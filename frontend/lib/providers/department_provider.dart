import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/department_model.dart';

class DepartmentProvider extends ChangeNotifier {
  List<DepartmentModel> _departments = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<DepartmentModel> get departments => _departments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchDepartments() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.get('/accounts/departments/');
      if (res is List) {
        _departments = res.map((d) => DepartmentModel.fromJson(d as Map<String, dynamic>)).toList();
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

  Future<DepartmentModel?> createDepartment({
    required String name,
    String code = '',
    String description = '',
    String attendanceMode = 'GEOFENCE',
    List<String> allowedBranches = const [],
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/accounts/departments/', {
        'name': name.trim(),
        'code': code.trim(),
        'description': description.trim(),
        'attendance_mode': attendanceMode,
        'allowed_branches': allowedBranches,
      });
      final dept = DepartmentModel.fromJson(res);
      _departments.insert(0, dept);
      _isLoading = false;
      notifyListeners();
      return dept;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateDepartment({
    required String departmentId,
    String? name,
    String? code,
    String? description,
    String? attendanceMode,
    List<String>? allowedBranches,
    bool? isActive,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (name != null) payload['name'] = name.trim();
      if (code != null) payload['code'] = code.trim();
      if (description != null) payload['description'] = description.trim();
      if (attendanceMode != null) payload['attendance_mode'] = attendanceMode;
      if (allowedBranches != null) payload['allowed_branches'] = allowedBranches;
      if (isActive != null) payload['is_active'] = isActive;

      final res = await ApiClient.patch('/accounts/departments/$departmentId/', payload);
      final updated = DepartmentModel.fromJson(res);
      final idx = _departments.indexWhere((d) => d.id == departmentId);
      if (idx != -1) {
        _departments[idx] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteDepartment(String departmentId) async {
    try {
      await ApiClient.delete('/accounts/departments/$departmentId/');
      _departments.removeWhere((d) => d.id == departmentId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
