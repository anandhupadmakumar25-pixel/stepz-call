import 'package:flutter/material.dart';
import '../core/network/api_client.dart';

class HrPayrollProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _holidays = [];
  List<Map<String, dynamic>> _leaveTypes = [];
  List<Map<String, dynamic>> _leaveBalances = [];
  List<Map<String, dynamic>> _leaveRequests = [];
  List<Map<String, dynamic>> _regularizations = [];
  List<Map<String, dynamic>> _salaryStructures = [];
  List<Map<String, dynamic>> _payrollRuns = [];
  List<Map<String, dynamic>> _myPayslips = [];
  List<Map<String, dynamic>> _activeRunPayslips = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> get holidays => _holidays;
  List<Map<String, dynamic>> get leaveTypes => _leaveTypes;
  List<Map<String, dynamic>> get leaveBalances => _leaveBalances;
  List<Map<String, dynamic>> get leaveRequests => _leaveRequests;
  List<Map<String, dynamic>> get regularizations => _regularizations;
  List<Map<String, dynamic>> get salaryStructures => _salaryStructures;
  List<Map<String, dynamic>> get payrollRuns => _payrollRuns;
  List<Map<String, dynamic>> get myPayslips => _myPayslips;
  List<Map<String, dynamic>> get activeRunPayslips => _activeRunPayslips;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchHolidays() async {
    try {
      final res = await ApiClient.get('/accounts/holidays/');
      if (res is List) {
        _holidays = res.whereType<Map<String, dynamic>>().toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> createHoliday({required String name, required String date, bool isOptional = false}) async {
    _errorMessage = null;
    try {
      await ApiClient.post('/accounts/holidays/', {'name': name.trim(), 'date': date, 'is_optional': isOptional});
      await fetchHolidays();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteHoliday(String id) async {
    try {
      await ApiClient.delete('/accounts/holidays/$id/');
      _holidays.removeWhere((h) => h['id'].toString() == id);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchLeaveTypes() async {
    try {
      final res = await ApiClient.get('/accounts/leave-types/');
      if (res is List) {
        _leaveTypes = res.whereType<Map<String, dynamic>>().toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> fetchLeaveBalances() async {
    try {
      final res = await ApiClient.get('/accounts/leave-balances/');
      if (res is List) {
        _leaveBalances = res.whereType<Map<String, dynamic>>().toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> fetchLeaveRequests() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiClient.get('/accounts/leaves/');
      if (res is List) {
        _leaveRequests = res.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {} finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> applyLeave({
    required String leaveTypeId,
    required String startDate,
    required String endDate,
    bool isHalfDay = false,
    String reason = '',
  }) async {
    _errorMessage = null;
    try {
      await ApiClient.post('/accounts/leaves/', {
        'leave_type': leaveTypeId,
        'start_date': startDate,
        'end_date': endDate,
        'is_half_day': isHalfDay,
        'reason': reason.trim(),
      });
      await Future.wait([fetchLeaveRequests(), fetchLeaveBalances()]);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> actionLeave(String id, String action, {String notes = ''}) async {
    _errorMessage = null;
    try {
      await ApiClient.post('/accounts/leaves/$id/action/', {'action': action, 'review_notes': notes});
      await Future.wait([fetchLeaveRequests(), fetchLeaveBalances()]);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchRegularizations() async {
    try {
      final res = await ApiClient.get('/accounts/regularizations/');
      if (res is List) {
        _regularizations = res.whereType<Map<String, dynamic>>().toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> submitRegularization({
    required String date,
    required String checkIn,
    String? checkOut,
    required String reason,
  }) async {
    _errorMessage = null;
    try {
      await ApiClient.post('/accounts/regularizations/', {
        'date': date,
        'requested_check_in': checkIn,
        if (checkOut != null && checkOut.isNotEmpty) 'requested_check_out': checkOut,
        'reason': reason.trim(),
      });
      await fetchRegularizations();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> actionRegularization(String id, String action) async {
    try {
      await ApiClient.post('/accounts/regularizations/$id/action/', {'action': action});
      await fetchRegularizations();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> fetchSalaryStructures() async {
    try {
      final res = await ApiClient.get('/accounts/salary-structures/');
      if (res is List) {
        _salaryStructures = res.whereType<Map<String, dynamic>>().toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> saveSalaryStructure(Map<String, dynamic> payload) async {
    _errorMessage = null;
    try {
      await ApiClient.post('/accounts/salary-structures/', payload);
      await fetchSalaryStructures();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchPayrollRuns() async {
    try {
      final res = await ApiClient.get('/accounts/payroll-runs/');
      if (res is List) {
        _payrollRuns = res.whereType<Map<String, dynamic>>().toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> generatePayrollRun(int month, int year) async {
    _errorMessage = null;
    try {
      await ApiClient.post('/accounts/payroll-runs/', {'month': month, 'year': year});
      await fetchPayrollRuns();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchPayrollRunDetail(String runId) async {
    try {
      final res = await ApiClient.get('/accounts/payroll-runs/$runId/');
      if (res is Map<String, dynamic> && res['payslips'] is List) {
        _activeRunPayslips = (res['payslips'] as List).whereType<Map<String, dynamic>>().toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> actionPayrollRun(String runId, String action, {String paymentReference = ''}) async {
    try {
      await ApiClient.post('/accounts/payroll-runs/$runId/action/', {
        'action': action,
        'payment_reference': paymentReference,
      });
      await fetchPayrollRuns();
      await fetchPayrollRunDetail(runId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> fetchMyPayslips() async {
    try {
      final res = await ApiClient.get('/accounts/my-payslips/');
      if (res is List) {
        _myPayslips = res.whereType<Map<String, dynamic>>().toList();
        notifyListeners();
      }
    } catch (_) {}
  }
}

