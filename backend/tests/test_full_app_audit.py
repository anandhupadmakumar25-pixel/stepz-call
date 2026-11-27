from datetime import date, datetime, time, timedelta
from decimal import Decimal
from unittest.mock import patch
from django.core.files.uploadedfile import SimpleUploadedFile
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from apps.accounts.models import (
    AttendanceRecord,
    CustomRole,
    EmployeeProfile,
    LeaveBalance,
    LeaveRequest,
    LeaveType,
    SectionDelegation,
)
from apps.billing.models import DocumentTemplate, Invoice, Product, Quotation
from apps.calls.models import CallAttempt, CallRecording
from apps.companies.models import ALL_MENU_KEYS, Company, Plan
from apps.leads.models import Branch, Lead

User = get_user_model()


class FullAppLogicAuditTests(TestCase):
    def setUp(self):
        self.plan = Plan.objects.create(
            name='Pro Plan',
            code='PRO',
            max_users=50,
            max_leads=5000,
            price_monthly=Decimal('1999.00'),
            allowed_menus=list(ALL_MENU_KEYS),
        )
        self.super_a = User.objects.create_user(
            email='supera@stepz.com',
            password='Password123!',
            first_name='Super',
            last_name='A',
            role='SUPER_ADMIN',
        )
        self.super_b = User.objects.create_user(
            email='superb@stepz.com',
            password='Password123!',
            first_name='Super',
            last_name='B',
            role='SUPER_ADMIN',
        )

        self.company_a = Company.objects.create(
            name='Alpha Corp',
            subdomain='alpha',
            contact_email='admin@alpha.com',
            plan=self.plan,
            allowed_menus=list(ALL_MENU_KEYS),
            created_by=self.super_a,
        )
        self.company_b = Company.objects.create(
            name='Beta Corp',
            subdomain='beta',
            contact_email='admin@beta.com',
            plan=self.plan,
            allowed_menus=list(ALL_MENU_KEYS),
            created_by=self.super_b,
        )

        self.admin_a = User.objects.create_user(
            email='admin@alpha.com',
            password='Password123!',
            first_name='Alpha',
            last_name='Admin',
            role='COMPANY_ADMIN',
            company=self.company_a,
        )
        self.admin_b = User.objects.create_user(
            email='admin@beta.com',
            password='Password123!',
            first_name='Beta',
            last_name='Admin',
            role='COMPANY_ADMIN',
            company=self.company_b,
        )
        self.emp_role = CustomRole.objects.create(
            company=self.company_a,
            name='Caller Role',
            permissions=['leads.view_own', 'attendance.mark_own', 'leave.apply_own'],
        )
        self.emp_a = User.objects.create_user(
            email='emp@alpha.com',
            password='Password123!',
            first_name='Emp',
            last_name='Alpha',
            role='EMPLOYEE',
            company=self.company_a,
        )
        self.emp_a.custom_roles.add(self.emp_role)
        self.emp_profile = EmployeeProfile.objects.create(
            user=self.emp_a,
            shift_start_time=time(9, 30),
            shift_end_time=time(18, 0),
        )
        self.branch_a = Branch.objects.create(
            company=self.company_a,
            name='HQ Branch',
            code='HQ',
            latitude=Decimal('12.971600'),
            longitude=Decimal('77.594600'),
            radius_meters=500,
        )

    def _client(self, user):
        c = APIClient()
        c.force_authenticate(user=user)
        return c

    # ------------------------------------------------------------------
    # 1. AUTH & RBAC
    # ------------------------------------------------------------------
    def test_role_edit_updates_profile_and_enforces_lead_create(self):
        emp_client = self._client(self.emp_a)

        # Without leads.create -> 403 (not 500)
        res_denied = emp_client.post('/api/v1/leads/', {
            'first_name': 'Test Lead',
            'raw_phone': '9876543210',
        }, format='json')
        self.assertEqual(res_denied.status_code, 403)

        # Admin edits CustomRole to add leads.create
        admin_client = self._client(self.admin_a)
        res_role = admin_client.patch(f'/api/v1/accounts/roles/{self.emp_role.id}/', {
            'permissions': ['leads.view_own', 'attendance.mark_own', 'leads.create'],
        }, format='json')
        self.assertEqual(res_role.status_code, 200)

        # Employee profile immediately reflects new permission
        res_prof = emp_client.get('/api/v1/accounts/profile/')
        self.assertEqual(res_prof.status_code, 200)
        self.assertIn('leads.create', res_prof.data.get('resolved_permissions', []))

        # Employee can now create lead cleanly
        res_ok = emp_client.post('/api/v1/leads/', {
            'first_name': 'Created By Emp',
            'raw_phone': '9876543210',
        }, format='json')
        self.assertEqual(res_ok.status_code, 201)

    def test_section_delegation_grant_and_revoke(self):
        admin_client = self._client(self.admin_a)
        self.emp_role.permissions = list(set(self.emp_role.permissions + ['payroll.view_own_payslip']))
        self.emp_role.save(update_fields=['permissions'])
        emp_client = self._client(self.emp_a)

        # Before delegation -> cannot list employees
        res_before = emp_client.get('/api/v1/accounts/employees/')
        self.assertEqual(res_before.status_code, 403)

        # Delegate employees section
        res_del = admin_client.post('/api/v1/accounts/delegations/', {
            'delegatee': str(self.emp_a.id),
            'title': 'Acting HR',
            'sections': ['employees'],
            'start_date': str(timezone.localdate()),
            'end_date': str(timezone.localdate() + timedelta(days=5)),
        }, format='json')
        self.assertEqual(res_del.status_code, 201)
        del_id = res_del.data['id']

        # Now allowed
        res_during = emp_client.get('/api/v1/accounts/employees/')
        self.assertEqual(res_during.status_code, 200)

        # Revoke delegation
        res_rev = admin_client.post(f'/api/v1/accounts/delegations/{del_id}/revoke/', {}, format='json')
        self.assertEqual(res_rev.status_code, 200)

        # Denied again
        res_after = emp_client.get('/api/v1/accounts/employees/')
        self.assertEqual(res_after.status_code, 403)

    # ------------------------------------------------------------------
    # 2. SCOPED SUPER ADMIN ISOLATION
    # ------------------------------------------------------------------
    def test_scoped_super_admin_cannot_access_other_super_admins_company(self):
        super_a_client = self._client(self.super_a)
        res_detail = super_a_client.get(f'/api/v1/companies/{self.company_b.id}/')
        self.assertIn(res_detail.status_code, [403, 404])

    # ------------------------------------------------------------------
    # 3. ATTENDANCE MULTI-SESSION & EARLY CHECKOUT REASON
    # ------------------------------------------------------------------
    def test_attendance_mark_own_permission_accepted(self):
        emp_client = self._client(self.emp_a)
        r = emp_client.post('/api/v1/accounts/attendance/check-in/', {
            'latitude': 12.9716,
            'longitude': 77.5946,
        }, format='json')
        self.assertIn(
            r.status_code,
            [200, 201],
            f"Logic bug: Employee with 'attendance.mark_own' got {r.status_code} on check-in ({r.data})",
        )

    def test_attendance_multiple_sessions_and_early_checkout_reason(self):
        self.emp_role.permissions = ['leads.view_own', 'attendance.mark_own', 'attendance.punch']
        self.emp_role.save()
        emp_client = self._client(self.emp_a)
        tz = timezone.get_current_timezone()
        morning_in = timezone.make_aware(datetime.combine(timezone.localdate(), time(9, 15)), tz)
        midday_out = timezone.make_aware(datetime.combine(timezone.localdate(), time(13, 0)), tz)
        afternoon_in = timezone.make_aware(datetime.combine(timezone.localdate(), time(15, 0)), tz)
        evening_out = timezone.make_aware(datetime.combine(timezone.localdate(), time(18, 15)), tz)

        # 1st Check-in at 09:15 (on time -> PRESENT)
        with patch('django.utils.timezone.now', return_value=morning_in):
            r1 = emp_client.post('/api/v1/accounts/attendance/check-in/', {
                'latitude': 12.9716,
                'longitude': 77.5946,
            }, format='json')
        self.assertIn(r1.status_code, [200, 201])
        att1 = r1.data.get('attendance', r1.data.get('record', r1.data))
        self.assertEqual(att1['status'], 'PRESENT')

        # Duplicate check-in while open -> 400
        with patch('django.utils.timezone.now', return_value=morning_in + timedelta(minutes=5)):
            r_dup = emp_client.post('/api/v1/accounts/attendance/check-in/', {
                'latitude': 12.9716,
                'longitude': 77.5946,
            }, format='json')
        self.assertEqual(r_dup.status_code, 400)

        # Early check-out at 13:00 (< 18:00) WITHOUT reason -> 400
        with patch('django.utils.timezone.now', return_value=midday_out):
            r_out_no_reason = emp_client.post('/api/v1/accounts/attendance/check-out/', {
                'latitude': 12.9716,
                'longitude': 77.5946,
                'notes': '',
            }, format='json')
        self.assertEqual(r_out_no_reason.status_code, 400)

        # Early check-out WITH reason -> 200
        with patch('django.utils.timezone.now', return_value=midday_out):
            r_out_ok = emp_client.post('/api/v1/accounts/attendance/check-out/', {
                'latitude': 12.9716,
                'longitude': 77.5946,
                'notes': 'Client site visit',
            }, format='json')
        self.assertEqual(r_out_ok.status_code, 200)

        # 2nd Check-in same day at 15:00 -> 200/201 and NOT marked LATE
        with patch('django.utils.timezone.now', return_value=afternoon_in):
            r2 = emp_client.post('/api/v1/accounts/attendance/check-in/', {
                'latitude': 12.9716,
                'longitude': 77.5946,
            }, format='json')
        self.assertIn(r2.status_code, [200, 201])
        att2 = r2.data.get('attendance', r2.data.get('record', r2.data))
        self.assertEqual(att2['status'], 'PRESENT')

        # 2nd Check-out at 18:15 (>= 18:00) without notes -> 200
        with patch('django.utils.timezone.now', return_value=evening_out):
            r2_out = emp_client.post('/api/v1/accounts/attendance/check-out/', {
                'latitude': 12.9716,
                'longitude': 77.5946,
            }, format='json')
        self.assertEqual(r2_out.status_code, 200)

        # Today summary reflects 2 sessions and combined ~7.0h
        r_today = emp_client.get('/api/v1/accounts/attendance/today/')
        self.assertEqual(r_today.status_code, 200)
        self.assertEqual(r_today.data['sessions_today_count'], 2)
        self.assertAlmostEqual(r_today.data['total_hours_today'], 7.0, places=1)

        # Admin summary: present_count should NOT exceed total_employees when 1 employee has 2 sessions!
        admin_client = self._client(self.admin_a)
        r_admin = admin_client.get('/api/v1/accounts/attendance/records/')
        self.assertEqual(r_admin.status_code, 200)
        summary = r_admin.data['summary']
        self.assertLessEqual(
            summary['present_count'],
            summary['total_employees'],
            f"Logic bug: present_count ({summary['present_count']}) > total_employees ({summary['total_employees']}) due to multi-session double counting!",
        )

    # ------------------------------------------------------------------
    # 4. HR & LEAVES
    # ------------------------------------------------------------------
    def test_leave_rejects_invalid_date_range_and_deducts_balance_on_approve(self):
        emp_client = self._client(self.emp_a)
        admin_client = self._client(self.admin_a)
        lt = LeaveType.objects.create(
            company=self.company_a,
            name='Casual Leave',
            code='CL',
            annual_quota=10,
            is_paid=True,
        )

        # Negative date range (end_date < start_date) MUST be rejected!
        res_bad_dates = emp_client.post('/api/v1/accounts/leaves/', {
            'leave_type': str(lt.id),
            'start_date': '2026-12-10',
            'end_date': '2026-12-08',
            'reason': 'Invalid range test',
        }, format='json')
        self.assertEqual(
            res_bad_dates.status_code,
            400,
            f"Logic bug: LeaveRequest allowed end_date < start_date (status {res_bad_dates.status_code})",
        )

        # Valid 2-day leave
        res_ok = emp_client.post('/api/v1/accounts/leaves/', {
            'leave_type': str(lt.id),
            'start_date': '2026-12-15',
            'end_date': '2026-12-16',
            'reason': 'Family event',
        }, format='json')
        self.assertEqual(res_ok.status_code, 201)
        leave_id = res_ok.data['id']

        res_app = admin_client.post(f'/api/v1/accounts/leaves/{leave_id}/action/', {
            'action': 'APPROVE',
        }, format='json')
        self.assertEqual(res_app.status_code, 200)

        bal = LeaveBalance.objects.get(user=self.emp_a, leave_type=lt, year=2026)
        self.assertEqual(float(bal.used), 2.0)

    # ------------------------------------------------------------------
    # 5. ANALYTICS DISTINCT CALLS TODAY
    # ------------------------------------------------------------------
    def test_analytics_calls_today_counts_distinct_leads(self):
        lead1 = Lead.objects.create(
            company=self.company_a, first_name='L1', raw_phone='9000000001', normalized_phone='+919000000001', assigned_to=self.emp_a
        )
        lead2 = Lead.objects.create(
            company=self.company_a, first_name='L2', raw_phone='9000000002', normalized_phone='+919000000002', assigned_to=self.emp_a
        )
        # 3 calls to lead1, 1 call to lead2
        for _ in range(3):
            CallAttempt.objects.create(
                company=self.company_a, lead=lead1, employee=self.emp_a, outcome='NO_ANSWER', notes='Ring'
            )
        CallAttempt.objects.create(
            company=self.company_a, lead=lead2, employee=self.emp_a, outcome='INTERESTED', notes='Talked'
        )

        emp_client = self._client(self.emp_a)
        admin_client = self._client(self.admin_a)

        r_emp = emp_client.get('/api/v1/analytics/telecaller-dashboard/')
        r_adm = admin_client.get('/api/v1/analytics/admin-dashboard/')
        self.assertEqual(r_emp.status_code, 200)
        self.assertEqual(r_adm.status_code, 200)
        self.assertEqual(r_emp.data['kpis']['calls_today'], 2)
        self.assertEqual(r_adm.data['employee_performance'][0]['calls_today'], 2)

    # ------------------------------------------------------------------
    # 6. BILLING: QUOTATION -> INVOICE IDEMPOTENCY & PAYMENT GUARDS
    # ------------------------------------------------------------------
    def test_billing_quotation_convert_idempotency_and_payment_guards(self):
        admin_client = self._client(self.admin_a)
        lead = Lead.objects.create(
            company=self.company_a, first_name='Buyer', raw_phone='9111111111', normalized_phone='+919111111111', assigned_to=self.emp_a
        )
        res_q = admin_client.post('/api/v1/billing/quotations/', {
            'lead': str(lead.id),
            'customer_name': 'Buyer',
            'customer_phone': '9111111111',
            'subtotal': '1000.00',
            'tax_amount': '180.00',
            'grand_total': '1180.00',
            'items': [{'name': 'License', 'quantity': 2, 'unit_price': 500, 'tax_percent': 18}],
        }, format='json')
        self.assertEqual(res_q.status_code, 201)
        q_id = res_q.data['id']

        # Convert 1st time -> 201
        r_conv1 = admin_client.post(f'/api/v1/billing/quotations/{q_id}/convert-to-invoice/', {}, format='json')
        self.assertIn(r_conv1.status_code, [200, 201])
        inv_id = r_conv1.data['id']

        # Convert 2nd time -> must NOT create a duplicate invoice
        r_conv2 = admin_client.post(f'/api/v1/billing/quotations/{q_id}/convert-to-invoice/', {}, format='json')
        self.assertEqual(
            Invoice.objects.filter(quotation_id=q_id).count(),
            1,
            f"Logic bug: Converting quotation twice created duplicate invoices (status {r_conv2.status_code})",
        )

        # Partial payment
        inv = Invoice.objects.get(id=inv_id)
        half = round(float(inv.grand_total) / 2, 2)
        r_pay1 = admin_client.post(f'/api/v1/billing/invoices/{inv_id}/record-payment/', {
            'amount': half,
            'payment_mode': 'UPI',
        }, format='json')
        self.assertEqual(r_pay1.status_code, 200)
        inv.refresh_from_db()
        self.assertIn(inv.payment_status, ['PARTIAL', 'PARTIALLY_PAID'])

        # Overpayment guard
        r_over = admin_client.post(f'/api/v1/billing/invoices/{inv_id}/record-payment/', {
            'amount': float(inv.grand_total) + 1000.0,
            'payment_mode': 'CASH',
        }, format='json')
        self.assertEqual(
            r_over.status_code,
            400,
            f"Logic bug: Overpayment beyond balance_due was accepted (status {r_over.status_code})",
        )

    # ------------------------------------------------------------------
    # 7. CALL RECORDINGS TENANT ISOLATION
    # ------------------------------------------------------------------
    def test_call_recording_upload_and_cross_tenant_isolation(self):
        emp_client = self._client(self.emp_a)
        admin_b_client = self._client(self.admin_b)
        lead = Lead.objects.create(
            company=self.company_a, first_name='Rec Lead', raw_phone='9222222222', normalized_phone='+919222222222', assigned_to=self.emp_a
        )
        audio = SimpleUploadedFile('call.m4a', b'fake-m4a-bytes', content_type='audio/mp4')
        res_up = emp_client.post('/api/v1/calls/recordings/', {
            'lead': str(lead.id),
            'audio_file': audio,
            'duration_seconds': 25,
        }, format='multipart')
        self.assertEqual(res_up.status_code, 201)
        rec_id = res_up.data['id']

        # Company B admin cannot access Company A recording
        res_other = admin_b_client.get(f'/api/v1/calls/recordings/{rec_id}/')
        self.assertIn(res_other.status_code, [403, 404])

    # ------------------------------------------------------------------
    # 8. NOTIFICATIONS: TRIGGER, READ/UNREAD & PUSH TOKEN REGISTRATION
    # ------------------------------------------------------------------
    def test_notifications_trigger_read_unread_and_push_token_registration(self):
        from apps.notifications.models import Notification, PushDeviceToken

        notif = Notification.objects.create(
            company=self.company_a,
            user=self.emp_a,
            title='Callback Due',
            message='Call back Buyer in 10 minutes',
            notification_type='CALLBACK_REMINDER',
            entity_type='callback',
            entity_id='cb-123',
        )

        emp_client = self._client(self.emp_a)
        admin_client = self._client(self.admin_a)

        # Unread initially
        r_list = emp_client.get('/api/v1/notifications/')
        self.assertEqual(r_list.status_code, 200)
        self.assertEqual(r_list.data['unread_count'], 1)
        self.assertEqual(r_list.data['notifications'][0]['entity_type'], 'callback')

        # Mark read
        r_read = emp_client.post(f'/api/v1/notifications/{notif.id}/mark-read/', {}, format='json')
        self.assertEqual(r_read.status_code, 200)
        r_unread_list = emp_client.get('/api/v1/notifications/?filter=unread')
        self.assertEqual(r_unread_list.data['unread_count'], 0)
        self.assertEqual(len(r_unread_list.data['notifications']), 0)

        # Mark unread
        r_unread = emp_client.post(f'/api/v1/notifications/{notif.id}/mark-unread/', {}, format='json')
        self.assertEqual(r_unread.status_code, 200)
        r_unread_list2 = emp_client.get('/api/v1/notifications/?filter=unread')
        self.assertEqual(r_unread_list2.data['unread_count'], 1)
        self.assertEqual(len(r_unread_list2.data['notifications']), 1)

        # Push token registration + device user switch does not throw IntegrityError
        r_tok1 = emp_client.post('/api/v1/notifications/register-token/', {'token': 'fcm-tok-1', 'device_type': 'android'}, format='json')
        self.assertEqual(r_tok1.status_code, 200)
        r_tok2 = admin_client.post('/api/v1/notifications/register-token/', {'token': 'fcm-tok-1', 'device_type': 'android'}, format='json')
        self.assertEqual(r_tok2.status_code, 200)
        self.assertEqual(PushDeviceToken.objects.get(token='fcm-tok-1').user_id, self.admin_a.id)

    def test_employee_creation_with_salary_and_attendance_payroll_calculation(self):
        from datetime import date
        from apps.accounts.models import AttendanceRecord, EmployeeSalaryStructure
        from apps.companies.models import CompanyCustomRule

        admin_client = self._client(self.admin_a)
        r_emp = admin_client.post(
            '/api/v1/accounts/employees/',
            {
                'email': 'payroll_emp@companya.com',
                'password': 'Password@123!',
                'first_name': 'Payroll',
                'last_name': 'Tester',
                'role': 'EMPLOYEE',
                'basic_salary': 2000,
                'hra': 500,
                'allowances': 500,
                'pf_deduction': 100,
                'salary_currency': 'QAR',
            },
            format='json',
        )
        self.assertEqual(r_emp.status_code, 201)
        emp_id = r_emp.data['id']
        sal = EmployeeSalaryStructure.objects.get(user_id=emp_id)
        self.assertEqual(float(sal.gross_salary), 3000.0)
        self.assertEqual(sal.currency, 'QAR')

        # Multi-session check-ins on same day should count as 1 present day, plus 1 late day
        AttendanceRecord.objects.create(company=self.company_a, user_id=emp_id, date=date(2026, 11, 2), status='PRESENT')
        AttendanceRecord.objects.create(company=self.company_a, user_id=emp_id, date=date(2026, 11, 2), status='PRESENT')
        AttendanceRecord.objects.create(company=self.company_a, user_id=emp_id, date=date(2026, 11, 3), status='LATE')

        CompanyCustomRule.objects.create(
            company=self.company_a,
            name='Late Penalty',
            trigger_metric='LATE_COUNT',
            threshold_value=1,
            action_type='FLAT_AMOUNT',
            action_value=50,
            is_active=True,
        )

        r_run = admin_client.post('/api/v1/accounts/payroll-runs/', {'month': 11, 'year': 2026}, format='json')
        self.assertEqual(r_run.status_code, 201)
        run_id = r_run.data['id']

        r_detail = admin_client.get(f'/api/v1/accounts/payroll-runs/{run_id}/')
        self.assertEqual(r_detail.status_code, 200)
        slip = next(s for s in r_detail.data['payslips'] if str(s['user']) == str(emp_id))
        self.assertEqual(float(slip['present_days']), 2.0)
        self.assertEqual(slip['late_days'], 1)
        self.assertEqual(float(slip['late_deduction']), 50.0)
        self.assertEqual(float(slip['net_pay']), 2850.0)

    def test_company_creation_with_plan_and_collect_payment(self):
        from apps.companies.models import Plan, CompanySubscriptionHistory

        plan = Plan.objects.create(
            name='Pro Plan',
            code='pro_test',
            price_monthly=1000,
            price_yearly=10000,
            currency='INR',
        )
        super_client = self._client(self.super_a)

        # 1. Create company with explicit PAID status (verifies receipt_number generation & timezone import)
        r_paid = super_client.post('/api/v1/companies/', {
            'name': 'Paid Tenant Co',
            'admin_email': 'admin@paidtenant.com',
            'plan_id': str(plan.id),
            'plan_billing_cycle': 'MONTHLY',
            'initial_payment_status': 'PAID',
        }, format='json')
        self.assertEqual(r_paid.status_code, 201)
        self.assertEqual(float(r_paid.data['company']['due_amount']), 0.0)
        self.assertEqual(r_paid.data['company']['payment_status'], 'PAID')
        paid_hist = CompanySubscriptionHistory.objects.get(company_id=r_paid.data['company']['id'])
        self.assertEqual(paid_hist.payment_status, 'PAID')
        self.assertTrue(paid_hist.receipt_number.startswith('SUB-'))

        # 2. Create company with default status (defaults to DUE), then collect payment
        r_due = super_client.post('/api/v1/companies/', {
            'name': 'Due Tenant Co',
            'admin_email': 'admin@duetenant.com',
            'plan_id': str(plan.id),
            'plan_billing_cycle': 'MONTHLY',
        }, format='json')
        self.assertEqual(r_due.status_code, 201)
        self.assertEqual(float(r_due.data['company']['due_amount']), 1000.0)
        self.assertEqual(r_due.data['company']['payment_status'], 'DUE')
        due_company_id = r_due.data['company']['id']
        due_hist = CompanySubscriptionHistory.objects.get(company_id=due_company_id)
        self.assertEqual(due_hist.payment_status, 'DUE')
        self.assertEqual(float(due_hist.due_amount), 1000.0)
        self.assertEqual(due_hist.receipt_number, '')

        r_collect = super_client.post(f'/api/v1/companies/{due_company_id}/collect-payment/', {
            'amount_paid': 1000,
            'payment_mode': 'UPI',
            'transaction_ref': 'UPI-999',
        }, format='json')
        self.assertEqual(r_collect.status_code, 201)
        due_hist.refresh_from_db()
        self.assertEqual(due_hist.payment_status, 'PAID')
        self.assertEqual(float(due_hist.due_amount), 0.0)
        self.assertTrue(r_collect.data['receipt']['receipt_number'].startswith('SUB-'))

        # 3. Expired paid tenant auto-suspends and generates renewal due on fetch
        from datetime import timedelta
        from django.utils import timezone
        from apps.companies.models import Company
        paid_comp = Company.objects.get(id=r_paid.data['company']['id'])
        paid_comp.plan_expires_at = timezone.now() - timedelta(days=1)
        paid_comp.save(update_fields=['plan_expires_at'])

        r_list = super_client.get('/api/v1/companies/')
        self.assertEqual(r_list.status_code, 200)
        exp_row = next(c for c in r_list.data if c['id'] == str(paid_comp.id))
        self.assertEqual(exp_row['status'], 'SUSPENDED')
        self.assertEqual(float(exp_row['due_amount']), 1000.0)
        self.assertEqual(exp_row['payment_status'], 'PARTIAL')

    def test_checkin_menu_access_lock(self):
        from apps.companies.models import CompanyPayrollPolicy
        policy, _ = CompanyPayrollPolicy.objects.get_or_create(company=self.company_a)
        policy.require_checkin_for_menu_access = True
        policy.save(update_fields=['require_checkin_for_menu_access'])

        admin_client = self._client(self.admin_a)
        self.emp_role.permissions = list(set(self.emp_role.permissions + ['payroll.view_own_payslip']))
        self.emp_role.save(update_fields=['permissions'])
        emp_client = self._client(self.emp_a)

        # Company Admin bypasses check-in lock
        self.assertEqual(admin_client.get('/api/v1/leads/').status_code, 200)

        # Employee without active check-in is blocked from operational menus (leads)
        r_blocked = emp_client.get('/api/v1/leads/')
        self.assertEqual(r_blocked.status_code, 403)

        # Attendance & profile endpoints remain accessible so employee can punch in
        self.assertEqual(emp_client.get('/api/v1/accounts/profile/').status_code, 200)
        self.assertEqual(emp_client.get('/api/v1/accounts/attendance/today/').status_code, 200)

        # Active check-in unlocks operational menus
        att = AttendanceRecord.objects.create(
            user=self.emp_a,
            company=self.company_a,
            date=timezone.localdate(),
            check_in_time=timezone.now(),
        )
        self.assertEqual(emp_client.get('/api/v1/leads/').status_code, 200)

        # Checking out re-locks operational menus
        att.check_out_time = timezone.now()
        att.save(update_fields=['check_out_time'])
        self.assertEqual(emp_client.get('/api/v1/leads/').status_code, 403)

        # Per-employee EXEMPT override bypasses company lock
        self.emp_profile.require_checkin_override = 'EXEMPT'
        self.emp_profile.save(update_fields=['require_checkin_override'])
        self.assertEqual(emp_client.get('/api/v1/leads/').status_code, 200)

    def test_per_employee_quotation_approval_workflow(self):
        self.emp_role.permissions = [
            'quotations.view_own',
            'quotations.create',
            'quotations.edit',
            'quotations.convert_to_invoice',
        ]
        self.emp_role.save(update_fields=['permissions'])

        approver_role = CustomRole.objects.create(
            company=self.company_a,
            name='Quotation Approver Role',
            permissions=[
                'quotations.view_all',
                'quotations.create',
                'quotations.edit',
                'quotations.approve',
            ],
        )
        approver = User.objects.create_user(
            email='approver@alpha.com',
            password='Password123!',
            first_name='Quote',
            last_name='Approver',
            role='EMPLOYEE',
            company=self.company_a,
        )
        approver.custom_roles.add(approver_role)
        EmployeeProfile.objects.create(user=approver)

        self.emp_profile.require_quotation_approval = True
        self.emp_profile.quotation_approver = approver
        self.emp_profile.save(update_fields=['require_quotation_approval', 'quotation_approver'])

        emp_client = self._client(self.emp_a)
        approver_client = self._client(approver)

        # 1. Employee creates quotation -> automatically PENDING_APPROVAL
        r_create = emp_client.post('/api/v1/billing/quotations/', {
            'customer_name': 'Acme Client',
            'customer_phone': '+919999999999',
            'items': [{'description': 'Service A', 'quantity': 1, 'unit_price': 1000, 'total': 1000}],
            'subtotal': 1000,
            'grand_total': 1000,
        }, format='json')
        self.assertEqual(r_create.status_code, 201)
        self.assertEqual(r_create.data['status'], 'PENDING_APPROVAL')
        quote_id = r_create.data['id']

        # 2. Conversion blocked while PENDING_APPROVAL
        r_conv_blocked = emp_client.post(f'/api/v1/billing/quotations/{quote_id}/convert-to-invoice/', {}, format='json')
        self.assertEqual(r_conv_blocked.status_code, 403)

        # 3. Assigned approver rejects with reason
        r_reject = approver_client.post(f'/api/v1/billing/quotations/{quote_id}/approval/', {
            'action': 'REJECT',
            'rejection_reason': 'Fix unit price',
        }, format='json')
        self.assertEqual(r_reject.status_code, 200)
        self.assertEqual(r_reject.data['status'], 'REJECTED')
        self.assertEqual(r_reject.data['rejection_reason'], 'Fix unit price')

        # 4. Employee edits & resubmits -> resets to PENDING_APPROVAL
        r_patch = emp_client.patch(f'/api/v1/billing/quotations/{quote_id}/', {
            'notes': 'Updated price as requested',
        }, format='json')
        self.assertEqual(r_patch.status_code, 200)
        self.assertEqual(r_patch.data['status'], 'PENDING_APPROVAL')
        self.assertEqual(r_patch.data['rejection_reason'], '')

        # 5. Approver approves -> APPROVED, then conversion succeeds
        r_approve = approver_client.post(f'/api/v1/billing/quotations/{quote_id}/approval/', {
            'action': 'APPROVE',
        }, format='json')
        self.assertEqual(r_approve.status_code, 200)
        self.assertEqual(r_approve.data['status'], 'APPROVED')
        self.assertEqual(str(r_approve.data['approved_by']), str(approver.id))

        r_conv_ok = emp_client.post(f'/api/v1/billing/quotations/{quote_id}/convert-to-invoice/', {}, format='json')
        self.assertEqual(r_conv_ok.status_code, 201)

    def test_dynamic_payroll_rules_installments_reminders_and_payslip_template(self):
        from apps.accounts.models import EmployeeSalaryStructure, PayrollRun, Payslip, PayslipPayment
        from apps.companies.models import CompanyCustomRule, CompanyPayrollPolicy
        from apps.notifications.models import Notification

        admin_client = self._client(self.admin_a)
        self.emp_role.permissions = list(set(self.emp_role.permissions + ['payroll.view_own_payslip']))
        self.emp_role.save(update_fields=['permissions'])
        emp_client = self._client(self.emp_a)

        # Configure payroll policy: Fixed 26 days, salary day 5, auto_deduct_absent_lop=False for clean rule isolation
        policy, _ = CompanyPayrollPolicy.objects.get_or_create(company=self.company_a)
        policy.pay_calculation_basis = 'FIXED_26_DAYS'
        policy.salary_day = 5
        policy.reminder_days_before = 3
        policy.auto_deduct_absent_lop = False
        policy.save()

        # Late rule: every 2 lates beyond 1 free allowance = 0.5 day LOP
        CompanyCustomRule.objects.create(
            company=self.company_a,
            name='Late Coming LOP',
            category='LATE_ARRIVAL',
            trigger_metric='LATE_COUNT',
            operator='EVERY_N',
            threshold_value=Decimal('2.00'),
            free_allowance_count=1,
            action_type='LOP_DAYS',
            action_value=Decimal('0.50'),
            is_active=True,
        )

        # Salary structure: 26,000 gross (1,000/day)
        EmployeeSalaryStructure.objects.create(
            company=self.company_a,
            user=self.emp_a,
            currency='INR',
            basic_salary=Decimal('20000.00'),
            hra=Decimal('4000.00'),
            allowances=Decimal('2000.00'),
        )

        # 3 LATE days in Nov 2026 -> (3 - 1) // 2 = 1 trigger -> 0.5 day LOP (500.00)
        for day_num in (2, 3, 4):
            AttendanceRecord.objects.create(
                company=self.company_a,
                user=self.emp_a,
                date=date(2026, 11, day_num),
                status='LATE',
                check_in_time=timezone.now(),
            )

        # 1 day Unpaid Leave
        unpaid_lt = LeaveType.objects.create(
            company=self.company_a,
            name='Loss of Pay',
            code='LOP',
            annual_quota=10,
            is_paid=False,
        )
        LeaveRequest.objects.create(
            company=self.company_a,
            user=self.emp_a,
            leave_type=unpaid_lt,
            start_date=date(2026, 11, 10),
            end_date=date(2026, 11, 10),
            days_count=Decimal('1.0'),
            reason='Personal',
            status='APPROVED',
            reviewed_by=self.admin_a,
        )

        # 1. Generate Payroll Run for Nov 2026
        r_gen = admin_client.post('/api/v1/accounts/payroll-runs/', {'month': 11, 'year': 2026}, format='json')
        self.assertEqual(r_gen.status_code, 201)
        run_id = r_gen.data['id']

        r_detail = admin_client.get(f'/api/v1/accounts/payroll-runs/{run_id}/')
        self.assertEqual(r_detail.status_code, 200)
        slip = r_detail.data['payslips'][0]
        slip_id = slip['id']
        self.assertEqual(float(slip['unpaid_leave_days']), 1.0)
        self.assertEqual(float(slip['lop_deduction']), 1000.0)
        self.assertEqual(float(slip['late_deduction']), 500.0)
        self.assertEqual(float(slip['net_pay']), 24500.0)
        self.assertEqual(float(slip['balance_due']), 24500.0)
        self.assertEqual(slip['payment_status'], 'UNPAID')
        self.assertTrue(len(slip['rule_breakdown']) >= 1)

        # 2. Adjust bonus while DRAFT (+500 -> net 25,000)
        r_patch = admin_client.patch(f'/api/v1/accounts/payslips/{slip_id}/', {'bonus': 500}, format='json')
        self.assertEqual(r_patch.status_code, 200)
        self.assertEqual(float(r_patch.data['net_pay']), 25000.0)
        self.assertEqual(float(r_patch.data['balance_due']), 25000.0)

        # 3. Overpayment guard (400)
        r_over = admin_client.post(f'/api/v1/accounts/payslips/{slip_id}/pay/', {
            'amount': 30000,
            'payment_mode': 'BANK_TRANSFER',
        }, format='json')
        self.assertEqual(r_over.status_code, 400)

        # 4. Pay partial installment (10,000) -> PARTIAL, balance 15,000, receipt SAL-2026-0001
        r_part = admin_client.post(f'/api/v1/accounts/payslips/{slip_id}/pay/', {
            'amount': 10000,
            'payment_mode': 'BANK_TRANSFER',
            'transaction_ref': 'TXN-101',
        }, format='json')
        self.assertEqual(r_part.status_code, 201)
        self.assertEqual(r_part.data['payment']['receipt_number'], 'SAL-2026-0001')
        self.assertEqual(r_part.data['payslip']['payment_status'], 'PARTIAL')
        self.assertEqual(float(r_part.data['payslip']['balance_due']), 15000.0)

        # Employee received Salary Credited notification
        self.assertTrue(Notification.objects.filter(user=self.emp_a, title='Salary Credited').exists())

        # 5. Overdue reminder check (set due_date in past) + deduplication
        Payslip.objects.filter(id=slip_id).update(due_date=timezone.localdate() - timedelta(days=1))
        r_rem1 = admin_client.post('/api/v1/accounts/payroll-reminders/check/', {}, format='json')
        self.assertEqual(r_rem1.status_code, 200)
        self.assertEqual(r_rem1.data['dispatched'], 1)
        r_rem2 = admin_client.post('/api/v1/accounts/payroll-reminders/check/', {}, format='json')
        self.assertEqual(r_rem2.data['dispatched'], 0)

        # 6. Pay remaining balance (15,000) -> PAID & PayrollRun auto-marked PAID
        r_full = admin_client.post(f'/api/v1/accounts/payslips/{slip_id}/pay/', {
            'amount': 15000,
            'payment_mode': 'CASH',
        }, format='json')
        self.assertEqual(r_full.status_code, 201)
        self.assertEqual(r_full.data['payslip']['payment_status'], 'PAID')
        self.assertEqual(float(r_full.data['payslip']['balance_due']), 0.0)
        self.assertEqual(PayrollRun.objects.get(id=run_id).status, 'PAID')

        # Employee can fetch own payslips with installment history
        r_my = emp_client.get('/api/v1/accounts/my-payslips/')
        self.assertEqual(r_my.status_code, 200)
        self.assertEqual(len(r_my.data[0]['payments']), 2)

        # 7. Save & retrieve PAYSLIP DocumentTemplate
        r_tpl = admin_client.post('/api/v1/billing/templates/', {
            'name': 'Default Corporate Payslip',
            'doc_type': 'PAYSLIP',
            'is_default': True,
            'layout_json': {'theme': {'primary_color': '#047857'}},
        }, format='json')
        self.assertEqual(r_tpl.status_code, 201)
        self.assertEqual(r_tpl.data['doc_type'], 'PAYSLIP')
