from datetime import timedelta
from django.utils import timezone
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from apps.companies.models import Company
from apps.accounts.models import Team, EmployeeProfile
from apps.leads.models import Lead, PermanentPhoneNumberRegistry, ImportBatch
from apps.calls.models import CallAttempt
from apps.callbacks.models import Callback
from apps.notifications.models import Notification

User = get_user_model()

class Command(BaseCommand):
    help = 'Seeds initial companies, users, leads, calls, and callbacks for development and testing'

    def handle(self, *args, **options):
        self.stdout.write("Seeding demo data...")

        # 1. Super Admin
        super_admin, _ = User.objects.get_or_create(
            email='superadmin@telecaller.crm',
            defaults={
                'first_name': 'Global',
                'last_name': 'SuperAdmin',
                'role': 'SUPER_ADMIN',
                'is_staff': True,
                'is_superuser': True,
                'is_active': True,
            }
        )
        super_admin.set_password('SuperAdmin123!')
        super_admin.save()
        self.stdout.write(f"Super Admin: {super_admin.email} (Password: SuperAdmin123!)")

        # 2. Company 1: Apex Global Solutions
        apex, _ = Company.objects.get_or_create(
            name='Apex Global Solutions',
            defaults={
                'subdomain': 'apex',
                'contact_email': 'contact@apex.com',
                'contact_phone': '+919876543210',
                'status': 'ACTIVE',
                'default_country_code': '+91',
                'default_country_iso': 'IN',
            }
        )

        apex_admin, _ = User.objects.get_or_create(
            email='admin@apex.com',
            defaults={
                'first_name': 'Aarav',
                'last_name': 'Patel',
                'role': 'COMPANY_ADMIN',
                'company': apex,
                'is_active': True,
            }
        )
        apex_admin.set_password('Admin123!')
        apex_admin.save()

        # Sales Team
        team, _ = Team.objects.get_or_create(
            company=apex,
            name='Outbound Sales Alpha',
            defaults={'description': 'Primary outbound qualification team'}
        )

        manager, _ = User.objects.get_or_create(
            email='manager@apex.com',
            defaults={
                'first_name': 'Priya',
                'last_name': 'Sharma',
                'role': 'MANAGER',
                'company': apex,
                'is_active': True,
            }
        )
        manager.set_password('Manager123!')
        manager.save()
        team.manager = manager
        team.save()

        # Telecaller 1
        caller1, _ = User.objects.get_or_create(
            email='caller1@apex.com',
            defaults={
                'first_name': 'Rohan',
                'last_name': 'Verma',
                'role': 'EMPLOYEE',
                'company': apex,
                'is_active': True,
            }
        )
        caller1.set_password('Caller123!')
        caller1.save()
        EmployeeProfile.objects.update_or_create(
            user=caller1,
            defaults={
                'team': team,
                'manager': manager,
                'employee_code': 'APX-TC-01',
                'daily_call_target': 60,
                'status': 'ACTIVE',
            }
        )

        # Telecaller 2
        caller2, _ = User.objects.get_or_create(
            email='caller2@apex.com',
            defaults={
                'first_name': 'Ananya',
                'last_name': 'Deshmukh',
                'role': 'EMPLOYEE',
                'company': apex,
                'is_active': True,
            }
        )
        caller2.set_password('Caller123!')
        caller2.save()
        EmployeeProfile.objects.update_or_create(
            user=caller2,
            defaults={
                'team': team,
                'manager': manager,
                'employee_code': 'APX-TC-02',
                'daily_call_target': 50,
                'status': 'ACTIVE',
            }
        )

        # 3. Company 2: Zenith Technologies (for tenant isolation testing)
        zenith, _ = Company.objects.get_or_create(
            name='Zenith Technologies',
            defaults={
                'subdomain': 'zenith',
                'contact_email': 'contact@zenith.com',
                'contact_phone': '+919988776655',
                'status': 'ACTIVE',
                'default_country_code': '+91',
                'default_country_iso': 'IN',
            }
        )
        zenith_admin, _ = User.objects.get_or_create(
            email='admin@zenith.com',
            defaults={
                'first_name': 'Vikram',
                'last_name': 'Mehta',
                'role': 'COMPANY_ADMIN',
                'company': zenith,
                'is_active': True,
            }
        )
        zenith_admin.set_password('Admin123!')
        zenith_admin.save()

        zenith_caller, _ = User.objects.get_or_create(
            email='caller@zenith.com',
            defaults={
                'first_name': 'Neha',
                'last_name': 'Gupta',
                'role': 'EMPLOYEE',
                'company': zenith,
                'is_active': True,
            }
        )
        zenith_caller.set_password('Caller123!')
        zenith_caller.save()

        # 4. Create Batch & Sample Leads for Apex
        batch, _ = ImportBatch.objects.get_or_create(
            company=apex,
            file_name='Q4_Qualified_Leads.xlsx',
            defaults={
                'uploaded_by': apex_admin,
                'total_rows': 10,
                'valid_new_count': 10,
                'status': 'CONFIRMED'
            }
        )

        sample_leads_data = [
            ("Rajesh", "Kumar", "+919811223344", "Mumbai", "Maharashtra", "ASSIGNED", caller1),
            ("Siddharth", "Menon", "+919822334455", "Bangalore", "Karnataka", "ASSIGNED", caller1),
            ("Kavita", "Iyer", "+919833445566", "Chennai", "Tamil Nadu", "CALLBACK_REQUESTED", caller1),
            ("Amit", "Bansal", "+919844556677", "Delhi", "Delhi", "COMPLETED", caller1),
            ("Sneha", "Reddy", "+919855667788", "Hyderabad", "Telangana", "ASSIGNED", caller2),
            ("Rahul", "Nair", "+919866778899", "Kochi", "Kerala", "ASSIGNED", caller2),
            ("Manish", "Tiwari", "+919877889900", "Lucknow", "Uttar Pradesh", "UNASSIGNED", None),
            ("Deepa", "Joshi", "+919888990011", "Pune", "Maharashtra", "UNASSIGNED", None),
            ("Sunil", "Chopra", "+919899001122", "Chandigarh", "Punjab", "UNASSIGNED", None),
            ("Pooja", "Malhotra", "+919800112233", "Jaipur", "Rajasthan", "UNASSIGNED", None),
        ]

        now = timezone.now()
        for f_name, l_name, phone, city, state, st, emp in sample_leads_data:
            lead, _ = Lead.objects.get_or_create(
                company=apex,
                normalized_phone=phone,
                defaults={
                    'first_name': f_name,
                    'last_name': l_name,
                    'raw_phone': phone,
                    'city': city,
                    'state': state,
                    'status': st,
                    'assigned_to': emp,
                    'assigned_at': now if emp else None,
                    'is_assigned_ever': bool(emp),
                    'import_batch': batch,
                    'source': 'IMPORT_EXCEL',
                }
            )
            # If lead is assigned, register permanently in registry
            if emp:
                PermanentPhoneNumberRegistry.objects.get_or_create(
                    company=apex,
                    normalized_phone=phone,
                    defaults={
                        'first_assigned_to': emp,
                        'original_lead_id': str(lead.id),
                        'notes': f"Allocated during demo seed to {emp.email}"
                    }
                )

        # 5. Calls & Callbacks for Caller 1
        lead_kavita = Lead.objects.filter(company=apex, normalized_phone="+919833445566").first()
        if lead_kavita:
            call_attempt = CallAttempt.objects.create(
                company=apex,
                lead=lead_kavita,
                employee=caller1,
                outcome='CALLBACK_REQUESTED',
                notes='Customer is in a conference meeting, requested a follow-up today afternoon.',
                duration_seconds=45,
                dialer_launched_at=now - timedelta(hours=2)
            )

            # Scheduled callback (Due today)
            cb_due, _ = Callback.objects.get_or_create(
                company=apex,
                lead=lead_kavita,
                defaults={
                    'assigned_employee': caller1,
                    'originating_call_attempt': call_attempt,
                    'scheduled_at': now + timedelta(hours=1),
                    'status': 'DUE',
                    'initial_notes': 'Follow up on software demonstration request',
                }
            )

        # Overdue callback
        lead_rajesh = Lead.objects.filter(company=apex, normalized_phone="+919811223344").first()
        if lead_rajesh:
            Callback.objects.get_or_create(
                company=apex,
                lead=lead_rajesh,
                defaults={
                    'assigned_employee': caller1,
                    'scheduled_at': now - timedelta(days=1),
                    'status': 'OVERDUE',
                    'initial_notes': 'Needs pricing sheet discussion',
                }
            )

        # Upcoming callback for Caller 2
        lead_sneha = Lead.objects.filter(company=apex, normalized_phone="+919855667788").first()
        if lead_sneha:
            Callback.objects.get_or_create(
                company=apex,
                lead=lead_sneha,
                defaults={
                    'assigned_employee': caller2,
                    'scheduled_at': now + timedelta(days=2),
                    'status': 'SCHEDULED',
                    'initial_notes': 'Product inquiry discussion',
                }
            )

        # Notifications
        Notification.objects.create(
            company=apex,
            user=caller1,
            title='Callback Due Soon',
            message='You have a callback with Kavita Iyer scheduled shortly.',
            notification_type='CALLBACK_REMINDER'
        )
        Notification.objects.create(
            company=apex,
            user=caller1,
            title='Callback Overdue',
            message='Callback with Rajesh Kumar was scheduled yesterday and is now overdue.',
            notification_type='CALLBACK_OVERDUE'
        )

        self.stdout.write(self.style.SUCCESS("Successfully seeded comprehensive demo data!"))
