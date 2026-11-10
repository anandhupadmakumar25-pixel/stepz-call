class DepartmentModel {
  final String id;
  final String name;
  final String code;
  final String description;
  final String attendanceMode;
  final List<String> allowedBranches;
  final List<Map<String, dynamic>> allowedBranchDetails;
  final int memberCount;
  final bool isActive;
  final String managerName;

  DepartmentModel({
    required this.id,
    required this.name,
    this.code = '',
    this.description = '',
    this.attendanceMode = 'GEOFENCE',
    this.allowedBranches = const [],
    this.allowedBranchDetails = const [],
    this.memberCount = 0,
    this.isActive = true,
    this.managerName = '',
  });

  bool get isGeofenceMode => attendanceMode == 'GEOFENCE';
  bool get isFieldStaffMode => attendanceMode == 'FIELD_STAFF';

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    final rawBranches = json['allowed_branches'] as List<dynamic>?;
    final List<String> branchIds = rawBranches != null
        ? rawBranches.map((e) => e.toString()).toList()
        : [];

    final rawDetails = json['allowed_branch_details'] as List<dynamic>?;
    final List<Map<String, dynamic>> details = rawDetails != null
        ? rawDetails.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : [];

    return DepartmentModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      description: json['description'] ?? '',
      attendanceMode: json['attendance_mode'] ?? 'GEOFENCE',
      allowedBranches: branchIds,
      allowedBranchDetails: details,
      memberCount: json['member_count'] ?? 0,
      isActive: json['is_active'] ?? true,
      managerName: json['manager_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'description': description,
        'attendance_mode': attendanceMode,
        'allowed_branches': allowedBranches,
        'is_active': isActive,
      };
}
