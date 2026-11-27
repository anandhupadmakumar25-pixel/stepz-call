import os
import sys
import time
import unittest
from pathlib import Path
from typing import List

from automation_tests.config import ROOT_DIR
from automation_tests.excel_reporter import TestCaseResult

# Mapping from Django test method names -> human-readable QA metadata
CASE_METADATA = {
    'test_scoped_super_admin_cannot_access_other_super_admins_company': (
        'AUTH-02',
        '1. Multi-Tenant & Auth',
        'Scoped Super Admin Tenant Isolation',
        'Authenticate as Super Admin A and Super Admin B; attempt cross-tenant company access.',
        'Super Admin B is blocked (403/404) from Super Admin A companies.',
    ),
    'test_company_creation_with_plan_and_collect_payment': (
        'TEN-02',
        '2. Plans & Onboarding',
        'Company Onboarding, Due Collection & Expiry Suspension',
        'Create PAID & DUE companies, collect payment, simulate plan expiry.',
        'PAID issues SUB- receipt; DUE updates on collection; expired tenant auto-suspends.',
    ),
    'test_role_edit_updates_profile_and_enforces_lead_create': (
        'ROLE-01',
        '3. Employees & RBAC',
        'Custom Role Update & Lead Create Enforcement',
        'Update employee profile & custom role permissions; test lead creation.',
        'Updated permissions take effect immediately on lead endpoints.',
    ),
    'test_section_delegation_grant_and_revoke': (
        'ROLE-02',
        '3. Employees & RBAC',
        'Section Delegation Grant & Revoke',
        'Grant temporary section delegation to employee, verify access, then revoke.',
        'Delegated access works while active and is revoked immediately.',
    ),
    'test_checkin_menu_access_lock': (
        'CHK-01',
        '4. Check-In Menu Lock',
        'Must Check-In to Access Menus (Lock, Unlock, Re-Lock & Exempt)',
        'Enable company check-in lock; test before check-in, during active check-in, after check-out, and EXEMPT override.',
        'Admin & EXEMPT bypass; employee blocked (403) before check-in and after check-out, unlocked (200) while checked in.',
    ),
    'test_attendance_mark_own_permission_accepted': (
        'ATT-01',
        '5. Attendance & Leaves',
        'Attendance Mark Own Permission',
        'Employee with attendance.mark_own punches in via API.',
        'Check-in succeeds (200/201) without requiring admin role.',
    ),
    'test_attendance_multiple_sessions_and_early_checkout_reason': (
        'ATT-02',
        '5. Attendance & Leaves',
        'Multi-Session Punch & Early Checkout Reason',
        'Check in, check out early with reason, check in and out again same day.',
        'Both sessions recorded cleanly with early checkout reason preserved.',
    ),
    'test_leave_rejects_invalid_date_range_and_deducts_balance_on_approve': (
        'LEV-01',
        '5. Attendance & Leaves',
        'Leave Validation & Balance Deduction on Approval',
        'Submit invalid date range, then valid leave request; approve as Admin.',
        'Invalid range rejected (400); approval deducts leave balance.',
    ),
    'test_employee_creation_with_salary_and_attendance_payroll_calculation': (
        'PAY-01',
        '6. Dynamic Payroll',
        'Employee Salary Structure & Basic Payroll Calculation',
        'Create employee with salary structure, log attendance/late, generate payroll.',
        'Net pay and deductions match configured salary and attendance.',
    ),
    'test_dynamic_payroll_rules_installments_reminders_and_payslip_template': (
        'PAY-02',
        '6. Dynamic Payroll',
        'Rules Engine, Installments, Reminders & Payslip PDF Template',
        'Apply EVERY_N late rule & unpaid leave, adjust draft, test overpayment guard, pay installments, trigger reminders, save PAYSLIP template.',
        'Rule breakdown accurate; overpayment blocked (400); SAL- receipts issued; reminders deduplicated; PAYSLIP template saved.',
    ),
    'test_analytics_calls_today_counts_distinct_leads': (
        'CRM-01',
        '7. Leads & Calls',
        'Analytics Calls Today Distinct Lead Count',
        'Log multiple call attempts on same lead and check analytics.',
        'Distinct lead call count is accurate.',
    ),
    'test_call_recording_upload_and_cross_tenant_isolation': (
        'CRM-02',
        '7. Leads & Calls',
        'Call Recording Upload & Cross-Tenant Isolation',
        'Upload recording in Company A; attempt access from Company B.',
        'Company A plays recording; Company B is blocked.',
    ),
    'test_per_employee_quotation_approval_workflow': (
        'QTA-01',
        '8. Quotations & Billing',
        'Per-Employee Quotation Approval Workflow',
        'Employee creates quotation -> PENDING_APPROVAL -> conversion blocked -> Approver rejects -> Employee edits -> Approver approves -> Convert.',
        'Conversion blocked until APPROVED; edit resets to PENDING_APPROVAL; conversion succeeds after approval.',
    ),
    'test_billing_quotation_convert_idempotency_and_payment_guards': (
        'BIL-01',
        '8. Quotations & Billing',
        'Quotation Conversion Idempotency & Invoice Payment Guards',
        'Convert quotation to invoice twice; attempt invoice overpayment.',
        'Second conversion rejected (400); overpayment rejected (400).',
    ),
    'test_notifications_trigger_read_unread_and_push_token_registration': (
        'NOTIF-01',
        '9. Notifications',
        'Notification Trigger, Read/Unread & Push Token Registration',
        'Trigger notification, toggle read/unread, register FCM push token.',
        'Unread counts update accurately and device token registers.',
    ),
}


