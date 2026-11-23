from datetime import timedelta
from django.utils import timezone
from django.db.models import Count, Q, Max, Sum
from rest_framework import views
from rest_framework.response import Response
from apps.leads.models import Lead, ImportBatch
from apps.calls.models import CallAttempt
from apps.callbacks.models import Callback
from apps.accounts.models import User, AttendanceRecord
from apps.billing.models import Quotation, Invoice, ReceiptVoucher
from apps.core.permissions import IsCompanyAdmin, IsEmployee, require_permission

from apps.companies.models import Company
from apps.companies.serializers import CompanySerializer

class AdminDashboardMetricsView(views.APIView):
    permission_classes = [IsCompanyAdmin]

    def get(self, request):
        company = request.user.company
        if not company and not request.user.is_super_admin:
            return Response({})

        if request.user.is_master_admin:
            comp_qs = Company.objects.all()
            lead_qs = Lead.objects.all()
            call_qs = CallAttempt.objects.all()
            cb_qs = Callback.objects.all()
            emp_qs = User.objects.filter(role__in=['EMPLOYEE', 'MANAGER'], is_active=True)
        elif request.user.role == 'SUPER_ADMIN':
            comp_qs = Company.objects.filter(Q(created_by=request.user) | Q(assigned_super_admin=request.user))
            lead_qs = Lead.objects.filter(company__in=comp_qs)
            call_qs = CallAttempt.objects.filter(company__in=comp_qs)
            cb_qs = Callback.objects.filter(company__in=comp_qs)
            emp_qs = User.objects.filter(company__in=comp_qs, role__in=['EMPLOYEE', 'MANAGER'], is_active=True)
        else:
            comp_qs = Company.objects.filter(id=company.id) if company else Company.objects.none()
            lead_qs = Lead.objects.filter(company=company)
            call_qs = CallAttempt.objects.filter(company=company)
            cb_qs = Callback.objects.filter(company=company)
            emp_qs = User.objects.filter(company=company, role__in=['EMPLOYEE', 'MANAGER'], is_active=True)

        now = timezone.now()
        today = now.date()
        week_ago = now - timedelta(days=7)

        # 1. KPI Cards
        total_registered_leads = lead_qs.count()
        newly_imported_leads = lead_qs.filter(created_at__gte=week_ago).count()
        assigned_leads = lead_qs.filter(status__in=['ASSIGNED', 'IN_PROGRESS', 'CALLBACK_REQUESTED']).count()
        unassigned_leads = lead_qs.filter(status='UNASSIGNED').count()
        calls_logged_today = call_qs.filter(created_at__date=today).count()
        calls_logged_total = call_qs.count()
        completed_leads = lead_qs.filter(status='COMPLETED').count()
        scheduled_callbacks = cb_qs.filter(status__in=['SCHEDULED', 'RESCHEDULED']).count()
        completed_callbacks = cb_qs.filter(status='COMPLETED').count()
        overdue_callbacks = cb_qs.filter(status='OVERDUE').count()

        # Company metrics scoped to viewer
        total_companies = comp_qs.count()
        active_companies = comp_qs.filter(status='ACTIVE').count()
        suspended_companies = comp_qs.filter(status='SUSPENDED').count()
        total_employees = User.objects.filter(company__in=comp_qs, role__in=['EMPLOYEE', 'MANAGER', 'COMPANY_ADMIN']).count()
        recent_companies = CompanySerializer(comp_qs.order_by('-created_at')[:5], many=True).data

        # 1b. Master Admin Super Admins Breakdown (how many tenants added/purchased per super admin)
        super_admins_breakdown = []
        if request.user.is_master_admin:
            for sa in User.objects.filter(role__in=['SUPER_ADMIN', 'MASTER_ADMIN']).order_by('-created_at'):
                sa_companies = sa.onboarded_companies.all()
                super_admins_breakdown.append({
                    'id': str(sa.id),
                    'full_name': sa.full_name,
                    'email': sa.email,
                    'phone': sa.phone,
                    'role': sa.role,
                    'is_active': sa.is_active,
                    'is_master_admin': sa.is_master_admin,
                    'tenants_count': sa_companies.count(),
                    'active_tenants': sa_companies.filter(status='ACTIVE').count(),
                    'total_staff': User.objects.filter(company__in=sa_companies).count(),
                    'companies': [
                        {
                            'id': str(c.id),
                            'name': c.name,
                            'subdomain': c.subdomain,
                            'status': c.status,
                            'plan_name': c.plan.name if c.plan else 'Starter Lite',
                            'plan_price': float(c.plan.price_monthly) if c.plan else 0.0,
                            'created_at': c.created_at.isoformat() if c.created_at else None,
                        }
                        for c in sa_companies.select_related('plan').order_by('-created_at')
                    ]
                })

        # 2. Call Outcomes Distribution
        outcome_counts = list(
            call_qs.values('outcome').annotate(count=Count('id')).order_by('-count')
        )

        # 3. Lead Status Distribution
        status_counts = list(
            lead_qs.values('status').annotate(count=Count('id')).order_by('-count')
        )

        # 4. Activity Over Time (last 7 days)
        activity_timeline = []
        for d in range(6, -1, -1):
            day_date = today - timedelta(days=d)
            count = call_qs.filter(created_at__date=day_date).count()
            activity_timeline.append({
                'date': day_date.strftime('%Y-%m-%d'),
                'day': day_date.strftime('%a'),
                'calls': count
            })

        # 5. Employee Performance Table
        employee_performance = []
        for emp in emp_qs:
            assigned = lead_qs.filter(assigned_to=emp, status__in=['ASSIGNED', 'IN_PROGRESS', 'CALLBACK_REQUESTED']).count()
            calls_today = call_qs.filter(employee=emp, created_at__date=today).values('lead_id').distinct().count()
            calls_total = call_qs.filter(employee=emp).count()
            completed = lead_qs.filter(assigned_to=emp, status='COMPLETED').count()
            cbs_due = cb_qs.filter(assigned_employee=emp, status='DUE').count()
            cbs_done = cb_qs.filter(assigned_employee=emp, status='COMPLETED').count()
            cbs_overdue = cb_qs.filter(assigned_employee=emp, status='OVERDUE').count()
            last_call = call_qs.filter(employee=emp).aggregate(last_act=Max('created_at'))['last_act']

            target = 50
            if hasattr(emp, 'employee_profile') and emp.employee_profile:
                target = emp.employee_profile.daily_call_target

            employee_performance.append({
                'employee_id': str(emp.id),
                'name': emp.full_name,
                'email': emp.email,
                'assigned_leads': assigned,
                'calls_today': calls_today,
                'daily_target': target,
                'calls_total': calls_total,
                'completed_leads': completed,
                'callbacks_due': cbs_due,
                'callbacks_done': cbs_done,
                'callbacks_overdue': cbs_overdue,
                'last_activity': last_call.isoformat() if last_call else None,
            })

        return Response({
            'kpis': {
                'total_registered_leads': total_registered_leads,
                'newly_imported_leads': newly_imported_leads,
                'assigned_leads': assigned_leads,
                'unassigned_leads': unassigned_leads,
                'calls_logged_today': calls_logged_today,
                'calls_logged_total': calls_logged_total,
                'completed_leads': completed_leads,
                'scheduled_callbacks': scheduled_callbacks,
                'completed_callbacks': completed_callbacks,
                'overdue_callbacks': overdue_callbacks,
                'total_companies': total_companies,
                'active_companies': active_companies,
                'suspended_companies': suspended_companies,
                'total_employees': total_employees,
            },
            'outcomes': outcome_counts,
            'lead_statuses': status_counts,
            'activity_timeline': activity_timeline,
            'employee_performance': employee_performance,
            'recent_companies': recent_companies,
            'super_admins_breakdown': super_admins_breakdown,
            'onboarding_rate': 75,
        })

