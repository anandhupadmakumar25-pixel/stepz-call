from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple
import openpyxl
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

from automation_tests.excel_reporter import TestCaseResult

# Exact 46-case catalog matching the user's QA sheet
CASES_46: List[Tuple[str, str, str, str, str, str]] = [
    ("Section 1: Master Admin, Super Admin & Tenant Onboarding", "1.1 Root Master Admin & Scoped Super Admin", "AUTH-01", "Root Master Admin Login", "Log in as Master Admin.", "Master Command, Tenants, Subscription Plans, and Platform Billing appear in the sidebar."),
    ("Section 1: Master Admin, Super Admin & Tenant Onboarding", "1.1 Root Master Admin & Scoped Super Admin", "AUTH-02", "Scoped Super Admin Isolation", "Log in as Super Admin A -> open My Tenants.", "Only tenants created by or assigned to Super Admin A are visible; other Super Admins' tenants are hidden."),
    ("Section 1: Master Admin, Super Admin & Tenant Onboarding", "1.2 Subscription Plans & Company Onboarding", "TEN-01", "Create Plan", "Open Subscription Plans -> click Create Plan -> set Name, Code, Price, Currency, Allowed Menus -> Save.", "Plan appears in list with selected currency and menu permissions."),
    ("Section 1: Master Admin, Super Admin & Tenant Onboarding", "1.2 Subscription Plans & Company Onboarding", "TEN-02", "Onboard Paid Company", "Open Tenants / My Tenants -> create company with Initial Payment Status = PAID.", "Company status is ACTIVE, due_amount = 0, and a SUB- receipt is generated."),
    ("Section 1: Master Admin, Super Admin & Tenant Onboarding", "1.2 Subscription Plans & Company Onboarding", "TEN-03", "Onboard Due Company & Collect Payment", "Create company with Initial Payment Status = DUE -> click Collect Payment -> enter amount, select mode -> Submit.", "Due amount decreases; when due_amount == 0, status updates to PAID and a SUB- receipt is issued."),
    ("Section 1: Master Admin, Super Admin & Tenant Onboarding", "1.2 Subscription Plans & Company Onboarding", "TEN-04", "Plan Expiry Auto-Suspension", "For an expired tenant, refresh Tenants or log in as that Company Admin.", "Tenant status shows SUSPENDED and renewal due is generated."),
    ("Section 2: Company Settings, Branches, Rules & Check-In Lock", "2.1 Branches & Geofencing", "BR-01", "Create Branch with GPS", "Go to Company Settings -> Branches -> Add Branch -> enter Name, Code, Latitude, Longitude, Radius (m), enable Geofence -> Save.", "Branch saves and appears in dropdowns across Employees and Quotations."),
    ("Section 2: Company Settings, Branches, Rules & Check-In Lock", "2.2 Company Rules & Payroll Policy", "RULE-01", "Shift, Payday & Absent LOP Policy", "Go to Company Settings -> Company Rules -> set Shift Start/End, Grace Period, Hours, Salary Payday (1-31), Reminder Days Before, Pay Basis -> Save.", "Toast confirms policy saved; reloading the tab retains all values."),
    ("Section 2: Company Settings, Branches, Rules & Check-In Lock", "2.2 Company Rules & Payroll Policy", "RULE-02", "Create Late Coming Rule", "In Company Rules, add Custom Rule: LATE_ARRIVAL, LATE_COUNT, EVERY_N, Threshold 2, Free 1, LOP_DAYS 0.5 -> Save.", "Rule appears active and is included in next payroll generation."),
    ("Section 2: Company Settings, Branches, Rules & Check-In Lock", "2.2 Company Rules & Payroll Policy", "RULE-03", "Toggle Must Check-In to Access Menus (ON)", "Turn ON Must Check-In to Access Menus -> Save.", "Policy saves cleanly."),
    ("Section 3: Employees, Roles, Delegation & Access Controls", "3.1 Custom Roles & Section Delegation", "ROLE-01", "Create & Edit Custom Role", "Go to Employees & Roles -> Roles -> create role with leads, attendance, leave, and quotation permissions -> Save.", "Role appears in chip list when creating/editing employees."),
    ("Section 3: Employees, Roles, Delegation & Access Controls", "3.1 Custom Roles & Section Delegation", "ROLE-02", "Section Delegation", "Grant temporary delegation to an employee for a section, then revoke it.", "While active, employee sees Delegated badge and section; after revoke, access is removed."),
    ("Section 3: Employees, Roles, Delegation & Access Controls", "3.2 Employee Creation & Per-Employee Controls", "EMP-01", "Create Employee with Joining Date & Controls", "Add Employee -> fill details, Branch, Department, Joining Date, Custom Role, Check-In Override, Require Quotation Approval + Approver -> Save.", "Employee is created; editing the employee shows all saved values accurately."),
    ("Section 4: Active Check-In Menu Lock Flow (End-to-End)", "3.2 Employee Creation & Per-Employee Controls", "CHK-01", "Locked Before Check-In", "With Must Check-In to Access Menus = ON, log in as an employee (INHERIT/REQUIRED).", "Sidebar shows only My Workspace, My Attendance & Punch, and Leave & Payroll."),
    ("Section 4: Active Check-In Menu Lock Flow (End-to-End)", "3.2 Employee Creation & Per-Employee Controls", "CHK-02", "Dashboard & Top-Bar Locked", "On My Workspace before checking in, inspect the screen and top bar.", "Add Lead, Tasks, KPI cards, Calling Queue, All Leads, Callbacks, and Quotation buttons are hidden; Check-In Required card shown."),
    ("Section 4: Active Check-In Menu Lock Flow (End-to-End)", "3.2 Employee Creation & Per-Employee Controls", "CHK-03", "Notification Deep-Link Guard", "Open Notification Drawer while locked and tap a Lead/Quotation notification.", "Redirects to Attendance with 'Please check in first to access this section.'"),
    ("Section 4: Active Check-In Menu Lock Flow (End-to-End)", "3.2 Employee Creation & Per-Employee Controls", "CHK-04", "Check-In Unlocks Everything", "Click Check In on the Dashboard Punch card or Attendance screen.", "Sidebar menus, Dashboard Calling Queue, KPI cards, and top-bar Add Lead unlock immediately."),
    ("Section 4: Active Check-In Menu Lock Flow (End-to-End)", "3.2 Employee Creation & Per-Employee Controls", "CHK-05", "Check-Out Re-Locks Everything", "Click Check Out (enter early checkout reason if before shift end).", "Operational menus and dashboard queue immediately lock again."),
    ("Section 4: Active Check-In Menu Lock Flow (End-to-End)", "3.2 Employee Creation & Per-Employee Controls", "CHK-06", "Per-Employee EXEMPT & Admin Bypass", "Set employee override to EXEMPT and test; also test as COMPANY_ADMIN.", "Both EXEMPT employees and COMPANY_ADMIN access all assigned menus without checking in."),
    ("Section 4: Active Check-In Menu Lock Flow (End-to-End)", "3.2 Employee Creation & Per-Employee Controls", "CHK-07", "Toggle OFF Globally", "Turn OFF Must Check-In to Access Menus in Company Rules -> Save -> refresh as employee.", "Employee accesses all assigned menus without needing an active check-in."),
    ("Section 5: Attendance, Leaves & Holiday Calendar", "5.1 Attendance & Regularization", "ATT-01", "Multi-Session Check-In / Out", "Check in, check out, then check in and check out again on the same day.", "Both sessions appear; total working hours sum both; payroll counts 1 present day."),
    ("Section 5: Attendance, Leaves & Holiday Calendar", "5.1 Attendance & Regularization", "ATT-02", "Out-of-Fence Warning / Strict Block", "Test punch outside branch radius with Strict Block OFF vs ON.", "OFF allows punch with OUT_OF_FENCE flag; ON blocks punch with error."),
    ("Section 5: Attendance, Leaves & Holiday Calendar", "5.1 Attendance & Regularization", "ATT-03", "Attendance Regularization", "Employee submits regularization for a missed punch -> Admin approves.", "Attendance record updates and reflects in payroll."),
    ("Section 5: Attendance, Leaves & Holiday Calendar", "5.2 Holidays & Leave Management", "LEV-01", "Add Company Holiday", "In Leave & Payroll -> Leaves & Holidays, Admin adds a mandatory holiday in the current month.", "Holiday appears on list and reduces working_days in payroll generation."),
    ("Section 5: Attendance, Leaves & Holiday Calendar", "5.2 Holidays & Leave Management", "LEV-02", "Create Paid & Unpaid Leave Types", "Create Annual Leave (is_paid=True) and Loss of Pay (is_paid=False).", "Both leave types appear in the Apply Leave dropdown."),
    ("Section 5: Attendance, Leaves & Holiday Calendar", "5.2 Holidays & Leave Management", "LEV-03", "Apply & Approve Leave", "Employee applies for Paid Leave (1d) and Unpaid Leave (1d); test invalid end < start first.", "Invalid date range rejected; valid requests approved and deduct Leave Balance."),
    ("Section 6: Dynamic Payroll, Installments, Reminders & Payslip PDF Designer", "6.1 Salary Configuration & Payroll Generation", "PAY-01", "Configure Salary Structure", "Go to Payroll Runs -> Configure Employee Salary -> set Basic, HRA, Allowances, PF, Tax, Payday Override -> Save.", "Structure appears in Configured Salary Structures."),
    ("Section 6: Dynamic Payroll, Installments, Reminders & Payslip PDF Designer", "6.1 Salary Configuration & Payroll Generation", "PAY-02", "Generate Monthly Payroll", "Click Generate Monthly Payroll -> select Month/Year -> Generate.", "Payroll Run is created in DRAFT status."),
    ("Section 6: Dynamic Payroll, Installments, Reminders & Payslip PDF Designer", "6.1 Salary Configuration & Payroll Generation", "PAY-03", "Verify Rules-Based Calculations", "Click View Slips -> inspect employee payslip.", "working_days, paid/unpaid leave, absent, late, LOP/late deductions, rule_breakdown, due_date, net_pay, balance_due match rules."),
    ("Section 6: Dynamic Payroll, Installments, Reminders & Payslip PDF Designer", "6.1 Salary Configuration & Payroll Generation", "PAY-04", "Adjust Draft Payslip", "Click Adjust on a DRAFT payslip -> add Bonus or Other Deductions -> Save.", "net_pay, balance_due, and Payroll Run totals recalculate immediately."),
    ("Section 6: Dynamic Payroll, Installments, Reminders & Payslip PDF Designer", "6.2 Installment Payments, Balance Due & Reminders", "PAY-05", "Overpayment Guard", "Click Pay / Installment -> enter amount > balance_due -> Submit.", "Blocked with validation message."),
    ("Section 6: Dynamic Payroll, Installments, Reminders & Payslip PDF Designer", "6.2 Installment Payments, Balance Due & Reminders", "PAY-06", "Partial Installment Payment", "Pay half of balance_due via Bank Transfer/Cash/Card/Cheque/Online Transfer (no UPI).", "Receipt SAL-YYYY-NNNN created; PARTIAL status; balance_due updates; employee notified."),
    ("Section 6: Dynamic Payroll, Installments, Reminders & Payslip PDF Designer", "6.2 Installment Payments, Balance Due & Reminders", "PAY-07", "Full Remaining Balance & Auto-Complete", "Pay remaining balance_due via Pay / Installment (or Mark Paid).", "balance_due=0, payment_status=PAID, PayrollRun auto-marks PAID."),
    ("Section 6: Dynamic Payroll, Installments, Reminders & Payslip PDF Designer", "6.2 Installment Payments, Balance Due & Reminders", "PAY-08", "Payday & Overdue Reminders", "Click Check Salary Reminders (or load Payroll Runs when due/overdue).", "Admin receives Payday/Overdue reminder; deduplicated on repeat."),
    ("Section 6: Dynamic Payroll, Installments, Reminders & Payslip PDF Designer", "6.3 Admin Payslip PDF Designer & Employee Payslips", "PAY-09", "Design Payslip PDF Template", "Click Payslip PDF Design -> customize Salary Payslip (PAYSLIP) -> Save as Default.", "Template saves under PAYSLIP doc type."),
    ("Section 6: Dynamic Payroll, Installments, Reminders & Payslip PDF Designer", "6.3 Admin Payslip PDF Designer & Employee Payslips", "PAY-10", "Export Payslip PDF (Admin & Employee)", "Click PDF button on a payslip in Payroll Runs and My Payslips.", "PDF uses active PAYSLIP theme and displays Earnings, Deductions, Rules, Net/Paid/Balance Due, and Installments."),
    ("Section 7: Leads, Calling Queue, Recordings & Callbacks", "7.1 Leads & Calling", "CRM-01", "Create, Edit & Update Lead Status", "Open Leads -> Add Lead -> Edit Lead -> change status across every dropdown option -> Save.", "Lead saves cleanly with zero 400 errors on any status."),
    ("Section 7: Leads, Calling Queue, Recordings & Callbacks", "7.1 Leads & Calling", "CRM-02", "Calling Queue & Log Call", "From My Workspace (checked in), click Call / Log Outcome -> submit outcome + callback.", "Call attempt logs in Call History and callback appears in Callbacks."),
    ("Section 7: Leads, Calling Queue, Recordings & Callbacks", "7.1 Leads & Calling", "CRM-03", "Call Recording Upload", "Upload an audio recording for a call and play it in Call Recordings.", "Plays cleanly; other tenants cannot see or access it."),
    ("Section 8: Document Templates, Quotations, Approval Workflow & Billing", "8.1 Template Columns & PDF Preview", "DOC-01", "Custom Columns in Form & PDF", "Create/Edit Quotation Template with custom columns -> open Generate Quotation -> select template.", "All template columns appear in both form table and live PDF preview."),
    ("Section 8: Document Templates, Quotations, Approval Workflow & Billing", "8.2 Per-Employee Quotation Approval Workflow", "QTA-01", "Submit Quotation Requiring Approval", "Log in as approval-required employee -> create quotation (Save, Save & PDF, Save & WhatsApp).", "Saves as PENDING_APPROVAL; PDF/WhatsApp locked; Admin & Approver notified."),
    ("Section 8: Document Templates, Quotations, Approval Workflow & Billing", "8.2 Per-Employee Quotation Approval Workflow", "QTA-02", "Pending Approval Filter & Locked Actions", "Log in as Approver -> Quotations -> Pending Approval filter -> open quotation.", "Filter shows pending quotes; WhatsApp/PDF/Convert locked; Approve & Reject buttons visible."),
    ("Section 8: Document Templates, Quotations, Approval Workflow & Billing", "8.2 Per-Employee Quotation Approval Workflow", "QTA-03", "Reject -> Edit -> Resubmit -> Approve", "Reject with reason -> employee edits & saves -> Approver clicks Approve.", "Rejection locks quote; edit resets to PENDING_APPROVAL; Approve sets APPROVED and unlocks actions."),
    ("Section 8: Document Templates, Quotations, Approval Workflow & Billing", "8.2 Per-Employee Quotation Approval Workflow", "QTA-04", "Convert to Fixed Price Bill & Receipt", "Click Convert to Fixed Price Bill -> Record Payment -> Save.", "Quotation becomes CONVERTED; duplicate conversion blocked; Invoice balance_due updates & Receipt generated."),
    ("Section 9: Notification Drawer & UI Polish", "9.1 Notification Drawer", "UI-01", "Notification Drawer Header", "With >=1 unread notification, open Notifications drawer.", "Bell, Notifications, unread badge, and Mark all read align cleanly with zero overflow."),
    ("Section 9: Notification Drawer & UI Polish", "9.1 Notification Drawer", "UI-02", "Mark Read / Mark All Read / Deep Link", "Click Mark read, Mark all read, and tap a notification card.", "Counts update immediately; tapping navigates to matching section (or Attendance if locked)."),
]


