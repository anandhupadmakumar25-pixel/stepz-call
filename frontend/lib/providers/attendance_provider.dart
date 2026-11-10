import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/attendance_model.dart';

class AttendanceProvider extends ChangeNotifier {
  AttendanceModel? _todayAttendance;
  bool _isCheckedIn = false;
  bool _isCheckedOut = false;
  List<FieldVisitModel> _todayVisits = [];

  List<AttendanceModel> _adminRecords = [];
  Map<String, dynamic> _adminSummary = {
    'total_employees': 0,
    'present_count': 0,
    'late_count': 0,
    'out_of_fence_count': 0,
    'absent_count': 0,
    'checked_in_count': 0,
  };

  bool _isLoading = false;
  String? _errorMessage;

  AttendanceModel? get todayAttendance => _todayAttendance;
  bool get isCheckedIn => _isCheckedIn;
  bool get isCheckedOut => _isCheckedOut;
  List<FieldVisitModel> get todayVisits => _todayVisits;

  List<AttendanceModel> get adminRecords => _adminRecords;
  Map<String, dynamic> get adminSummary => _adminSummary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchTodayStatus() async {
    try {
      final res = await ApiClient.get('/accounts/attendance/today/');
      _isCheckedIn = res['checked_in'] == true;
      _isCheckedOut = res['checked_out'] == true;
      if (res['attendance'] != null) {
        _todayAttendance = AttendanceModel.fromJson(res['attendance'] as Map<String, dynamic>);
        _todayVisits = _todayAttendance!.fieldVisits;
      } else {
        _todayAttendance = null;
        _todayVisits = [];
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> checkIn({
    double? latitude,
    double? longitude,
    String address = '',
    String notes = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/accounts/attendance/check-in/', {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'notes': notes,
      });
      _todayAttendance = AttendanceModel.fromJson(res as Map<String, dynamic>);
      _isCheckedIn = true;
      _isCheckedOut = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> checkOut({
    double? latitude,
    double? longitude,
    String address = '',
    String notes = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/accounts/attendance/check-out/', {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'notes': notes,
      });
      _todayAttendance = AttendanceModel.fromJson(res as Map<String, dynamic>);
      _isCheckedOut = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> recordFieldVisit({
    required String placeName,
    double? latitude,
    double? longitude,
    String address = '',
    String remarks = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/accounts/attendance/field-visits/', {
        'place_name': placeName.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'address': address.trim(),
        'remarks': remarks.trim(),
      });
      final visit = FieldVisitModel.fromJson(res as Map<String, dynamic>);
      _todayVisits.add(visit);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchAdminRecords({
    String? date,
    String? branchId,
    String? departmentId,
    String? status,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final params = <String>[];
      if (date != null && date.isNotEmpty) params.add('date=$date');
      if (branchId != null && branchId.isNotEmpty && branchId != 'ALL') params.add('branch_id=$branchId');
      if (departmentId != null && departmentId.isNotEmpty && departmentId != 'ALL') params.add('department_id=$departmentId');
      if (status != null && status.isNotEmpty && status != 'ALL') params.add('status=$status');

      final query = params.isNotEmpty ? '?${params.join('&')}' : '';
      final res = await ApiClient.get('/accounts/attendance/records/$query');

      if (res['summary'] is Map) {
        _adminSummary = Map<String, dynamic>.from(res['summary'] as Map);
      }
      if (res['records'] is List) {
        _adminRecords = (res['records'] as List)
            .map((r) => AttendanceModel.fromJson(r as Map<String, dynamic>))
            .toList();
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
