"""
Canonical Permission & Dynamic Section Catalog.
Single source of truth for:
- Module -> Company Menu Key mapping
- Granular `module.action` permission keys
- Human-readable labels, descriptions, and grouping for CustomRoles & SectionDelegation
- Default role permission presets (Manager, Telecaller, Accountant, HR)
"""

PERMISSION_GROUPS = [
    {
        'key': 'leads',
        'label': 'Leads & Pipeline',
        'menu_key': 'leads',
        'icon': 'people',
        'permissions': [
            {'key': 'leads.view_own', 'label': 'View Assigned Leads', 'description': 'View leads assigned to self'},
            {'key': 'leads.view_all', 'label': 'View All Company Leads', 'description': 'View all leads across branches/teams'},
            {'key': 'leads.create', 'label': 'Create Leads', 'description': 'Add new leads manually'},
            {'key': 'leads.edit', 'label': 'Edit Leads', 'description': 'Update lead details and status'},
            {'key': 'leads.delete', 'label': 'Delete Leads', 'description': 'Permanently delete leads'},
            {'key': 'leads.assign', 'label': 'Assign & Reassign Leads', 'description': 'Assign or bulk-reassign leads to staff'},
            {'key': 'leads.import', 'label': 'Import Leads (CSV/Excel)', 'description': 'Bulk import leads from spreadsheets'},
            {'key': 'leads.export', 'label': 'Export Leads', 'description': 'Export lead lists to CSV/Excel'},
        ],
    },
    {
        'key': 'calls',
        'label': 'Calls, Recordings & Callbacks',
        'menu_key': 'call_history',
        'icon': 'call',
        'permissions': [
            {'key': 'calls.make', 'label': 'Make & Log Calls', 'description': 'Initiate outbound calls and log outcomes'},
            {'key': 'calls.view_own', 'label': 'View Own Call History', 'description': 'View personal call logs'},
            {'key': 'calls.view_all', 'label': 'View Team Call History', 'description': 'View all company call logs'},
            {'key': 'recordings.listen', 'label': 'Listen to Call Recordings', 'description': 'Play and download call audio recordings'},
            {'key': 'callbacks.manage', 'label': 'Manage Callbacks', 'description': 'Schedule, reschedule, and complete callbacks'},
        ],
    },
    {
        'key': 'tasks',
        'label': 'Tasks & Follow-Ups',
        'menu_key': 'tasks',
        'icon': 'task',
        'permissions': [
            {'key': 'tasks.view_own', 'label': 'View & Update Own Tasks', 'description': 'View and complete assigned tasks'},
            {'key': 'tasks.manage_team', 'label': 'Manage Team Tasks', 'description': 'Create, assign, and monitor tasks for any employee'},
        ],
    },
    {
        'key': 'quotations',
        'label': 'Quotations & Costing',
        'menu_key': 'quotations',
        'icon': 'request_quote',
        'permissions': [
            {'key': 'quotations.view', 'label': 'View Quotations', 'description': 'View company quotations'},
            {'key': 'quotations.create', 'label': 'Create Quotations', 'description': 'Create new client quotations'},
            {'key': 'quotations.edit', 'label': 'Edit Quotations', 'description': 'Modify existing quotations'},
            {'key': 'quotations.delete', 'label': 'Delete Quotations', 'description': 'Delete draft or cancelled quotations'},
            {'key': 'quotations.view_cost_cst', 'label': 'View Internal Cost (CST) & Margin', 'description': 'See internal cost prices and gross profit margins'},
            {'key': 'quotations.convert_to_invoice', 'label': 'Convert Quotation to Bill', 'description': '1-click convert approved quotation into an invoice'},
        ],
    },
    {
        'key': 'billing',
        'label': 'Billing, Invoices & Receipts',
        'menu_key': 'billing',
        'icon': 'receipt_long',
        'permissions': [
            {'key': 'invoices.view', 'label': 'View Invoices / Bills', 'description': 'View bills and payment status'},
            {'key': 'invoices.create', 'label': 'Create Invoices / Bills', 'description': 'Create direct bills and invoices'},
            {'key': 'invoices.edit', 'label': 'Edit Invoices / Bills', 'description': 'Edit unpaid or draft invoices'},
            {'key': 'invoices.delete', 'label': 'Delete Invoices / Bills', 'description': 'Delete invoices'},
            {'key': 'invoices.record_payment', 'label': 'Record Payments', 'description': 'Record partial or full payments against invoices'},
            {'key': 'receipts.view_print', 'label': 'View & Print Receipt Vouchers', 'description': 'View, print PDF, and share official receipt vouchers'},
            {'key': 'receipts.create', 'label': 'Issue Standalone Receipts', 'description': 'Create standalone receipt vouchers'},
            {'key': 'templates.manage', 'label': 'Manage Document Templates', 'description': 'Create, customize, and set default Quotation/Bill/Receipt templates'},
        ],
    },
    {
        'key': 'employees',
        'label': 'Employee Management & Organization',
        'menu_key': 'employees',
        'icon': 'badge',
        'permissions': [
            {'key': 'employees.view', 'label': 'View Employees', 'description': 'View staff directory and profiles'},
            {'key': 'employees.create', 'label': 'Add Employees', 'description': 'Onboard new employees'},
            {'key': 'employees.edit', 'label': 'Edit Employees', 'description': 'Update employee profiles, departments, and branches'},
            {'key': 'employees.deactivate', 'label': 'Activate / Deactivate Employees', 'description': 'Enable or suspend employee accounts'},
            {'key': 'roles.manage', 'label': 'Manage Roles & Permissions', 'description': 'Create and edit custom roles and assign permissions'},
            {'key': 'delegation.manage', 'label': 'Delegate Sections (Acting In-Charge)', 'description': 'Temporarily assign admin/manager sections to employees on leave'},
            {'key': 'branches.manage', 'label': 'Manage Branches', 'description': 'Create and configure company branches and geofences'},
            {'key': 'departments.manage', 'label': 'Manage Departments & Teams', 'description': 'Create and configure departments and teams'},
        ],
    },
    {
        'key': 'attendance_leave',
        'label': 'Attendance, Holidays & Leave',
        'menu_key': 'attendance',
        'icon': 'event_available',
        'permissions': [
            {'key': 'attendance.mark_own', 'label': 'Mark Own Attendance', 'description': 'Check-in and check-out daily attendance'},
            {'key': 'attendance.view_team', 'label': 'View Team Attendance', 'description': 'View attendance logs for all employees'},
            {'key': 'attendance.approve_corrections', 'label': 'Approve Attendance Regularization', 'description': 'Approve or reject missed-punch / correction requests'},
            {'key': 'leave.apply_own', 'label': 'Apply for Leave', 'description': 'Submit personal leave requests and view balances'},
            {'key': 'leave.approve', 'label': 'Approve / Reject Leave Requests', 'description': 'Approve or reject team leave applications'},
            {'key': 'leave.manage_types', 'label': 'Manage Leave Types & Holidays', 'description': 'Configure leave policies, quotas, and holiday calendar'},
        ],
    },
    {
        'key': 'payroll',
        'label': 'Payroll & Payslips',
        'menu_key': 'payroll',
        'icon': 'payments',
        'permissions': [
            {'key': 'payroll.view_own_payslip', 'label': 'View Own Payslips', 'description': 'View and download personal monthly payslips'},
            {'key': 'payroll.manage_rules', 'label': 'Manage Salary Structures & Rules', 'description': 'Configure employee salary breakdowns and payroll policies'},
            {'key': 'payroll.process_salary', 'label': 'Process & Finalize Payroll', 'description': 'Run monthly payroll, adjust bonuses/deductions, and lock/pay salaries'},
        ],
    },
    {
        'key': 'reports',
        'label': 'Reports & Analytics',
        'menu_key': 'reports',
        'icon': 'bar_chart',
        'permissions': [
            {'key': 'reports.sales_billing', 'label': 'Sales & Billing Reports', 'description': 'View quotation, invoice, and collection reports'},
            {'key': 'reports.calls_telecaller', 'label': 'Call & Telecaller Reports', 'description': 'View call performance and telecaller productivity reports'},
            {'key': 'reports.leads_conversion', 'label': 'Lead Pipeline Reports', 'description': 'View lead source and conversion funnel reports'},
            {'key': 'reports.hr_attendance', 'label': 'HR, Attendance & Payroll Reports', 'description': 'View attendance, leave, and payroll summary reports'},
            {'key': 'reports.export', 'label': 'Export Reports (PDF / CSV)', 'description': 'Download report exports'},
        ],
    },
]