class _CapturingResult(unittest.TextTestResult):
    def __init__(self, stream, descriptions, verbosity):
        super().__init__(stream, descriptions, verbosity)
        self.case_records: List[TestCaseResult] = []
        self._start_times = {}

    def startTest(self, test):
        super().startTest(test)
        self._start_times[test] = time.perf_counter()

    def _record(self, test, status: str, error_detail: str = ''):
        elapsed_ms = int((time.perf_counter() - self._start_times.get(test, time.perf_counter())) * 1000)
        method_name = getattr(test, '_testMethodName', str(test))
        meta = CASE_METADATA.get(
            method_name,
            (
                method_name.upper()[:12],
                'Backend API Suite',
                method_name,
                'Automated Django TestCase execution',
                'Test passes without errors',
            ),
        )
        case_id, section, title, steps, expected = meta
        actual = 'All assertions passed' if status == 'PASS' else 'Assertion or runtime error occurred'
        self.case_records.append(
            TestCaseResult(
                case_id=case_id,
                section=section,
                title=title,
                steps=steps,
                expected=expected,
                actual=actual,
                status=status,
                duration_ms=elapsed_ms,
                error_detail=error_detail,
            )
        )

    def addSuccess(self, test):
        super().addSuccess(test)
        self._record(test, 'PASS')

    def addFailure(self, test, err):
        super().addFailure(test, err)
        self._record(test, 'FAIL', self._exc_info_to_string(err, test))

    def addError(self, test, err):
        super().addError(test, err)
        self._record(test, 'FAIL', self._exc_info_to_string(err, test))


def run_api_e2e_suite() -> List[TestCaseResult]:
    backend_dir = str(ROOT_DIR / 'backend')
    if backend_dir not in sys.path:
        sys.path.insert(0, backend_dir)
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

    import django
    from django.test.utils import setup_test_environment, teardown_test_environment, setup_databases, teardown_databases

    django.setup()
    setup_test_environment()
    old_config = setup_databases(verbosity=0, interactive=False)
    try:
        suite = unittest.defaultTestLoader.loadTestsFromName('tests.test_full_app_audit')
        runner = unittest.TextTestRunner(verbosity=2, resultclass=_CapturingResult)
        result = runner.run(suite)
        return result.case_records
    finally:
        teardown_databases(old_config, verbosity=0)
        teardown_test_environment()
