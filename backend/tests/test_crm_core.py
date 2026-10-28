import io
import pytest
from datetime import timedelta
from django.utils import timezone
from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from apps.companies.models import Company
from apps.accounts.models import Team, EmployeeProfile
from apps.leads.models import Lead, PermanentPhoneNumberRegistry, ImportBatch
from apps.leads.services.import_service import LeadImportService
from apps.leads.services.assignment_service import LeadAssignmentService
from apps.calls.models import CallAttempt
from apps.callbacks.models import Callback
from apps.callbacks.services.reminder_service import CallbackReminderService
from apps.core.phone_utils import normalize_phone_number

User = get_user_model()

class TelecallerCRMCoreTests(TestCase):
    def setUp(self):
        # Company A
        self.company_a = Company.objects.create(
            name='Company A Corp',
            subdomain='comp-a',
            contact_email='admin@compa.com',
            default_country_iso='IN'
        )
        self.admin_a = User.objects.create_user(
            email='admin@compa.com',
            password='Password123!',
            first_name='Admin',
            last_name='A',
            role='COMPANY_ADMIN',
            company=self.company_a
        )
        self.caller_a1 = User.objects.create_user(
            email='caller1@compa.com',
            password='Password123!',
            first_name='Caller1',
            last_name='A',
            role='EMPLOYEE',
            company=self.company_a
        )
        self.caller_a2 = User.objects.create_user(
            email='caller2@compa.com',
            password='Password123!',
            first_name='Caller2',
            last_name='A',
            role='EMPLOYEE',
            company=self.company_a
        )

        # Company B (for tenant isolation)
        self.company_b = Company.objects.create(
            name='Company B Corp',
            subdomain='comp-b',
            contact_email='admin@compb.com',
            default_country_iso='IN'
        )
        self.admin_b = User.objects.create_user(
            email='admin@compb.com',
            password='Password123!',
            first_name='Admin',
            last_name='B',
            role='COMPANY_ADMIN',
            company=self.company_b
        )
        self.caller_b = User.objects.create_user(
            email='caller@compb.com',
            password='Password123!',
            first_name='Caller',
            last_name='B',
            role='EMPLOYEE',
            company=self.company_b
        )

        self.client = APIClient()

    def test_phone_normalization(self):
        # Test Indian 10 digits
        num, is_valid, _ = normalize_phone_number("9876543210", "IN")
        self.assertTrue(is_valid)
        self.assertEqual(num, "+919876543210")

        # Test with spaces and dashes
        num, is_valid, _ = normalize_phone_number("+91 98765-43210", "IN")
        self.assertTrue(is_valid)
        self.assertEqual(num, "+919876543210")

        # Test international US number
        num, is_valid, _ = normalize_phone_number("+1 (415) 555-2671", "US")
        self.assertTrue(is_valid)
        self.assertEqual(num, "+14155552671")

    def test_tenant_isolation(self):
        lead_a = Lead.objects.create(
            company=self.company_a,
            first_name='John',
            last_name='Doe',
            raw_phone='9811111111',
            normalized_phone='+919811111111',
            status='UNASSIGNED'
        )
        lead_b = Lead.objects.create(
            company=self.company_b,
            first_name='Jane',
            last_name='Smith',
            raw_phone='9822222222',
            normalized_phone='+919822222222',
            status='UNASSIGNED'
        )

        # Authenticate as Admin A
        self.client.force_authenticate(user=self.admin_a)
        res = self.client.get('/api/v1/leads/')
        self.assertEqual(res.status_code, 200)
        phone_numbers = [item['normalized_phone'] for item in res.data]
        self.assertIn('+919811111111', phone_numbers)
        self.assertNotIn('+919822222222', phone_numbers)

        # Admin A cannot access lead B directly
        res_detail = self.client.get(f'/api/v1/leads/{lead_b.id}/')
        self.assertEqual(res_detail.status_code, 403)

    def test_permanent_phone_blocking_invariant(self):
        """
        CRITICAL BUSINESS RULE:
        A normalized phone number may be assigned only once within the lifetime of a company's records.
        Even if the original lead is deleted, Company A cannot assign it again.
        Company B can independently assign the same phone number.
        """
        shared_phone = "+919876500001"

        # 1. Company A creates and assigns the lead
        lead_a = Lead.objects.create(
            company=self.company_a,
            first_name='Alice',
            raw_phone='9876500001',
            normalized_phone=shared_phone,
            status='UNASSIGNED'
        )

        result_a = LeadAssignmentService.bulk_assign(
            company=self.company_a,
            assigned_by=self.admin_a,
            lead_ids=[lead_a.id],
            allocations=[{'employee_id': str(self.caller_a1.id), 'count': 1}],
            method='EQUAL'
        )
        self.assertEqual(result_a['assigned_count'], 1)
        self.assertEqual(result_a['blocked_count'], 0)

        # Check permanent registry has recorded this number for Company A
        self.assertTrue(
            PermanentPhoneNumberRegistry.objects.filter(
                company=self.company_a,
                normalized_phone=shared_phone
            ).exists()
        )

        # 2. Suppose lead_a is deleted or completed
        lead_a.delete()

        # Try to import/create the same number again in Company A manually
        self.client.force_authenticate(user=self.admin_a)
        res_create_a = self.client.post('/api/v1/leads/', {
            'first_name': 'Alice New',
            'raw_phone': '9876500001'
        })
        self.assertEqual(res_create_a.status_code, 400)
        self.assertIn("permanently blocked", str(res_create_a.data))

        # 3. Company B CAN independently import and assign this number!
        lead_b = Lead.objects.create(
            company=self.company_b,
            first_name='Bob',
            raw_phone='9876500001',
            normalized_phone=shared_phone,
            status='UNASSIGNED'
        )
        result_b = LeadAssignmentService.bulk_assign(
            company=self.company_b,
            assigned_by=self.admin_b,
            lead_ids=[lead_b.id],
            allocations=[{'employee_id': str(self.caller_b.id), 'count': 1}],
            method='EQUAL'
        )
        self.assertEqual(result_b['assigned_count'], 1)
        self.assertTrue(
            PermanentPhoneNumberRegistry.objects.filter(
                company=self.company_b,
                normalized_phone=shared_phone
            ).exists()
        )

    def test_bulk_lead_assignment_equal_split(self):
        leads = []
        for i in range(10):
            leads.append(Lead.objects.create(
                company=self.company_a,
                first_name=f'User {i}',
                raw_phone=f'980000000{i}',
                normalized_phone=f'+91980000000{i}',
                status='UNASSIGNED'
            ))

        lead_ids = [l.id for l in leads]
        result = LeadAssignmentService.bulk_assign(
            company=self.company_a,
            assigned_by=self.admin_a,
            lead_ids=lead_ids,
            allocations=[
                {'employee_id': str(self.caller_a1.id)},
                {'employee_id': str(self.caller_a2.id)}
            ],
            method='EQUAL'
        )

        self.assertEqual(result['assigned_count'], 10)
        c1_count = Lead.objects.filter(company=self.company_a, assigned_to=self.caller_a1).count()
        c2_count = Lead.objects.filter(company=self.company_a, assigned_to=self.caller_a2).count()
        self.assertEqual(c1_count, 5)
        self.assertEqual(c2_count, 5)

    def test_call_outcome_and_callback(self):
        lead = Lead.objects.create(
            company=self.company_a,
            first_name='Mark',
            raw_phone='9855555555',
            normalized_phone='+919855555555',
            status='ASSIGNED',
            assigned_to=self.caller_a1
        )

        self.client.force_authenticate(user=self.caller_a1)
        callback_time = (timezone.now() + timedelta(hours=3)).isoformat()
        res = self.client.post('/api/v1/calls/', {
            'lead_id': str(lead.id),
            'outcome': 'CALLBACK_REQUESTED',
            'notes': 'Requested callback after lunch meeting.',
            'duration_seconds': 35,
            'schedule_callback': True,
            'callback_time': callback_time
        })
        self.assertEqual(res.status_code, 201)

        # Lead status updated
        lead.refresh_from_db()
        self.assertEqual(lead.status, 'CALLBACK_REQUESTED')

        # Callback created
        cb = Callback.objects.filter(lead=lead).first()
        self.assertIsNotNone(cb)
        self.assertEqual(cb.status, 'SCHEDULED')
        self.assertEqual(cb.assigned_employee, self.caller_a1)

    def test_callback_reminder_service(self):
        lead = Lead.objects.create(
            company=self.company_a,
            first_name='Due Test',
            raw_phone='9844444444',
            normalized_phone='+919844444444',
            status='ASSIGNED',
            assigned_to=self.caller_a1
        )
        # Create callback due 5 minutes ago
        cb = Callback.objects.create(
            company=self.company_a,
            lead=lead,
            assigned_employee=self.caller_a1,
            scheduled_at=timezone.now() - timedelta(minutes=5),
            status='SCHEDULED'
        )

        result = CallbackReminderService.process_due_and_overdue_callbacks()
        self.assertGreaterEqual(result['marked_due'], 1)
        cb.refresh_from_db()
        self.assertEqual(cb.status, 'DUE')
        self.assertTrue(cb.reminder_sent)

    def test_csv_import_service(self):
        csv_content = """Name,Phone,Email,City
Rajesh Kumar,9812345678,rajesh@example.com,Delhi
Duplicate Row,9812345678,dup@example.com,Delhi
Invalid Phone,not-a-number,bad@example.com,Mumbai
Sunil Joshi,9812345679,sunil@example.com,Pune
"""
        file_obj = io.BytesIO(csv_content.encode('utf-8'))
        batch = LeadImportService.preview_import(
            company=self.company_a,
            uploaded_by=self.admin_a,
            file_obj=file_obj,
            filename='test_leads.csv'
        )

        self.assertEqual(batch.total_rows, 4)
        self.assertEqual(batch.valid_new_count, 2)
        self.assertEqual(batch.duplicate_in_file_count, 1)
        self.assertEqual(batch.invalid_rows_count, 1)

        # Confirm import
        imported_count = LeadImportService.confirm_import(batch.id, self.company_a, self.admin_a)
        self.assertEqual(imported_count, 2)
        self.assertTrue(Lead.objects.filter(company=self.company_a, normalized_phone='+919812345678').exists())
        self.assertTrue(Lead.objects.filter(company=self.company_a, normalized_phone='+919812345679').exists())