# Flatten lookup helpers
ALL_PERMISSION_KEYS = {
    p['key']
    for group in PERMISSION_GROUPS
    for p in group['permissions']
}

MODULE_TO_MENU_KEY = {
    'leads': 'leads',
    'calls': 'call_history',
    'recordings': 'recordings',
    'callbacks': 'callbacks',
    'tasks': 'tasks',
    'quotations': 'quotations',
    'invoices': 'billing',
    'receipts': 'billing',
    'billing': 'billing',
    'templates': 'templates',
    'employees': 'employees',
    'staff': 'employees',
    'roles': 'employees',
    'delegation': 'delegation',
    'branches': 'branches',
    'departments': 'employees',
    'attendance': 'attendance',
    'leave': 'leave',
    'payroll': 'payroll',
    'reports': 'reports',
    'analytics': 'analytics',
}

# Safe backward-compatible default permissions for legacy MANAGER users with no CustomRole assigned
DEFAULT_MANAGER_PERMISSIONS = {
    'leads.view_own', 'leads.view_all', 'leads.create', 'leads.edit', 'leads.assign', 'leads.import', 'leads.export',
    'calls.make', 'calls.view_own', 'calls.view_all', 'recordings.listen', 'callbacks.manage',
    'tasks.view_own', 'tasks.manage_team',
    'quotations.view', 'quotations.create', 'quotations.edit', 'quotations.convert_to_invoice',
    'invoices.view', 'invoices.create', 'invoices.edit', 'invoices.record_payment',
    'receipts.view_print', 'receipts.create',
    'employees.view', 'attendance.mark_own', 'attendance.view_team', 'attendance.approve_corrections',
    'leave.apply_own', 'leave.approve',
    'payroll.view_own_payslip',
    'reports.sales_billing', 'reports.calls_telecaller', 'reports.leads_conversion', 'reports.hr_attendance', 'reports.export',
}

# Safe baseline permissions for standard Employees / Telecallers
DEFAULT_EMPLOYEE_PERMISSIONS = {
    'leads.view_own', 'leads.create', 'leads.edit',
    'calls.make', 'calls.view_own', 'callbacks.manage',
    'tasks.view_own',
    'attendance.mark_own',
    'leave.apply_own',
    'payroll.view_own_payslip',
}


def get_menu_key_for_permission(perm_key: str) -> str:
    module = perm_key.split('.')[0] if '.' in perm_key else perm_key
    return MODULE_TO_MENU_KEY.get(module, module)

