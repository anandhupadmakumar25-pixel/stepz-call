import 'plan_model.dart';

class CompanyModel {
  final String id;
  final String name;
  final String? subdomain;
  final String contactEmail;
  final String contactPhone;
  final String status;
  final String defaultCountryCode;
  final String logo;
  final String address;
  final String gstin;
  final String website;
  final String? planId;
  final String planName;
  final String planCode;
  final String planCurrency;
  final String planCurrencySymbol;
  final double planPriceMonthly;
  final double planPriceYearly;
  final int planMaxUsers;
  final int planMaxLeads;
  final List<String> allowedMenus;
  final bool canManageBranches;
  final int userCount;
  final int leadCount;
  final int branchCount;
  final int taskCount;
  final String adminName;
  final String? explicitAdminEmail;
  final String createdAt;

  CompanyModel({
    required this.id,
    required this.name,
    this.subdomain,
    required this.contactEmail,
    required this.contactPhone,
    this.status = 'ACTIVE',
    this.defaultCountryCode = '+91',
    this.logo = '',
    this.address = '',
    this.gstin = '',
    this.website = '',
    this.planId,
    this.planName = 'Starter Lite',
    this.planCode = 'starter',
    this.planCurrency = 'INR',
    this.planCurrencySymbol = '₹',
    this.planPriceMonthly = 0.0,
    this.planPriceYearly = 0.0,
    this.planMaxUsers = 5,
    this.planMaxLeads = 5000,
    this.allowedMenus = const [],
    this.canManageBranches = true,
    this.userCount = 0,
    this.leadCount = 0,
    this.branchCount = 0,
    this.taskCount = 0,
    this.adminName = '',
    this.explicitAdminEmail,
    this.createdAt = '',
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isSuspended => status.toUpperCase() == 'SUSPENDED';
  int get employeeCount => userCount;
  String get adminEmail => explicitAdminEmail != null && explicitAdminEmail!.isNotEmpty ? explicitAdminEmail! : contactEmail;

  bool hasMenuPermission(String menuKey) => allowedMenus.contains(menuKey);

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    final rawMenus = (json['resolved_allowed_menus'] ?? json['allowed_menus']) as List<dynamic>?;
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

    double parsePrice(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    return CompanyModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      subdomain: json['subdomain'],
      contactEmail: json['contact_email'] ?? '',
      contactPhone: json['contact_phone'] ?? '',
      status: json['status'] ?? 'ACTIVE',
      defaultCountryCode: json['default_country_code'] ?? '+91',
      logo: json['logo'] ?? '',
      address: json['address'] ?? '',
      gstin: json['gstin'] ?? '',
      website: json['website'] ?? '',
      planId: json['plan']?.toString(),
      planName: json['plan_name'] ?? 'Starter Lite',
      planCode: json['plan_code'] ?? 'starter',
      planCurrency: json['plan_currency']?.toString() ?? 'INR',
      planCurrencySymbol: json['plan_currency_symbol']?.toString().isNotEmpty == true
          ? json['plan_currency_symbol'].toString()
          : (json['plan_currency'] != null ? PlanModel.getSymbolForCurrency(json['plan_currency'].toString()) : '₹'),
      planPriceMonthly: parsePrice(json['plan_price_monthly']),
      planPriceYearly: parsePrice(json['plan_price_yearly']),
      planMaxUsers: json['plan_max_users'] is int ? json['plan_max_users'] : int.tryParse(json['plan_max_users']?.toString() ?? '5') ?? 5,
      planMaxLeads: json['plan_max_leads'] is int ? json['plan_max_leads'] : int.tryParse(json['plan_max_leads']?.toString() ?? '5000') ?? 5000,
      allowedMenus: parsedMenus,
      canManageBranches: json['can_manage_branches'] ?? parsedMenus.contains('branches'),
      userCount: json['user_count'] ?? 0,
      leadCount: json['lead_count'] ?? 0,
      branchCount: json['branch_count'] ?? 0,
      taskCount: json['task_count'] ?? 0,
      adminName: json['admin_name'] ?? '',
      explicitAdminEmail: json['admin_email'],
      createdAt: json['created_at'] ?? '',
    );
  }
}
