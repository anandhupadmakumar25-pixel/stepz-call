from django.db import transaction
from django.utils import timezone
from django.contrib.auth import get_user_model
from apps.leads.models import Lead, PermanentPhoneNumberRegistry, LeadAssignmentHistory
from apps.notifications.models import Notification

User = get_user_model()

class LeadAssignmentService:
    @classmethod
    def bulk_assign(cls, company, assigned_by, lead_ids: list, allocations: list[dict], method: str = 'EQUAL') -> dict:
        """
        Executes concurrency-safe bulk lead assignment.
        allocations format:
        [{'employee_id': 'uuid', 'count': int or 'percentage': float}]
        """
        with transaction.atomic():
            # Lock leads for update
            leads = list(
                Lead.objects.select_for_update()
                .filter(id__in=lead_ids, company=company, status='UNASSIGNED')
            )

            if not leads:
                return {
                    'success': False,
                    'message': 'No eligible unassigned leads found for the provided IDs.',
                    'assigned_count': 0,
                    'blocked_count': 0,
                }

            # Fetch active employees
            emp_ids = [a['employee_id'] for a in allocations]
            employees = {
                str(u.id): u for u in User.objects.filter(id__in=emp_ids, company=company, is_active=True)
            }

            if not employees:
                raise ValueError("No active target employees selected for assignment.")

            # Calculate distribution map {emp_id: count}
            distribution = cls._calculate_distribution(len(leads), allocations, method, list(employees.keys()))

            # Assign leads in order
            lead_index = 0
            assigned_count = 0
            blocked_count = 0
            emp_assigned_counts = {emp_id: 0 for emp_id in employees}
            now = timezone.now()

            # Pre-fetch company permanent registry
            company_permanent_numbers = set(
                PermanentPhoneNumberRegistry.objects.filter(company=company)
                .values_list('normalized_phone', flat=True)
            )

            registry_entries_to_create = []
            history_entries_to_create = []

            for emp_id, count in distribution.items():
                target_emp = employees[emp_id]
                assigned_to_emp = 0

                while assigned_to_emp < count and lead_index < len(leads):
                    lead = leads[lead_index]
                    lead_index += 1

                    # MANDATORY INVARIANT: Permanent Phone Number Blocking
                    if lead.normalized_phone in company_permanent_numbers:
                        lead.status = 'BLOCKED'
                        lead.save(update_fields=['status'])
                        blocked_count += 1
                        continue

                    # Assign lead
                    lead.assigned_to = target_emp
                    lead.assigned_at = now
                    lead.is_assigned_ever = True
                    lead.status = 'ASSIGNED'
                    lead.save(update_fields=['assigned_to', 'assigned_at', 'is_assigned_ever', 'status'])

                    # Mark permanently blocked in this company
                    company_permanent_numbers.add(lead.normalized_phone)
                    registry_entries_to_create.append(PermanentPhoneNumberRegistry(
                        company=company,
                        normalized_phone=lead.normalized_phone,
                        first_assigned_to=target_emp,
                        original_lead_id=str(lead.id),
                        notes=f"Assigned by {assigned_by.email} using {method}"
                    ))

                    history_entries_to_create.append(LeadAssignmentHistory(
                        company=company,
                        lead=lead,
                        assigned_to=target_emp,
                        assigned_by=assigned_by,
                        assignment_method=method,
                    ))

                    assigned_to_emp += 1
                    assigned_count += 1
                    emp_assigned_counts[emp_id] += 1

            PermanentPhoneNumberRegistry.objects.bulk_create(registry_entries_to_create)
            LeadAssignmentHistory.objects.bulk_create(history_entries_to_create)

            # Create in-app notifications for employees who received leads
            for emp_id, c in emp_assigned_counts.items():
                if c > 0:
                    emp = employees[emp_id]
                    Notification.objects.create(
                        company=company,
                        user=emp,
                        title='New Leads Assigned',
                        message=f'You have been assigned {c} new lead{"s" if c > 1 else ""}.',
                        notification_type='LEAD_ASSIGNED',
                        entity_type='lead'
                    )

            return {
                'success': True,
                'total_requested': len(lead_ids),
                'assigned_count': assigned_count,
                'blocked_count': blocked_count,
                'employee_breakdown': [
                    {'employee_id': emp_id, 'employee_name': employees[emp_id].full_name, 'count': c}
                    for emp_id, c in emp_assigned_counts.items()
                ]
            }

    @staticmethod
    def _calculate_distribution(total_leads: int, allocations: list[dict], method: str, active_emp_ids: list[str]) -> dict:
        dist = {emp_id: 0 for emp_id in active_emp_ids}
        if not active_emp_ids or total_leads == 0:
            return dist

        if method == 'EQUAL':
            base = total_leads // len(active_emp_ids)
            remainder = total_leads % len(active_emp_ids)
            for idx, emp_id in enumerate(active_emp_ids):
                dist[emp_id] = base + (1 if idx < remainder else 0)

        elif method == 'PERCENTAGE':
            allocated_so_far = 0
            for a in allocations:
                emp_id = str(a['employee_id'])
                if emp_id in dist:
                    pct = float(a.get('percentage', 0)) / 100.0
                    cnt = int(total_leads * pct)
                    dist[emp_id] = cnt
                    allocated_so_far += cnt
            # assign any rounding difference to first employee
            diff = total_leads - allocated_so_far
            if diff > 0 and active_emp_ids:
                dist[active_emp_ids[0]] += diff

        elif method == 'CUSTOM':
            for a in allocations:
                emp_id = str(a['employee_id'])
                if emp_id in dist:
                    dist[emp_id] = min(total_leads, int(a.get('count', 0)))

        return dist