class TelecallerDashboardMetricsView(views.APIView):
    permission_classes = [IsEmployee]

    def get(self, request):
        user = request.user
        company = user.company
        now = timezone.now()
        today = now.date()

        assigned_leads = Lead.objects.filter(
            company=company,
            assigned_to=user,
            status__in=['ASSIGNED', 'IN_PROGRESS', 'CALLBACK_REQUESTED']
        ).count()

        completed_leads = Lead.objects.filter(
            company=company,
            assigned_to=user,
            status='COMPLETED'
        ).count()

        calls_today = CallAttempt.objects.filter(
            company=company,
            employee=user,
            created_at__date=today
        ).values('lead_id').distinct().count()

        daily_target = 50
        if hasattr(user, 'employee_profile') and user.employee_profile:
            daily_target = user.employee_profile.daily_call_target

        callbacks_due_today = Callback.objects.filter(
            company=company,
            assigned_employee=user,
            scheduled_at__date=today,
            status__in=['SCHEDULED', 'DUE', 'RESCHEDULED']
        ).count()

        callbacks_upcoming = Callback.objects.filter(
            company=company,
            assigned_employee=user,
            scheduled_at__gt=now,
            status__in=['SCHEDULED', 'RESCHEDULED']
        ).count()

        callbacks_overdue = Callback.objects.filter(
            company=company,
            assigned_employee=user,
            status='OVERDUE'
        ).count()

        recent_calls = CallAttempt.objects.filter(
            company=company,
            employee=user
        ).order_by('-created_at')[:8]

        interested_count = CallAttempt.objects.filter(
            company=company,
            employee=user,
            created_at__date=today,
            outcome='INTERESTED'
        ).count()

        total_duration = CallAttempt.objects.filter(
            company=company,
            employee=user,
            created_at__date=today
        ).aggregate(tot=Sum('duration_seconds'))['tot'] or 0
        talk_time_minutes = round(total_duration / 60, 1)

        due_callbacks = Callback.objects.filter(
            company=company,
            assigned_employee=user,
            status__in=['SCHEDULED', 'DUE', 'RESCHEDULED', 'OVERDUE']
        ).select_related('lead', 'assigned_employee').order_by('scheduled_at')[:5]

        from apps.calls.serializers import CallAttemptSerializer
        from apps.callbacks.serializers import CallbackSerializer

        return Response({
            'kpis': {
                'assigned_leads': assigned_leads,
                'completed_leads': completed_leads,
                'calls_today': calls_today,
                'daily_target': daily_target,
                'callbacks_due_today': callbacks_due_today,
                'callbacks_upcoming': callbacks_upcoming,
                'callbacks_overdue': callbacks_overdue,
                'interested_count': interested_count,
                'talk_time_minutes': talk_time_minutes,
            },
            'recent_calls': CallAttemptSerializer(recent_calls, many=True).data,
            'due_callbacks': CallbackSerializer(due_callbacks, many=True).data,
        })


