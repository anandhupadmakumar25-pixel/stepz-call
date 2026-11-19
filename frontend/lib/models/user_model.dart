class DelegationSummary {
  final String id;
  final String title;
  final String delegatorId;
  final String delegatorName;
  final List<String> sections;
  final List<String> permissions;
  final String startDate;
  final String endDate;

  DelegationSummary({
    required this.id,
    required this.title,
    required this.delegatorId,
    required this.delegatorName,
    this.sections = const [],
    this.permissions = const [],
    required this.startDate,
    required this.endDate,
  });

  factory DelegationSummary.fromJson(Map<String, dynamic> json) {
    return DelegationSummary(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Acting In-Charge',
      delegatorId: json['delegator_id']?.toString() ?? '',
      delegatorName: json['delegator_name']?.toString() ?? 'Admin',
      sections: (json['sections'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      permissions: (json['permissions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'delegator_id': delegatorId,
    'delegator_name': delegatorName,
    'sections': sections,
    'permissions': permissions,
    'start_date': startDate,
    'end_date': endDate,
  };
}

class UserModel {
  final String id;
  final String email;
  final String? username;
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
  final String companyCountryCode;
  final String companyCountryIso;
  final String companyCurrency;
  final String companyCurrencySymbol;
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
  final List<DelegationSummary> activeDelegations;

  UserModel({
    required this.id,
    required this.email,
    this.username,
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
    this.companyCountryCode = '+91',
    this.companyCountryIso = 'IN',
    this.companyCurrency = 'INR',
    this.companyCurrencySymbol = '₹',
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
    this.activeDelegations = const [],
  });

  static const Map<String, String> _v2MenuParentMap = {
    'leave': 'attendance',
    'payroll': 'employees',
    'delegation': 'employees',
    'quotations': 'leads',
    'billing': 'leads',
    'templates': 'leads',
    'reports': 'analytics',
  };

  bool get isRootMasterAdmin => isMasterAdmin || role == 'MASTER_ADMIN';
  bool get isSuperAdmin => role == 'SUPER_ADMIN' || role == 'MASTER_ADMIN';
  bool get isCompanyAdmin => role == 'COMPANY_ADMIN';
  bool get isManager => role == 'MANAGER';
  bool get isEmployee => role == 'EMPLOYEE';
  bool get canManageCompany => isSuperAdmin || role == 'COMPANY_ADMIN' || role == 'MANAGER';
  bool get hasActiveDelegations => activeDelegations.isNotEmpty;

  bool hasMenuPermission(String menuKey) {
    if (isSuperAdmin) return true;
    if (companyAllowedMenus.isEmpty) return true; // Default fallback if not initialized
    if (companyAllowedMenus.contains(menuKey)) return true;
    final hasV2Keys = companyAllowedMenus.any((k) => _v2MenuParentMap.containsKey(k));
    if (!hasV2Keys && _v2MenuParentMap.containsKey(menuKey)) {
      return companyAllowedMenus.contains(_v2MenuParentMap[menuKey]);
    }
    return false;
  }

  bool hasPermission(String permKey) {
    if (isSuperAdmin) return true;
    if (isCompanyAdmin || resolvedPermissions.contains('*')) return true;
    if (resolvedPermissions.contains(permKey)) return true;
    final domain = permKey.split('.').first;
    if (resolvedPermissions.contains('$domain.*')) return true;
    return false;
  }

  bool hasAnyPermission(List<String> keys) {
    return keys.any(hasPermission);
  }

  bool isDelegatedFor(String sectionOrPrefix) {
    if (activeDelegations.isEmpty) return false;
    for (final d in activeDelegations) {
      if (d.sections.contains(sectionOrPrefix)) return true;
      if (d.permissions.any((p) => p == '*' || p == sectionOrPrefix || p.startsWith('$sectionOrPrefix.'))) {
        return true;
      }
    }
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

    final rawDelegations = json['active_delegations'] as List<dynamic>?;
    final List<DelegationSummary> parsedDelegations = rawDelegations != null
        ? rawDelegations
            .whereType<Map<String, dynamic>>()
            .map((e) => DelegationSummary.fromJson(e))
            .toList()
        : [];

    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      username: json['username']?.toString(),
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
      companyCountryCode: json['company_country_code'] ?? '+91',
      companyCountryIso: json['company_country_iso'] ?? 'IN',
      companyCurrency: json['company_currency'] ?? 'INR',
      companyCurrencySymbol: json['company_currency_symbol'] ?? '₹',
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
      activeDelegations: parsedDelegations,
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
    'company_country_code': companyCountryCode,
    'company_country_iso': companyCountryIso,
    'company_currency': companyCurrency,
    'company_currency_symbol': companyCurrencySymbol,
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
    'active_delegations': activeDelegations.map((e) => e.toJson()).toList(),
  };
}
