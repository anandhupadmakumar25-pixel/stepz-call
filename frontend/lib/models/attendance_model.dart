class FieldVisitModel {
  final String id;
  final String userName;
  final String placeName;
  final double? latitude;
  final double? longitude;
  final String address;
  final DateTime? visitedAt;
  final String remarks;

  FieldVisitModel({
    required this.id,
    this.userName = '',
    required this.placeName,
    this.latitude,
    this.longitude,
    this.address = '',
    this.visitedAt,
    this.remarks = '',
  });

  factory FieldVisitModel.fromJson(Map<String, dynamic> json) {
    double? parseCoord(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString());
    }

    return FieldVisitModel(
      id: json['id']?.toString() ?? '',
      userName: json['user_name'] ?? '',
      placeName: json['place_name'] ?? '',
      latitude: parseCoord(json['latitude']),
      longitude: parseCoord(json['longitude']),
      address: json['address'] ?? '',
      visitedAt: parseDate(json['visited_at']),
      remarks: json['remarks'] ?? '',
    );
  }
}

class AttendanceModel {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String userPhone;
  final String departmentName;
  final String matchedBranchName;
  final String date;
  final String trackingMode;
  final DateTime? checkInTime;
  final double? checkInLat;
  final double? checkInLng;
  final String checkInAddress;
  final double? checkInDistanceMeters;
  final bool checkInInGeofence;
  final DateTime? checkOutTime;
  final double? checkOutLat;
  final double? checkOutLng;
  final String checkOutAddress;
  final double? checkOutDistanceMeters;
  final double workingHours;
  final String status;
  final String notes;
  final List<FieldVisitModel> fieldVisits;

  AttendanceModel({
    required this.id,
    this.userId = '',
    this.userName = '',
    this.userEmail = '',
    this.userPhone = '',
    this.departmentName = '',
    this.matchedBranchName = '',
    required this.date,
    this.trackingMode = 'GEOFENCE',
    this.checkInTime,
    this.checkInLat,
    this.checkInLng,
    this.checkInAddress = '',
    this.checkInDistanceMeters,
    this.checkInInGeofence = false,
    this.checkOutTime,
    this.checkOutLat,
    this.checkOutLng,
    this.checkOutAddress = '',
    this.checkOutDistanceMeters,
    this.workingHours = 0.0,
    this.status = 'PRESENT',
    this.notes = '',
    this.fieldVisits = const [],
  });

  bool get isPresent => status == 'PRESENT';
  bool get isLate => status == 'LATE';
  bool get isOutOfFence => status == 'OUT_OF_FENCE';
  bool get isFieldStaff => trackingMode == 'FIELD_STAFF';
  bool get isFieldStaffMode => trackingMode == 'FIELD_STAFF';
  bool get isGeofenceMode => trackingMode == 'GEOFENCE';

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    double? parseCoord(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString());
    }

    final rawVisits = json['field_visits'] as List<dynamic>?;
    final List<FieldVisitModel> visits = rawVisits != null
        ? rawVisits.map((e) => FieldVisitModel.fromJson(e as Map<String, dynamic>)).toList()
        : [];

    return AttendanceModel(
      id: json['id']?.toString() ?? '',
      userId: json['user']?.toString() ?? '',
      userName: json['user_name'] ?? '',
      userEmail: json['user_email'] ?? '',
      userPhone: json['user_phone'] ?? '',
      departmentName: json['department_name'] ?? '',
      matchedBranchName: json['matched_branch_name'] ?? '',
      date: json['date'] ?? '',
      trackingMode: json['tracking_mode'] ?? 'GEOFENCE',
      checkInTime: parseDate(json['check_in_time']),
      checkInLat: parseCoord(json['check_in_lat']),
      checkInLng: parseCoord(json['check_in_lng']),
      checkInAddress: json['check_in_address'] ?? '',
      checkInDistanceMeters: parseCoord(json['check_in_distance_meters']),
      checkInInGeofence: json['check_in_in_geofence'] ?? false,
      checkOutTime: parseDate(json['check_out_time']),
      checkOutLat: parseCoord(json['check_out_lat']),
      checkOutLng: parseCoord(json['check_out_lng']),
      checkOutAddress: json['check_out_address'] ?? '',
      checkOutDistanceMeters: parseCoord(json['check_out_distance_meters']),
      workingHours: (json['working_hours'] is num)
          ? (json['working_hours'] as num).toDouble()
          : double.tryParse(json['working_hours']?.toString() ?? '0.0') ?? 0.0,
      status: json['status'] ?? 'PRESENT',
      notes: json['notes'] ?? '',
      fieldVisits: visits,
    );
  }
}
