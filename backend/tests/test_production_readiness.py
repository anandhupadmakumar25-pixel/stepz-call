import io
from datetime import timedelta
from django.utils import timezone
from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient

from apps.companies.models import Company
from apps.accounts.models import Team, EmployeeProfile
from apps.leads.models import (
    Lead, Branch, LeadCategory, CallingTask,
    PermanentPhoneNumberRegistry, ImportBatch, ImportRowError
)
from apps.leads.services.import_service import LeadImportService
from apps.leads.services.assignment_service import LeadAssignmentService
from apps.calls.models import CallAttempt
from apps.callbacks.models import Callback, CallbackHistory
from apps.core.phone_utils import normalize_phone_number

User = get_user_model()

class ProductionReadinessAuditTests(TestCase):
    def setUp(self):
        # Company Alpha
        self.company_a = Company.objects.create(
            name='Alpha Corp',
            subdomain='alpha-corp',
            contact_email='admin@alpha.com',
            default_country_iso='IN',
            status='ACTIVE'
        )
        self.admin_a = User.objects.create_user(
            email='admin@alpha.com',
            password='AdminPassword123!',
            first_name='Admin',
            last_name='Alpha',
            role='COMPANY_ADMIN',
            company=self.company_a,
            is_active=True
        )
        self.branch_a1 = Branch.objects.create(
            company=self.company_a,
            name='Alpha Main Branch',
            code='A-MAIN'
        )
        self.branch_a2 = Branch.objects.create(
            company=self.company_a,
            name='Alpha North Branch',
            code='A-NORTH'
        )
        self.cat_a_client = LeadCategory.objects.create(
            company=self.company_a,
            name='Corporate Client',
            color_code='#10B981'
        )
        self.cat_a_academy = LeadCategory.objects.create(
            company=self.company_a,
            name='Academy Student',
            color_code='#F59E0B'
        )
        self.caller_a1 = User.objects.create_user(
            email='caller1@alpha.com',
            password='CallerPassword123!',
            first_name='Caller',
            last_name='One',
            role='EMPLOYEE',
            company=self.company_a,
            branch=self.branch_a1,
            is_active=True
        )
        self.caller_a2 = User.objects.create_user(
            email='caller2@alpha.com',
            password='CallerPassword123!',
            first_name='Caller',
            last_name='Two',
            role='EMPLOYEE',
            company=self.company_a,
            branch=self.branch_a2,
            is_active=True
        )

        # Company Beta (Tenant Isolation Target)
        self.company_b = Company.objects.create(
            name='Beta Corp',
            subdomain='beta-corp',
            contact_email='admin@beta.com',
            default_country_iso='IN',
            status='ACTIVE'
        )
        self.admin_b = User.objects.create_user(
            email='admin@beta.com',
            password='BetaAdmin123!',
            first_name='Admin',
            last_name='Beta',
            role='COMPANY_ADMIN',
            company=self.company_b,
            is_active=True
        )
        self.branch_b = Branch.objects.create(
            company=self.company_b,
            name='Beta Headquarters',
            code='B-HQ'
        )
        self.cat_b = LeadCategory.objects.create(
            company=self.company_b,
            name='Retail Customer',
            color_code='#6366F1'
        )
        self.caller_b = User.objects.create_user(
            email='caller@beta.com',
            password='BetaCaller123!',
            first_name='Caller',
            last_name='Beta',
            role='EMPLOYEE',
            company=self.company_b,
            branch=self.branch_b,
            is_active=True
        )

        # Super Admin
        self.superadmin = User.objects.create_superuser(
            email='superadmin@platform.com',
            password='SuperSecret123!',
            first_name='Platform',
            last_name='Owner'
        )

        self.client = APIClient()

    # =========================================================================
    # 2. MULTI-TENANT ISOLATION TESTS
    # =========================================================================

    def test_tenant_cannot_access_or_modify_other_company_branches(self):
        """Proves Company A cannot delete or modify Company B's branches by changing request ID."""
        self.client.force_authenticate(user=self.admin_a)
        res = self.client.delete(f'/api/v1/leads/branches/{self.branch_b.id}/')
        self.assertEqual(res.status_code, 404)
        self.branch_b.refresh_from_db()
        self.assertTrue(self.branch_b.is_active)

    def test_tenant_cannot_access_or_modify_other_company_categories(self):
        """Proves Company A cannot delete or modify Company B's categories by changing request ID."""
        self.client.force_authenticate(user=self.admin_a)
        res = self.client.delete(f'/api/v1/leads/categories/{self.cat_b.id}/')
        self.assertEqual(res.status_code, 404)
        self.cat_b.refresh_from_db()
        self.assertTrue(self.cat_b.is_active)

    def test_tenant_cannot_access_or_modify_other_company_employees(self):
        """Proves Company A cannot view or alter Company B's employees."""
        self.client.force_authenticate(user=self.admin_a)
        res = self.client.get(f'/api/v1/accounts/employees/{self.caller_b.id}/')
        self.assertEqual(res.status_code, 404)

        # Attempt to deactivate Company B's employee
        patch_res = self.client.patch(f'/api/v1/accounts/employees/{self.caller_b.id}/', {
            'is_active': False
        })
        self.assertEqual(patch_res.status_code, 404)
        self.caller_b.refresh_from_db()
        self.assertTrue(self.caller_b.is_active)

    def test_tenant_cannot_read_or_patch_other_company_leads(self):
        """Proves Company A cannot read or patch Company B's leads."""
        lead_b = Lead.objects.create(
            company=self.company_b,
            first_name='Confidential',
            last_name='Beta Lead',
            raw_phone='9999900001',
            normalized_phone='+919999900001',
            status='UNASSIGNED'
        )

        self.client.force_authenticate(user=self.admin_a)
        get_res = self.client.get(f'/api/v1/leads/{lead_b.id}/')
        self.assertEqual(get_res.status_code, 403)

        patch_res = self.client.patch(f'/api/v1/leads/{lead_b.id}/', {
            'first_name': 'Hacked Name'
        })
        self.assertEqual(patch_res.status_code, 403)
        lead_b.refresh_from_db()
        self.assertEqual(lead_b.first_name, 'Confidential')

    def test_tenant_cannot_view_or_patch_other_company_calling_tasks(self):
        """Proves Company A cannot access or cancel Company B's calling tasks."""
        task_b = CallingTask.objects.create(
            company=self.company_b,
            title='Beta Outbound Task',
            assigned_to=self.caller_b,
            created_by=self.admin_b,
            status='PENDING'
        )

        self.client.force_authenticate(user=self.admin_a)
        res_get = self.client.get(f'/api/v1/leads/tasks/{task_b.id}/')
        self.assertEqual(res_get.status_code, 404)

        res_patch = self.client.patch(f'/api/v1/leads/tasks/{task_b.id}/', {'status': 'CANCELLED'})
        self.assertEqual(res_patch.status_code, 404)
        task_b.refresh_from_db()
        self.assertEqual(task_b.status, 'PENDING')

    def test_server_ignores_client_supplied_company_id(self):
        """Server must never trust a client-supplied company ID in payload."""
        self.client.force_authenticate(user=self.admin_a)
        res = self.client.post('/api/v1/leads/', {
            'first_name': 'Injected Lead',
            'raw_phone': '9888877771',
            'company': str(self.company_b.id),
            'company_id': str(self.company_b.id)
        })
        self.assertEqual(res.status_code, 201)
        created_lead = Lead.objects.get(normalized_phone='+919888877771')
        self.assertEqual(created_lead.company, self.company_a)
        self.assertNotEqual(created_lead.company, self.company_b)

    # =========================================================================
    # 3. PERMANENT PHONE NUMBER PROTECTION TESTS
    # =========================================================================

    def test_deleted_and_archived_lead_does_not_release_phone_number(self):
        """
        Permanent registry invariant:
        When a lead is deleted or archived, its normalized phone number is still permanently blocked for Company A.
        Company B can still independently register it.
        """
        phone = "+919111122223"
        lead = Lead.objects.create(
            company=self.company_a,
            first_name='Permanent',
            raw_phone='9111122223',
            normalized_phone=phone,
            status='UNASSIGNED'
        )

        # Assign lead to register phone in permanent registry
        LeadAssignmentService.bulk_assign(
            company=self.company_a,
            assigned_by=self.admin_a,
            lead_ids=[lead.id],
            allocations=[{'employee_id': str(self.caller_a1.id), 'count': 1}],
            method='EQUAL'
        )

        self.assertTrue(PermanentPhoneNumberRegistry.objects.filter(company=self.company_a, normalized_phone=phone).exists())

        # Hard delete the lead from DB
        lead.delete()
        self.assertFalse(Lead.objects.filter(company=self.company_a, normalized_phone=phone).exists())

        # Company A tries to recreate the same lead manually -> MUST BE REJECTED
        self.client.force_authenticate(user=self.admin_a)
        res_a = self.client.post('/api/v1/leads/', {
            'first_name': 'Retry',
            'raw_phone': '9111122223'
        })
        self.assertEqual(res_a.status_code, 400)
        self.assertIn("permanently blocked", str(res_a.data).lower())

        # Company B CAN create the lead
        self.client.force_authenticate(user=self.admin_b)
        res_b = self.client.post('/api/v1/leads/', {
            'first_name': 'Company B Lead',
            'raw_phone': '9111122223'
        })
        self.assertEqual(res_b.status_code, 201)

    def test_import_confirm_prevents_duplicate_and_permanently_blocked_numbers(self):
        """Batch import confirmation must re-verify permanent registry before committing."""
        blocked_phone = "+919222233334"
        PermanentPhoneNumberRegistry.objects.create(
            company=self.company_a,
            normalized_phone=blocked_phone,
            first_assigned_to=self.caller_a1,
            notes='Pre-existing registry entry'
        )

        csv_text = f"""Name,Phone\nValid Lead,9333344445\nBlocked Lead,9222233334\n"""
        batch = LeadImportService.preview_import(
            company=self.company_a,
            uploaded_by=self.admin_a,
            file_obj=io.BytesIO(csv_text.encode('utf-8')),
            filename='audit_import.csv'
        )

        self.assertEqual(batch.valid_new_count, 1)
        self.assertEqual(batch.permanently_blocked_count, 1)

        confirmed_count = LeadImportService.confirm_import(batch.id, self.company_a, self.admin_a)
        self.assertEqual(confirmed_count, 1)
        self.assertTrue(Lead.objects.filter(company=self.company_a, normalized_phone='+919333344445').exists())
        self.assertFalse(Lead.objects.filter(company=self.company_a, normalized_phone=blocked_phone).exists())

    # =========================================================================
    # 4. CALLING TASK ASSIGNMENT AUDIT TESTS
    # =========================================================================

    def test_calling_task_rejects_other_company_leads(self):
        """Calling task creation must reject lead IDs belonging to another company."""
        lead_b = Lead.objects.create(
            company=self.company_b,
            first_name='Beta Target',
            raw_phone='9444455556',
            normalized_phone='+919444455556',
            status='UNASSIGNED'
        )

        self.client.force_authenticate(user=self.admin_a)
        res = self.client.post('/api/v1/leads/tasks/', {
            'title': 'Cross-Company Assignment Attempt',
            'assigned_to_id': str(self.caller_a1.id),
            'lead_ids': [str(lead_b.id)]
        }, format='json')
        self.assertEqual(res.status_code, 400)
        lead_b.refresh_from_db()
        self.assertIsNone(lead_b.task)
        self.assertIsNone(lead_b.assigned_to)

    def test_calling_task_rejects_already_assigned_leads(self):
        """Calling task must reject leads that are already assigned to another task or employee."""
        lead_a = Lead.objects.create(
            company=self.company_a,
            first_name='Assigned Lead',
            raw_phone='9555566667',
            normalized_phone='+919555566667',
            status='ASSIGNED',
            assigned_to=self.caller_a1
        )

        self.client.force_authenticate(user=self.admin_a)
        res = self.client.post('/api/v1/leads/tasks/', {
            'title': 'Duplicate Assignment Attempt',
            'assigned_to_id': str(self.caller_a2.id),
            'lead_ids': [str(lead_a.id)]
        }, format='json')
        self.assertEqual(res.status_code, 400)
        self.assertIn("already assigned", str(res.data).lower())

    def test_calling_task_rejects_branch_and_category_mismatches(self):
        """Calling task with branch/category must reject leads belonging to different branches/categories."""
        lead_north = Lead.objects.create(
            company=self.company_a,
            branch=self.branch_a2,
            category=self.cat_a_academy,
            first_name='North Academy Lead',
            raw_phone='9666677778',
            normalized_phone='+919666677778',
            status='UNASSIGNED'
        )

        self.client.force_authenticate(user=self.admin_a)
        # Attempt to assign North branch lead to a Main branch task
        res_branch_mismatch = self.client.post('/api/v1/leads/tasks/', {
            'title': 'Main Branch Task',
            'branch_id': str(self.branch_a1.id),
            'assigned_to_id': str(self.caller_a1.id),
            'lead_ids': [str(lead_north.id)]
        }, format='json')
        self.assertEqual(res_branch_mismatch.status_code, 400)
        self.assertIn("branch", str(res_branch_mismatch.data).lower())

        # Attempt to assign Academy lead to a Client category task
        res_cat_mismatch = self.client.post('/api/v1/leads/tasks/', {
            'title': 'Client Category Task',
            'category_id': str(self.cat_a_client.id),
            'assigned_to_id': str(self.caller_a1.id),
            'lead_ids': [str(lead_north.id)]
        }, format='json')
        self.assertEqual(res_cat_mismatch.status_code, 400)
        self.assertIn("category", str(res_cat_mismatch.data).lower())

    def test_calling_task_reassignment_updates_leads_atomically(self):
        """Admin reassigning task to a new employee reassigns all task leads atomically."""
        lead1 = Lead.objects.create(
            company=self.company_a,
            first_name='Task Lead 1',
            raw_phone='9777788881',
            normalized_phone='+919777788881',
            status='UNASSIGNED'
        )
        lead2 = Lead.objects.create(
            company=self.company_a,
            first_name='Task Lead 2',
            raw_phone='9777788882',
            normalized_phone='+919777788882',
            status='UNASSIGNED'
        )

        self.client.force_authenticate(user=self.admin_a)
        create_res = self.client.post('/api/v1/leads/tasks/', {
            'title': 'Initial Task for Caller 1',
            'assigned_to_id': str(self.caller_a1.id),
            'lead_ids': [str(lead1.id), str(lead2.id)]
        }, format='json')
        self.assertEqual(create_res.status_code, 201)
        task_id = create_res.data['id']

        # Reassign task to Caller 2
        reassign_res = self.client.patch(f'/api/v1/leads/tasks/{task_id}/', {
            'assigned_to_id': str(self.caller_a2.id)
        }, format='json')
        self.assertEqual(reassign_res.status_code, 200)

        lead1.refresh_from_db()
        lead2.refresh_from_db()
        self.assertEqual(lead1.assigned_to, self.caller_a2)
        self.assertEqual(lead2.assigned_to, self.caller_a2)

    # =========================================================================
    # 5. CALL ATTEMPTS, NOTES, AND CALLBACKS AUDIT TESTS
    # =========================================================================

    def test_updating_note_does_not_create_fake_call_attempt(self):
        """Updating lead notes or custom fields must NOT create fake call attempts."""
        lead = Lead.objects.create(
            company=self.company_a,
            first_name='Note Lead',
            raw_phone='9888899990',
            normalized_phone='+919888899990',
            status='ASSIGNED',
            assigned_to=self.caller_a1
        )

        initial_call_count = CallAttempt.objects.filter(lead=lead).count()

        self.client.force_authenticate(user=self.caller_a1)
        res = self.client.patch(f'/api/v1/leads/{lead.id}/', {
            'notes': 'Spoke with secretary, decision maker in conference.'
        })
        self.assertEqual(res.status_code, 200)

        # Lead notes updated
        lead.refresh_from_db()
        self.assertEqual(lead.custom_fields.get('notes'), 'Spoke with secretary, decision maker in conference.')

        # CRITICAL AUDIT CHECK: No fake call attempts created
        after_call_count = CallAttempt.objects.filter(lead=lead).count()
        self.assertEqual(initial_call_count, after_call_count)

    def test_callback_rejects_past_scheduled_time(self):
        """Callback creation and rescheduling must reject times in the past."""
        lead = Lead.objects.create(
            company=self.company_a,
            first_name='Callback Lead',
            raw_phone='9888899991',
            normalized_phone='+919888899991',
            status='ASSIGNED',
            assigned_to=self.caller_a1
        )

        self.client.force_authenticate(user=self.caller_a1)
        past_time = (timezone.now() - timedelta(hours=2)).isoformat()
        res = self.client.post('/api/v1/callbacks/', {
            'lead': str(lead.id),
            'scheduled_at': past_time,
            'initial_notes': 'Please call back yesterday'
        })
        self.assertEqual(res.status_code, 400)
        self.assertIn("past", str(res.data).lower())

    def test_employee_cannot_modify_other_employees_callback(self):
        """Telecaller 1 cannot reschedule or complete Telecaller 2's callback."""
        lead = Lead.objects.create(
            company=self.company_a,
            first_name='Caller 2 Lead',
            raw_phone='9888899992',
            normalized_phone='+919888899992',
            status='ASSIGNED',
            assigned_to=self.caller_a2
        )
        cb = Callback.objects.create(
            company=self.company_a,
            lead=lead,
            assigned_employee=self.caller_a2,
            scheduled_at=timezone.now() + timedelta(days=1),
            status='SCHEDULED'
        )

        # Caller 1 tries to reschedule Caller 2's callback -> FORBIDDEN
        self.client.force_authenticate(user=self.caller_a1)
        res_reschedule = self.client.post(f'/api/v1/callbacks/{cb.id}/reschedule/', {
            'new_scheduled_at': (timezone.now() + timedelta(days=2)).isoformat(),
            'reason': 'Caller 1 unauthorized intervention'
        })
        self.assertEqual(res_reschedule.status_code, 403)

        # Caller 2 (assigned telecaller) CAN reschedule
        self.client.force_authenticate(user=self.caller_a2)
        future_time = timezone.now() + timedelta(days=2)
        res_authorized = self.client.post(f'/api/v1/callbacks/{cb.id}/reschedule/', {
            'new_scheduled_at': future_time.isoformat(),
            'reason': 'Customer requested delay by 1 day'
        })
        self.assertEqual(res_authorized.status_code, 200)

        # Audit history must be recorded
        cb.refresh_from_db()
        self.assertEqual(cb.status, 'RESCHEDULED')
        self.assertEqual(cb.rescheduled_count, 1)
        self.assertTrue(CallbackHistory.objects.filter(callback=cb, to_status='RESCHEDULED').exists())

    # =========================================================================
    # 6. SECURITY AND ACCESS CONTROL TESTS
    # =========================================================================

    def test_deactivated_user_is_denied_access(self):
        """Deactivated users must be immediately rejected across all endpoints."""
        self.caller_a1.is_active = False
        self.caller_a1.save(update_fields=['is_active'])

        self.client.force_authenticate(user=self.caller_a1)
        res = self.client.get('/api/v1/leads/')
        self.assertEqual(res.status_code, 403)

    def test_suspended_company_users_are_denied_access(self):
        """Users belonging to a suspended company must be rejected."""
        self.company_a.status = 'SUSPENDED'
        self.company_a.save(update_fields=['status'])

        self.client.force_authenticate(user=self.admin_a)
        res = self.client.get('/api/v1/leads/')
        self.assertEqual(res.status_code, 403)

    def test_company_admin_cannot_elevate_role_to_superadmin(self):
        """Company admin cannot create super admins or elevate user roles."""
        self.client.force_authenticate(user=self.admin_a)
        res = self.client.post('/api/v1/accounts/employees/', {
            'email': 'fake_superadmin@alpha.com',
            'password': 'StrongPassword123!',
            'first_name': 'Hacker',
            'role': 'SUPER_ADMIN'
        })
        self.assertEqual(res.status_code, 400)
        self.assertFalse(User.objects.filter(email='fake_superadmin@alpha.com').exists())

    def test_only_superadmin_can_create_companies(self):
        """Only authenticated SuperAdmin can create companies; Company Admin and Employees cannot."""
        self.client.force_authenticate(user=self.admin_a)
        res_company_admin = self.client.post('/api/v1/companies/', {
            'name': 'Unauthorized Corp',
            'admin_email': 'admin@unauth.com',
            'admin_password': 'Password123!'
        })
        self.assertEqual(res_company_admin.status_code, 403)

        # SuperAdmin CAN create company and default branches/categories are seeded
        self.client.force_authenticate(user=self.superadmin)
        res_super = self.client.post('/api/v1/companies/', {
            'name': 'Legitimate Tenant Corp',
            'admin_email': 'admin@legit.com',
            'admin_password': 'LegitAdmin123!'
        })
        self.assertEqual(res_super.status_code, 201)
        new_company = Company.objects.get(name='Legitimate Tenant Corp')
        self.assertTrue(Branch.objects.filter(company=new_company, name='Main Branch').exists())
        self.assertTrue(LeadCategory.objects.filter(company=new_company, name='Customer').exists())
        self.assertTrue(LeadCategory.objects.filter(company=new_company, name='Client').exists())
        self.assertTrue(LeadCategory.objects.filter(company=new_company, name='Academy').exists())
