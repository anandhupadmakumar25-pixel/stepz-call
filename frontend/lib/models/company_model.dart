class CompanyModel {
  final String id;
  final String name;
  final String? subdomain;
  final String contactEmail;
  final String contactPhone;
  final String status;
  final String defaultCountryCode;
  final int userCount;
  final int leadCount;
  final String createdAt;

  CompanyModel({
    required this.id,
    required this.name,
    this.subdomain,
    required this.contactEmail,
    required this.contactPhone,
    required this.status,
    required this.defaultCountryCode,
    this.userCount = 0,
    this.leadCount = 0,
    required this.createdAt,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      subdomain: json['subdomain'],
      contactEmail: json['contact_email'] ?? '',
      contactPhone: json['contact_phone'] ?? '',
      status: json['status'] ?? 'ACTIVE',
      defaultCountryCode: json['default_country_code'] ?? '+91',
      userCount: json['user_count'] ?? 0,
      leadCount: json['lead_count'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }
}
