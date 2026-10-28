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
  final bool isStaff;

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
    this.isStaff = false,
  });

  bool get isSuperAdmin => role == 'SUPER_ADMIN';
  bool get isCompanyAdmin => role == 'COMPANY_ADMIN' || role == 'SUPER_ADMIN';
  bool get isManager => role == 'MANAGER' || isCompanyAdmin;
  bool get isEmployee => role == 'EMPLOYEE';

  factory UserModel.fromJson(Map<String, dynamic> json) {
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
      isStaff: json['is_staff'] ?? false,
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
    'is_staff': isStaff,
  };
}
