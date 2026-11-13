class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String fullName;
  final String role;
  final String? phone;
  final String? companyId;
  final String? companyName;
  final String? companyLogo;
  final String? companyPhone;
  final String? companyEmail;
  final String? companyAddress;
  final String? companyGstin;
  final String? companyWebsite;
  final String? branchId;
  final String? branchName;
  final bool isStaff;
  final bool isMasterAdmin;
  final List<String> companyAllowedMenus;
  final bool canManageBranches;
  final String companyPlanName;
  final String? companyPlanExpiresAt;
  final int? companyDaysUntilExpiry;
  final bool companyIsPlanExpired;
  final List<String> customRoleIds;
  final List<String> customRoleNames;
  final List<String> resolvedPermissions;

  UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.role,
    this.phone,
    this.companyId,
    this.companyName,
    this.companyLogo,
    this.companyPhone,
    this.companyEmail,
    this.companyAddress,
    this.companyGstin,
    this.companyWebsite,
    this.branchId,
    this.branchName,
    this.isStaff = false,
    this.isMasterAdmin = false,
    this.companyAllowedMenus = const [],
    this.canManageBranches = true,
    this.companyPlanName = 'Default',
    this.companyPlanExpiresAt,
    this.companyDaysUntilExpiry,
    this.companyIsPlanExpired = false,
    this.customRoleIds = const [],
    this.customRoleNames = const [],
    this.resolvedPermissions = const [],
  });

  bool get isRootMasterAdmin => isMasterAdmin || role == 'MASTER_ADMIN';
  bool get isSuperAdmin => role == 'SUPER_ADMIN' || role == 'MASTER_ADMIN';
  bool get isCompanyAdmin => role == 'COMPANY_ADMIN';
  bool get isManager => role == 'MANAGER';
  bool get isEmployee => role == 'EMPLOYEE';
  bool get canManageCompany => isSuperAdmin || role == 'COMPANY_ADMIN' || role == 'MANAGER';

  bool hasMenuPermission(String menuKey) {
    if (isSuperAdmin) return true;
    if (companyAllowedMenus.isEmpty) return true; // Default fallback if not initialized
    return companyAllowedMenus.contains(menuKey);
  }

  bool hasPermission(String permKey) {
    if (isSuperAdmin || isCompanyAdmin) return true;
    if (resolvedPermissions.contains('*') || resolvedPermissions.contains(permKey)) return true;
    final domain = permKey.split('.').first;
    if (resolvedPermissions.contains('$domain.*')) return true;
    // Fallback if legacy manager
    if (isManager) return true;
    return false;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawMenus = json['company_allowed_menus'] as List<dynamic>?;
    final List<String> parsedMenus = rawMenus != null
        ? rawMenus.map((e) => e.toString()).toList()
        : [
            'branches',
            'employees',
            'attendance',
            'leads',
            'tasks',
            'recordings',
            'callbacks',
            'call_history',
            'analytics',
          ];

    final rawRoleIds = json['custom_role_ids'] as List<dynamic>?;
    final List<String> parsedRoleIds = rawRoleIds != null
        ? rawRoleIds.map((e) => e.toString()).toList()
        : [];

    final rawRoleNames = json['custom_role_names'] as List<dynamic>?;
    final List<String> parsedRoleNames = rawRoleNames != null
        ? rawRoleNames.map((e) => e.toString()).toList()
        : [];

    final rawPerms = json['resolved_permissions'] as List<dynamic>?;
    final List<String> parsedPerms = rawPerms != null
        ? rawPerms.map((e) => e.toString()).toList()
        : [];

    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      fullName: json['full_name'] ?? '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim(),
      role: json['role'] ?? 'EMPLOYEE',
      phone: json['phone'],
      companyId: json['company_id']?.toString() ?? json['company']?.toString(),
      companyName: json['company_name'],
      companyLogo: json['company_logo'],
      companyPhone: json['company_phone'],
      companyEmail: json['company_email'],
      companyAddress: json['company_address'],
      companyGstin: json['company_gstin'],
      companyWebsite: json['company_website'],
      branchId: json['branch_id']?.toString() ?? json['branch']?.toString(),
      branchName: json['branch_name'],
      isStaff: json['is_staff'] ?? false,
      isMasterAdmin: json['is_master_admin'] ?? (json['role'] == 'MASTER_ADMIN'),
      companyAllowedMenus: parsedMenus,
      canManageBranches: json['can_manage_branches'] ?? parsedMenus.contains('branches'),
      companyPlanName: json['company_plan_name'] ?? 'Default',
      companyPlanExpiresAt: json['company_plan_expires_at']?.toString(),
      companyDaysUntilExpiry: json['company_days_until_expiry'] is int
          ? json['company_days_until_expiry']
          : int.tryParse(json['company_days_until_expiry']?.toString() ?? ''),
      companyIsPlanExpired: json['company_is_plan_expired'] == true,
      customRoleIds: parsedRoleIds,
      customRoleNames: parsedRoleNames,
      resolvedPermissions: parsedPerms,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'first_name': firstName,
    'last_name': lastName,
    'full_name': fullName,
    'role': role,
    'phone': phone,
    'company_id': companyId,
    'company_name': companyName,
    'company_logo': companyLogo,
    'company_phone': companyPhone,
    'company_email': companyEmail,
    'company_address': companyAddress,
    'company_gstin': companyGstin,
    'company_website': companyWebsite,
    'branch_id': branchId,
    'branch_name': branchName,
    'is_staff': isStaff,
    'is_master_admin': isMasterAdmin,
    'company_allowed_menus': companyAllowedMenus,
    'can_manage_branches': canManageBranches,
    'company_plan_name': companyPlanName,
    'custom_role_ids': customRoleIds,
    'custom_role_names': customRoleNames,
    'resolved_permissions': resolvedPermissions,
  };
}