class SalesBillingReportView(views.APIView):
    permission_classes = [require_permission('reports.sales_billing')]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response({"summary": {}, "rows": []})

        date_from = request.query_params.get('date_from')
        date_to = request.query_params.get('date_to')
        emp_id = request.query_params.get('employee_id')

        q_qs = Quotation.objects.filter(company=company)
        inv_qs = Invoice.objects.filter(company=company)
        rv_qs = ReceiptVoucher.objects.filter(company=company)

        if date_from:
            q_qs = q_qs.filter(date__gte=date_from)
            inv_qs = inv_qs.filter(date__gte=date_from)
            rv_qs = rv_qs.filter(date__gte=date_from)
        if date_to:
            q_qs = q_qs.filter(date__lte=date_to)
            inv_qs = inv_qs.filter(date__lte=date_to)
            rv_qs = rv_qs.filter(date__lte=date_to)
        if emp_id and emp_id != 'ALL':
            q_qs = q_qs.filter(created_by_id=emp_id)
            inv_qs = inv_qs.filter(created_by_id=emp_id)
            rv_qs = rv_qs.filter(created_by_id=emp_id)

        can_view_cst = request.user.has_permission('quotations.view_cost_cst')
        q_agg = q_qs.aggregate(count=Count('id'), total=Sum('grand_total'))
        inv_agg = inv_qs.aggregate(
            count=Count('id'),
            total=Sum('grand_total'),
            paid=Sum('amount_paid'),
            cost=Sum('total_cost'),
            margin=Sum('gross_margin'),
        )
        rv_agg = rv_qs.aggregate(count=Count('id'), collected=Sum('amount'))

        total_invoiced = float(inv_agg['total'] or 0.0)
        total_paid = float(inv_agg['paid'] or 0.0)
        pending_dues = max(0.0, total_invoiced - total_paid)
        collection_rate = round((total_paid / total_invoiced) * 100, 1) if total_invoiced > 0 else 0.0

        summary = {
            'currency': company.currency,
            'quotation_count': q_agg['count'] or 0,
            'quotation_total': float(q_agg['total'] or 0.0),
            'converted_count': q_qs.filter(status='CONVERTED').count(),
            'invoice_count': inv_agg['count'] or 0,
            'total_invoiced': total_invoiced,
            'receipt_count': rv_agg['count'] or 0,
            'total_collected': float(rv_agg['collected'] or 0.0),
            'pending_dues': pending_dues,
            'collection_rate': collection_rate,
            'can_view_cst': can_view_cst,
        }
        if can_view_cst:
            summary['total_cost'] = float(inv_agg['cost'] or 0.0)
            summary['gross_margin'] = float(inv_agg['margin'] or 0.0)

        rows = []
        for inv in inv_qs.select_related('created_by').order_by('-date', '-created_at')[:200]:
            row = {
                'doc_type': 'INVOICE',
                'number': inv.invoice_number,
                'date': str(inv.date),
                'customer': inv.customer_name,
                'created_by': inv.created_by.full_name if inv.created_by else 'System',
                'currency': inv.currency,
                'grand_total': float(inv.grand_total),
                'amount_paid': float(inv.amount_paid),
                'balance_due': float(inv.balance_due),
                'status': inv.payment_status,
            }
            if can_view_cst:
                row['total_cost'] = float(inv.total_cost)
                row['gross_margin'] = float(inv.gross_margin)
            rows.append(row)

        return Response({'summary': summary, 'rows': rows})


