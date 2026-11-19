class RoleModel {
  final String id;
  final String name;
  final String code;
  final String description;
  final List<String> permissions;
  final bool isSystemDefault;
  final bool isActive;
  final int userCount;
  final DateTime? createdAt;

  RoleModel({
    required this.id,
    required this.name,
    this.code = '',
    this.description = '',
    this.permissions = const [],
    this.isSystemDefault = false,
    this.isActive = true,
    this.userCount = 0,
    this.createdAt,
  });

  bool hasPermission(String permKey) => permissions.contains(permKey);

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    final rawPerms = json['permissions'] as List<dynamic>?;
    final List<String> parsedPerms = rawPerms != null
        ? rawPerms.map((e) => e.toString()).toList()
        : [];

    DateTime? parsedCreated;
    if (json['created_at'] != null) {
      parsedCreated = DateTime.tryParse(json['created_at'].toString());
    }

    return RoleModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      description: json['description'] ?? '',
      permissions: parsedPerms,
      isSystemDefault: json['is_system_default'] ?? false,
      isActive: json['is_active'] ?? true,
      userCount: json['user_count'] ?? 0,
      createdAt: parsedCreated,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'description': description,
        'permissions': permissions,
        'is_active': isActive,
      };
}

/// Standard catalog of CRM, Billing, HR & Payroll functionality permissions grouped by business domain
class PermissionCatalog {
  static const Map<String, List<Map<String, String>>> categorizedPermissions = {
    'Lead Management': [
      {'key': 'leads.view_own', 'label': 'View Assigned Leads', 'desc': 'Can view leads assigned to them'},
      {'key': 'leads.view_all', 'label': 'View All Company Leads', 'desc': 'Can view all company and branch leads'},
      {'key': 'leads.create', 'label': 'Create Leads', 'desc': 'Can manually create individual leads'},
      {'key': 'leads.edit', 'label': 'Edit Leads & Notes', 'desc': 'Can edit lead details, status & callbacks'},
      {'key': 'leads.delete', 'label': 'Delete Leads', 'desc': 'Can permanently delete leads'},
      {'key': 'leads.import', 'label': 'Bulk Import Leads', 'desc': 'Can upload Excel/CSV batches of leads'},
      {'key': 'leads.export', 'label': 'Export Leads', 'desc': 'Can download lead lists as CSV/Excel'},
      {'key': 'leads.assign', 'label': 'Assign / Distribute Leads', 'desc': 'Can distribute leads to employees'},
    ],
    'Calling Tasks & Execution': [
      {'key': 'tasks.view_own', 'label': 'View & Update Own Tasks', 'desc': 'Can view and complete assigned calling tasks'},
      {'key': 'tasks.manage_team', 'label': 'Manage Team Tasks', 'desc': 'Can batch, assign, pause, or reassign tasks'},
    ],
    'Telephony & Recordings': [
      {'key': 'calls.make', 'label': 'Make & Log Calls', 'desc': 'Can initiate outbound calls and log outcomes'},
      {'key': 'calls.view_own', 'label': 'View Own Call History', 'desc': 'Can inspect personal call logs'},
      {'key': 'calls.view_all', 'label': 'View Team Call History', 'desc': 'Can inspect all company call logs'},
      {'key': 'recordings.listen', 'label': 'Listen to Call Recordings', 'desc': 'Can playback and download call audio recordings'},
      {'key': 'callbacks.manage', 'label': 'Manage Callbacks', 'desc': 'Can schedule, reschedule, and complete callbacks'},
    ],
    'Quotations & Costing': [
      {'key': 'quotations.view', 'label': 'View Quotations', 'desc': 'Can view company quotations'},
      {'key': 'quotations.create', 'label': 'Create Quotations', 'desc': 'Can create new client quotations'},
      {'key': 'quotations.edit', 'label': 'Edit Quotations', 'desc': 'Can modify existing quotations'},
      {'key': 'quotations.delete', 'label': 'Delete Quotations', 'desc': 'Can delete draft or cancelled quotations'},
      {'key': 'quotations.view_cost_cst', 'label': 'View Internal Cost (CST) & Margin', 'desc': 'Can see internal cost prices and gross profit margins'},
      {'key': 'quotations.convert_to_invoice', 'label': 'Convert Quotation to Bill', 'desc': 'Can 1-click convert approved quotation to invoice'},
    ],
    'Billing, Invoices & Receipts': [
      {'key': 'invoices.view', 'label': 'View Invoices / Bills', 'desc': 'Can view bills and payment status'},
      {'key': 'invoices.create', 'label': 'Create Invoices / Bills', 'desc': 'Can create direct bills and invoices'},
      {'key': 'invoices.edit', 'label': 'Edit Invoices / Bills', 'desc': 'Can edit unpaid or draft invoices'},
      {'key': 'invoices.delete', 'label': 'Delete Invoices / Bills', 'desc': 'Can delete invoices'},
      {'key': 'invoices.record_payment', 'label': 'Record Payments', 'desc': 'Can record partial or full payments'},
      {'key': 'receipts.view_print', 'label': 'View & Print Receipt Vouchers', 'desc': 'Can view, print PDF, and share receipt vouchers'},
      {'key': 'receipts.create', 'label': 'Issue Standalone Receipts', 'desc': 'Can create standalone receipt vouchers'},
      {'key': 'templates.manage', 'label': 'Manage Document Templates', 'desc': 'Can create and customize Quotation/Bill/Receipt templates'},
    ],
    'Employee Management & Organization': [
      {'key': 'employees.view', 'label': 'View Employees', 'desc': 'Can view staff directory and profiles'},
      {'key': 'employees.create', 'label': 'Add Employees', 'desc': 'Can onboard new employees'},
      {'key': 'employees.edit', 'label': 'Edit Employees', 'desc': 'Can update employee profiles, departments, and branches'},
      {'key': 'employees.deactivate', 'label': 'Activate / Deactivate Employees', 'desc': 'Can enable or suspend employee accounts'},
      {'key': 'roles.manage', 'label': 'Manage Roles & Permissions', 'desc': 'Can create and edit custom roles and permissions'},
      {'key': 'delegation.manage', 'label': 'Delegate Sections (Acting In-Charge)', 'desc': 'Can temporarily assign sections to employees on leave'},
      {'key': 'branches.manage', 'label': 'Manage Branches & Geofences', 'desc': 'Can create/edit branches and GPS fences'},
      {'key': 'departments.manage', 'label': 'Manage Departments & Teams', 'desc': 'Can configure departments and teams'},
    ],
    'Attendance, Holidays & Leave': [
      {'key': 'attendance.mark_own', 'label': 'Mark Own Attendance', 'desc': 'Can punch in/out with GPS verification'},
      {'key': 'attendance.view_team', 'label': 'View Team Attendance', 'desc': 'Can view team attendance metrics & route maps'},
      {'key': 'attendance.approve_corrections', 'label': 'Approve Attendance Regularization', 'desc': 'Can approve or reject missed-punch requests'},
      {'key': 'leave.apply_own', 'label': 'Apply for Leave', 'desc': 'Can submit personal leave requests and view balances'},
      {'key': 'leave.approve', 'label': 'Approve / Reject Leave Requests', 'desc': 'Can approve or reject team leave applications'},
      {'key': 'leave.manage_types', 'label': 'Manage Leave Types & Holidays', 'desc': 'Can configure leave quotas and holiday calendar'},
    ],
    'Analytics & Reporting': [
      {'key': 'reports.sales_billing', 'label': 'Sales & Billing Reports', 'desc': 'Can view quotation, invoice, and collection reports'},
      {'key': 'reports.calls_telecaller', 'label': 'Call & Telecaller Reports', 'desc': 'Can view call performance and telecaller productivity'},
      {'key': 'reports.leads_conversion', 'label': 'Lead Pipeline Reports', 'desc': 'Can view lead source and conversion funnel reports'},
      {'key': 'reports.hr_attendance', 'label': 'HR & Attendance Reports', 'desc': 'Can view attendance and leave reports'},
      {'key': 'reports.export', 'label': 'Export Reports (PDF / CSV)', 'desc': 'Can download report exports'},
    ],
  };
}

