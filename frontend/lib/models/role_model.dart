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

/// Standard catalog of CRM functionality permissions grouped by business domain
class PermissionCatalog {
  static const Map<String, List<Map<String, String>>> categorizedPermissions = {
    'Lead Management': [
      {'key': 'leads.view_assigned', 'label': 'View Assigned Leads', 'desc': 'Can view leads assigned to them'},
      {'key': 'leads.view_all', 'label': 'View All Company Leads', 'desc': 'Can view all company and branch leads'},
      {'key': 'leads.create', 'label': 'Create Leads', 'desc': 'Can manually create individual leads'},
      {'key': 'leads.edit', 'label': 'Edit Leads & Notes', 'desc': 'Can edit lead details, status & callbacks'},
      {'key': 'leads.delete', 'label': 'Delete Leads', 'desc': 'Can permanently delete leads'},
      {'key': 'leads.import', 'label': 'Bulk Import Leads', 'desc': 'Can upload Excel/CSV batches of leads'},
      {'key': 'leads.export', 'label': 'Export Leads', 'desc': 'Can download lead lists as CSV/Excel'},
      {'key': 'leads.assign', 'label': 'Assign / Distribute Leads', 'desc': 'Can distribute leads to employees'},
    ],
    'Calling Tasks & Execution': [
      {'key': 'tasks.view_assigned', 'label': 'View Assigned Tasks', 'desc': 'Can view assigned calling tasks'},
      {'key': 'tasks.view_all', 'label': 'View All Company Tasks', 'desc': 'Can view all calling batches and tasks'},
      {'key': 'tasks.execute', 'label': 'Dial Calls & Log Outcomes', 'desc': 'Can execute tasks, enter live notes and dial'},
      {'key': 'tasks.create', 'label': 'Create Calling Tasks', 'desc': 'Can batch and assign calling tasks to staff'},
      {'key': 'tasks.manage', 'label': 'Manage & Reassign Tasks', 'desc': 'Can edit, pause, or reassign tasks'},
    ],
    'Telephony & Recordings': [
      {'key': 'calls.view_history', 'label': 'View Call History', 'desc': 'Can inspect chronological call logs'},
      {'key': 'calls.view_recordings', 'label': 'Listen to Audio Recordings', 'desc': 'Can playback call audio recordings'},
      {'key': 'calls.download_recordings', 'label': 'Download Audio Files', 'desc': 'Can export recorded call files'},
    ],
    'Attendance & Field Operations': [
      {'key': 'attendance.punch', 'label': 'GPS Punch In / Punch Out', 'desc': 'Can punch in/out with geofence verification'},
      {'key': 'attendance.field_visit', 'label': 'Log Field Client Visits', 'desc': 'Can log client stops and GPS locations'},
      {'key': 'attendance.view_team_board', 'label': 'View Live Team Board', 'desc': 'Can view team attendance metrics & route maps'},
    ],
    'Branches & Organization': [
      {'key': 'branches.view', 'label': 'View Branches & Categories', 'desc': 'Can view organizational branches'},
      {'key': 'branches.manage', 'label': 'Manage Branches & Geofences', 'desc': 'Can create/edit branches and GPS fences'},
      {'key': 'departments.manage', 'label': 'Manage Departments', 'desc': 'Can configure departments and modes'},
      {'key': 'roles.manage', 'label': 'Manage Custom Roles & RBAC', 'desc': 'Can create and edit roles and permissions'},
      {'key': 'staff.view', 'label': 'View Staff Directory', 'desc': 'Can view staff profiles and phone numbers'},
      {'key': 'staff.manage', 'label': 'Onboard & Edit Employees', 'desc': 'Can create and edit staff accounts and roles'},
    ],
    'Analytics & Reporting': [
      {'key': 'analytics.view', 'label': 'View Dashboard Analytics', 'desc': 'Can view charts, KPI metrics and conversions'},
    ],
  };
}