class CallsTelecallerReportView(views.APIView):
    permission_classes = [require_permission('reports.calls_telecaller')]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response({"summary": {}, "rows": []})

        date_from = request.query_params.get('date_from')
        date_to = request.query_params.get('date_to')
        emp_id = request.query_params.get('employee_id')

        call_qs = CallAttempt.objects.filter(company=company)
        cb_qs = Callback.objects.filter(company=company)
        lead_qs = Lead.objects.filter(company=company, status='COMPLETED')

        if date_from:
            call_qs = call_qs.filter(created_at__date__gte=date_from)
            cb_qs = cb_qs.filter(scheduled_at__date__gte=date_from)
            lead_qs = lead_qs.filter(updated_at__date__gte=date_from)
        if date_to:
            call_qs = call_qs.filter(created_at__date__lte=date_to)
            cb_qs = cb_qs.filter(scheduled_at__date__lte=date_to)
            lead_qs = lead_qs.filter(updated_at__date__lte=date_to)

        staff_qs = User.objects.filter(company=company, is_active=True)
        if emp_id and emp_id != 'ALL':
            staff_qs = staff_qs.filter(id=emp_id)

        rows = []
        total_calls_all = 0
        connected_all = 0
        duration_all = 0
        for emp in staff_qs.order_by('first_name'):
            ecalls = call_qs.filter(employee=emp)
            c_count = ecalls.count()
            conn_count = ecalls.filter(outcome__in=['CONNECTED', 'INTERESTED', 'CALLBACK']).count()
            dur = ecalls.aggregate(tot=Sum('duration_seconds'))['tot'] or 0
            cb_done = cb_qs.filter(assigned_employee=emp, status='COMPLETED').count()
            conv = lead_qs.filter(assigned_to=emp).count()
            if c_count == 0 and cb_done == 0 and conv == 0:
                continue
            total_calls_all += c_count
            connected_all += conn_count
            duration_all += dur
            rows.append({
                'employee_id': str(emp.id),
                'employee_name': emp.full_name,
                'role': emp.role,
                'total_calls': c_count,
                'connected_calls': conn_count,
                'connect_rate': round((conn_count / c_count) * 100, 1) if c_count > 0 else 0.0,
                'talk_time_minutes': round(dur / 60, 1),
                'callbacks_completed': cb_done,
                'leads_converted': conv,
            })

        return Response({
            'summary': {
                'total_calls': total_calls_all,
                'connected_calls': connected_all,
                'connect_rate': round((connected_all / total_calls_all) * 100, 1) if total_calls_all > 0 else 0.0,
                'talk_time_minutes': round(duration_all / 60, 1),
                'active_telecallers': len(rows),
            },
            'rows': rows,
        })


