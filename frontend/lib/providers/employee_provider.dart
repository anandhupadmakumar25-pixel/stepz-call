import 'package:flutter/material.dart';
import '../core/network/api_client.dart';

class EmployeeProvider extends ChangeNotifier {
  List<dynamic> _employees = [];
  List<dynamic> _teams = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<dynamic> get employees => _employees;
  List<dynamic> get teams => _teams;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchEmployees({String? teamId, String? branchId, String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final params = <String>[];
      if (teamId != null && teamId.isNotEmpty && teamId != 'ALL') params.add('team=$teamId');
      if (branchId != null && branchId.isNotEmpty && branchId != 'ALL') params.add('branch=$branchId');
      if (search != null && search.isNotEmpty) params.add('search=${Uri.encodeComponent(search)}');
      final query = params.isNotEmpty ? '?${params.join('&')}' : '';

      final res = await ApiClient.get('/accounts/employees/$query');
      if (res is List) {
        _employees = res;
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

  Future<bool> updateEmployeeBranch(String employeeId, String? branchId) async {
    try {
      final res = await ApiClient.patch('/accounts/employees/$employeeId/', {
        'branch_id': branchId,
      });
      final idx = _employees.indexWhere((e) => e['id'] == employeeId);
      if (idx != -1) {
        _employees[idx] = res;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchTeams() async {
    try {
      final res = await ApiClient.get('/accounts/teams/');
      if (res is List) {
        _teams = res;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> createEmployee(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/accounts/employees/', data);
      _employees.insert(0, res);
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

  Future<bool> toggleEmployeeStatus(String employeeId, bool isActive) async {
    try {
      final res = await ApiClient.patch('/accounts/employees/$employeeId/', {
        'is_active': isActive,
      });
      final idx = _employees.indexWhere((e) => e['id'] == employeeId);
      if (idx != -1) {
        _employees[idx] = res;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
