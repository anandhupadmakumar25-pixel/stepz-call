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