def save_46_case_excel(results: List[TestCaseResult], output_path: Path, tester_name: str = 'Automated Runner') -> Path:
    by_id: Dict[str, TestCaseResult] = {r.case_id: r for r in results}
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = 'Test Execution'

    header_fill = PatternFill(start_color='1E3A8A', end_color='1E3A8A', fill_type='solid')
    header_font = Font(color='FFFFFF', bold=True, size=11)
    pass_fill = PatternFill(start_color='D1FAE5', end_color='D1FAE5', fill_type='solid')
    pass_font = Font(color='047857', bold=True)
    fail_fill = PatternFill(start_color='FEE2E2', end_color='FEE2E2', fill_type='solid')
    fail_font = Font(color='B91C1C', bold=True)
    block_fill = PatternFill(start_color='FEF3C7', end_color='FEF3C7', fill_type='solid')
    block_font = Font(color='B45309', bold=True)
    thin = Side(style='thin', color='CBD5E1')
    border = Border(left=thin, right=thin, top=thin, bottom=thin)

    today_str = datetime.now().strftime('%Y-%m-%d %H:%M')

    # Calculate counts
    statuses = []
    for _, _, cid, *_ in CASES_46:
        r = by_id.get(cid)
        if not r:
            statuses.append('Not Run')
        elif r.status == 'PASS':
            statuses.append('Pass')
        elif r.status == 'FAIL':
            statuses.append('Fail')
        elif r.status == 'SKIPPED':
            statuses.append('Blocked')
        else:
            statuses.append('Not Run')

    ws['A1'] = 'COMPLETE END-TO-END MANUAL & AUTOMATED TESTING REPORT'
    ws['A1'].font = Font(bold=True, size=14, color='0F172A')
    ws['A2'] = f'Total Test Cases: {len(CASES_46)} | Passed: {statuses.count("Pass")} | Failed: {statuses.count("Fail")} | Blocked: {statuses.count("Blocked")} | Not Run: {statuses.count("Not Run")}'
    ws['A2'].font = Font(bold=True, size=11, color='334155')

    headers = [
        'Section', 'Subsection', 'Case ID', 'Test Case', 'Test Steps',
        'Expected Result', 'Status', 'Actual Result / Notes',
        'Bug Report / Issue Details', 'Tester / Date',
    ]
    for c_idx, h in enumerate(headers, start=1):
        cell = ws.cell(row=4, column=c_idx, value=h)
        cell.fill = header_fill
        cell.font = header_font
        cell.border = border
        cell.alignment = Alignment(vertical='center', wrap_text=True)

    for idx, (sec, subsec, cid, title, steps, expected) in enumerate(CASES_46, start=5):
        r = by_id.get(cid)
        status_lbl = statuses[idx - 5]
        actual = r.actual if r else ''
        bug = ''
        if r and (r.error_detail or r.screenshot_path):
            bug = f'{r.error_detail}\n{("Screenshot: " + r.screenshot_path) if r.screenshot_path else ""}'.strip()
        tester_col = f'{tester_name} ({today_str})' if r else ''

        row_vals = [sec, subsec, cid, title, steps, expected, status_lbl, actual, bug, tester_col]
        for c_idx, v in enumerate(row_vals, start=1):
            cell = ws.cell(row=idx, column=c_idx, value=v)
            cell.border = border
            cell.alignment = Alignment(vertical='top', wrap_text=True)
            if c_idx == 7:
                if status_lbl == 'Pass':
                    cell.fill = pass_fill
                    cell.font = pass_font
                elif status_lbl == 'Fail':
                    cell.fill = fail_fill
                    cell.font = fail_font
                elif status_lbl == 'Blocked':
                    cell.fill = block_fill
                    cell.font = block_font

    widths = [30, 26, 10, 28, 42, 42, 12, 34, 38, 22]
    for c_idx, w in enumerate(widths, start=1):
        ws.column_dimensions[get_column_letter(c_idx)].width = w
    ws.freeze_panes = 'A5'

    output_path.parent.mkdir(parents=True, exist_ok=True)
    wb.save(output_path)
    return output_path
