class CompanySubscriptionHistoryModel {
  final String id;
  final String companyId;
  final String companyName;
  final String planName;
  final String billingCycle;
  final String billingCycleDisplay;
  final int extensionDays;
  final String? previousExpiry;
  final String newExpiry;
  final double amountPaid;
  final String currency;
  final String approvedByName;
  final String? renewalRequestId;
  final String notes;
  final String createdAt;

  CompanySubscriptionHistoryModel({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.planName,
    required this.billingCycle,
    required this.billingCycleDisplay,
    required this.extensionDays,
    this.previousExpiry,
    required this.newExpiry,
    this.amountPaid = 0.0,
    this.currency = 'INR',
    this.approvedByName = 'Super Admin',
    this.renewalRequestId,
    this.notes = '',
    required this.createdAt,
  });

  factory CompanySubscriptionHistoryModel.fromJson(Map<String, dynamic> json) {
    return CompanySubscriptionHistoryModel(
      id: json['id']?.toString() ?? '',
      companyId: json['company']?.toString() ?? '',
      companyName: json['company_name'] ?? '',
      planName: json['plan_name'] ?? 'Standard',
      billingCycle: json['billing_cycle'] ?? 'MONTHLY',
      billingCycleDisplay: json['billing_cycle_display'] ?? (json['billing_cycle'] ?? 'Monthly'),
      extensionDays: json['extension_days'] ?? 0,
      previousExpiry: json['previous_expiry'],
      newExpiry: json['new_expiry'] ?? '',
      amountPaid: double.tryParse(json['amount_paid']?.toString() ?? '0') ?? 0.0,
      currency: json['currency'] ?? 'INR',
      approvedByName: json['approved_by_name'] ?? 'Super Admin',
      renewalRequestId: json['renewal_request']?.toString(),
      notes: json['notes'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  String get formattedNewExpiry {
    try {
      final dt = DateTime.parse(newExpiry);
      return '${dt.day.toString().padLeft(2, '0')} ${_monthName(dt.month)} ${dt.year}';
    } catch (_) {
      return newExpiry;
    }
  }

  String get formattedCreatedAt {
    try {
      final dt = DateTime.parse(createdAt);
      return '${dt.day.toString().padLeft(2, '0')} ${_monthName(dt.month)} ${dt.year}';
    } catch (_) {
      return createdAt;
    }
  }

  static String _monthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (m >= 1 && m <= 12) return months[m - 1];
    return '';
  }
}

class SubscriptionHistoryMetrics {
  final int totalRenewals;
  final int yearlyCount;
  final int monthlyCount;
  final int daysCount;
  final int customDateCount;
  final double totalRevenue;

  SubscriptionHistoryMetrics({
    this.totalRenewals = 0,
    this.yearlyCount = 0,
    this.monthlyCount = 0,
    this.daysCount = 0,
    this.customDateCount = 0,
    this.totalRevenue = 0.0,
  });

  factory SubscriptionHistoryMetrics.fromJson(Map<String, dynamic> json) {
    return SubscriptionHistoryMetrics(
      totalRenewals: json['total_renewals'] ?? 0,
      yearlyCount: json['yearly_count'] ?? 0,
      monthlyCount: json['monthly_count'] ?? 0,
      daysCount: json['days_count'] ?? 0,
      customDateCount: json['custom_date_count'] ?? 0,
      totalRevenue: double.tryParse(json['total_revenue']?.toString() ?? '0') ?? 0.0,
    );
  }
}

