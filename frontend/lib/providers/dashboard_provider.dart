import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/dashboard_model.dart';
import '../models/call_model.dart';

class DashboardProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  DashboardKpis _adminKpis = DashboardKpis();
  List<dynamic> _outcomeCounts = [];
  List<dynamic> _activityTimeline = [];
  List<EmployeePerformanceItem> _employeePerformance = [];

  // Telecaller Dashboard
  int _telecallerAssignedLeads = 0;
  int _telecallerCompletedLeads = 0;
  int _telecallerCallsToday = 0;
  int _telecallerDailyTarget = 50;
  int _telecallerCallbacksDueToday = 0;
  int _telecallerCallbacksUpcoming = 0;
  int _telecallerCallbacksOverdue = 0;
  List<CallAttemptModel> _telecallerRecentCalls = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DashboardKpis get adminKpis => _adminKpis;
  List<dynamic> get outcomeCounts => _outcomeCounts;
  List<dynamic> get activityTimeline => _activityTimeline;
  List<EmployeePerformanceItem> get employeePerformance => _employeePerformance;

  int get telecallerAssignedLeads => _telecallerAssignedLeads;
  int get telecallerCompletedLeads => _telecallerCompletedLeads;
  int get telecallerCallsToday => _telecallerCallsToday;
  int get telecallerDailyTarget => _telecallerDailyTarget;
  int get telecallerCallbacksDueToday => _telecallerCallbacksDueToday;
  int get telecallerCallbacksUpcoming => _telecallerCallbacksUpcoming;
  int get telecallerCallbacksOverdue => _telecallerCallbacksOverdue;
  List<CallAttemptModel> get telecallerRecentCalls => _telecallerRecentCalls;

  Future<void> fetchAdminDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.get('/analytics/admin-dashboard/');
      if (res['kpis'] != null) {
        _adminKpis = DashboardKpis.fromJson(res['kpis']);
      }
      _outcomeCounts = res['outcomes'] ?? [];
      _activityTimeline = res['activity_timeline'] ?? [];
      if (res['employee_performance'] != null) {
        _employeePerformance = (res['employee_performance'] as List)
            .map((e) => EmployeePerformanceItem.fromJson(e))
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

  Future<void> fetchTelecallerDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.get('/analytics/telecaller-dashboard/');
      final kpis = res['kpis'] ?? {};
      _telecallerAssignedLeads = kpis['assigned_leads'] ?? 0;
      _telecallerCompletedLeads = kpis['completed_leads'] ?? 0;
      _telecallerCallsToday = kpis['calls_today'] ?? 0;
      _telecallerDailyTarget = kpis['daily_target'] ?? 50;
      _telecallerCallbacksDueToday = kpis['callbacks_due_today'] ?? 0;
      _telecallerCallbacksUpcoming = kpis['callbacks_upcoming'] ?? 0;
      _telecallerCallbacksOverdue = kpis['callbacks_overdue'] ?? 0;

      if (res['recent_calls'] != null) {
        _telecallerRecentCalls = (res['recent_calls'] as List)
            .map((c) => CallAttemptModel.fromJson(c))
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
