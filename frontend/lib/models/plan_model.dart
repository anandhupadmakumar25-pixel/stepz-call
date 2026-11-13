class PlanModel {
  final String id;
  final String name;
  final String code;
  final String currency;
  final String currencySymbol;
  final double priceMonthly;
  final double priceYearly;
  final int maxUsers;
  final int maxLeads;
  final List<String> allowedMenus;
  final String description;
  final bool isActive;
  final int companyCount;

  PlanModel({
    required this.id,
    required this.name,
    required this.code,
    this.currency = 'INR',
    this.currencySymbol = '₹',
    required this.priceMonthly,
    required this.priceYearly,
    required this.maxUsers,
    required this.maxLeads,
    required this.allowedMenus,
    this.description = '',
    this.isActive = true,
    this.companyCount = 0,
  });

  static String getSymbolForCurrency(String curr) {
    switch (curr.toUpperCase()) {
      case 'INR':
        return '₹';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'AED':
        return 'د.إ';
      default:
        return '₹';
    }
  }

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    final currency = json['currency']?.toString() ?? 'INR';
    final currencySymbol = json['currency_symbol']?.toString().isNotEmpty == true
        ? json['currency_symbol'].toString()
        : getSymbolForCurrency(currency);

    return PlanModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      currency: currency,
      currencySymbol: currencySymbol,
      priceMonthly: (json['price_monthly'] is num)
          ? (json['price_monthly'] as num).toDouble()
          : double.tryParse(json['price_monthly']?.toString() ?? '0.0') ?? 0.0,
      priceYearly: (json['price_yearly'] is num)
          ? (json['price_yearly'] as num).toDouble()
          : double.tryParse(json['price_yearly']?.toString() ?? '0.0') ?? 0.0,
      maxUsers: json['max_users'] ?? 5,
      maxLeads: json['max_leads'] ?? 5000,
      allowedMenus: (json['allowed_menus'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      description: json['description'] ?? '',
      isActive: json['is_active'] ?? true,
      companyCount: json['company_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'currency': currency,
        'price_monthly': priceMonthly,
        'price_yearly': priceYearly,
        'max_users': maxUsers,
        'max_leads': maxLeads,
        'allowed_menus': allowedMenus,
        'description': description,
        'is_active': isActive,
      };
}