class LeadsPipelineReportView(views.APIView):
    permission_classes = [require_permission('reports.leads_conversion')]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response({"summary": {}, "by_status": [], "by_branch": []})

        date_from = request.query_params.get('date_from')
        date_to = request.query_params.get('date_to')
        branch_id = request.query_params.get('branch_id')

        qs = Lead.objects.filter(company=company)
        if date_from:
            qs = qs.filter(created_at__date__gte=date_from)
        if date_to:
            qs = qs.filter(created_at__date__lte=date_to)
        if branch_id and branch_id != 'ALL':
            qs = qs.filter(branch_id=branch_id)

        total = qs.count()
        completed = qs.filter(status='COMPLETED').count()
        conv_rate = round((completed / total) * 100, 1) if total > 0 else 0.0

        by_status = list(qs.values('status').annotate(count=Count('id')).order_by('-count'))
        by_branch = list(qs.values('branch__name').annotate(count=Count('id')).order_by('-count'))

        return Response({
            'summary': {
                'total_leads': total,
                'completed_leads': completed,
                'unassigned_leads': qs.filter(status='UNASSIGNED').count(),
                'in_progress_leads': qs.filter(status__in=['ASSIGNED', 'IN_PROGRESS', 'CALLBACK_REQUESTED']).count(),
                'conversion_rate': conv_rate,
            },
            'by_status': by_status,
            'by_branch': [
                {'branch': b['branch__name'] or 'Unassigned Branch', 'count': b['count']}
                for b in by_branch
            ],
        })


class HrAttendanceReportView(views.APIView):
    permission_classes = [require_permission('reports.hr_attendance')]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response({"summary": {}, "rows": []})

        date_from = request.query_params.get('date_from')
        date_to = request.query_params.get('date_to')
        dept_id = request.query_params.get('department_id')

        qs = AttendanceRecord.objects.filter(company=company).select_related('user', 'department')
        if date_from:
            qs = qs.filter(date__gte=date_from)
        if date_to:
            qs = qs.filter(date__lte=date_to)
        if dept_id and dept_id != 'ALL':
            qs = qs.filter(department_id=dept_id)

        agg_map = {}
        for rec in qs:
            uid = str(rec.user_id)
            if uid not in agg_map:
                agg_map[uid] = {
                    'employee_id': uid,
                    'employee_name': rec.user.full_name if rec.user else 'Unknown',
                    'department': rec.department.name if rec.department else '-',
                    'present_days': 0,
                    'late_days': 0,
                    'out_of_fence_days': 0,
                    'total_hours': 0.0,
                }
            entry = agg_map[uid]
            if rec.status in ('PRESENT', 'LATE'):
                entry['present_days'] += 1
            if rec.status == 'LATE':
                entry['late_days'] += 1
            if rec.status == 'OUT_OF_FENCE':
                entry['out_of_fence_days'] += 1
            entry['total_hours'] = round(entry['total_hours'] + float(rec.working_hours or 0.0), 2)

        rows = sorted(agg_map.values(), key=lambda x: x['employee_name'])
        return Response({
            'summary': {
                'total_records': qs.count(),
                'employees_tracked': len(rows),
                'total_late': sum(r['late_days'] for r in rows),
                'total_out_of_fence': sum(r['out_of_fence_days'] for r in rows),
                'total_hours': round(sum(r['total_hours'] for r in rows), 1),
            },
            'rows': rows,
        })
