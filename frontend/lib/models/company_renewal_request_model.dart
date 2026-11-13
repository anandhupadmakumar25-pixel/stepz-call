class CompanyRenewalRequestModel {
  final String id;
  final String companyId;
  final String companyName;
  final String companySubdomain;
  final String? requestedById;
  final String requestedByName;
  final String requestedByEmail;
  final String? assignedSuperAdminId;
  final String assignedSuperAdminName;
  final String? planId;
  final String planName;
  final String billingCycle;
  final int requestedDays;
  final String? requestedDate;
  final String paymentReference;
  final String notes;
  final String status; // PENDING, APPROVED, REJECTED, CANCELLED
  final String? approvedById;
  final String? approvedByName;
  final String? approvedAt;
  final String adminNotes;
  final String? currentExpiry;
  final bool isCompanyExpired;
  final int? daysUntilExpiry;
  final String createdAt;

  CompanyRenewalRequestModel({
    required this.id,
    required this.companyId,
    required this.companyName,
    this.companySubdomain = '',
    this.requestedById,
    this.requestedByName = 'Tenant Admin',
    this.requestedByEmail = '',
    this.assignedSuperAdminId,
    this.assignedSuperAdminName = 'Unassigned',
    this.planId,
    this.planName = '',
    required this.billingCycle,
    this.requestedDays = 30,
    this.requestedDate,
    this.paymentReference = '',
    this.notes = '',
    this.status = 'PENDING',
    this.approvedById,
    this.approvedByName,
    this.approvedAt,
    this.adminNotes = '',
    this.currentExpiry,
    this.isCompanyExpired = false,
    this.daysUntilExpiry,
    required this.createdAt,
  });

  factory CompanyRenewalRequestModel.fromJson(Map<String, dynamic> json) {
    return CompanyRenewalRequestModel(
      id: json['id']?.toString() ?? '',
      companyId: json['company']?.toString() ?? '',
      companyName: json['company_name'] ?? 'Unnamed Tenant',
      companySubdomain: json['company_subdomain'] ?? '',
      requestedById: json['requested_by']?.toString(),
      requestedByName: json['requested_by_name'] ?? 'Tenant Admin',
      requestedByEmail: json['requested_by_email'] ?? '',
      assignedSuperAdminId: json['assigned_super_admin']?.toString(),
      assignedSuperAdminName: json['assigned_super_admin_name'] ?? 'Unassigned',
      planId: json['plan']?.toString(),
      planName: json['plan_name'] ?? '',
      billingCycle: json['billing_cycle'] ?? 'MONTHLY',
      requestedDays: json['requested_days'] ?? 30,
      requestedDate: json['requested_date'],
      paymentReference: json['payment_reference'] ?? '',
      notes: json['notes'] ?? '',
      status: json['status'] ?? 'PENDING',
      approvedById: json['approved_by']?.toString(),
      approvedByName: json['approved_by_name'],
      approvedAt: json['approved_at'],
      adminNotes: json['admin_notes'] ?? '',
      currentExpiry: json['current_expiry'],
      isCompanyExpired: json['is_company_expired'] ?? false,
      daysUntilExpiry: json['days_until_expiry'],
      createdAt: json['created_at'] ?? '',
    );
  }

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';

  String get billingCycleDisplay => cycleDisplay;

  String get cycleDisplay {
    switch (billingCycle) {
      case 'YEARLY':
        return 'Yearly (365 Days)';
      case 'MONTHLY':
        return 'Monthly (30 Days)';
      case 'DAYS':
        return '$requestedDays Days';
      case 'CUSTOM_DATE':
        return 'Custom Date Target';
      default:
        return billingCycle;
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

  String _monthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (m >= 1 && m <= 12) return months[m - 1];
    return '';
  }
}

