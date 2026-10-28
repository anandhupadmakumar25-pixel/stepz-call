class DashboardKpis {
  final int totalRegisteredLeads;
  final int newlyImportedLeads;
  final int assignedLeads;
  final int unassignedLeads;
  final int callsLoggedToday;
  final int callsLoggedTotal;
  final int completedLeads;
  final int scheduledCallbacks;
  final int completedCallbacks;
  final int overdueCallbacks;

  DashboardKpis({
    this.totalRegisteredLeads = 0,
    this.newlyImportedLeads = 0,
    this.assignedLeads = 0,
    this.unassignedLeads = 0,
    this.callsLoggedToday = 0,
    this.callsLoggedTotal = 0,
    this.completedLeads = 0,
    this.scheduledCallbacks = 0,
    this.completedCallbacks = 0,
    this.overdueCallbacks = 0,
  });

  factory DashboardKpis.fromJson(Map<String, dynamic> json) {
    return DashboardKpis(
      totalRegisteredLeads: json['total_registered_leads'] ?? 0,
      newlyImportedLeads: json['newly_imported_leads'] ?? 0,
      assignedLeads: json['assigned_leads'] ?? 0,
      unassignedLeads: json['unassigned_leads'] ?? 0,
      callsLoggedToday: json['calls_logged_today'] ?? 0,
      callsLoggedTotal: json['calls_logged_total'] ?? 0,
      completedLeads: json['completed_leads'] ?? 0,
      scheduledCallbacks: json['scheduled_callbacks'] ?? 0,
      completedCallbacks: json['completed_callbacks'] ?? 0,
      overdueCallbacks: json['overdue_callbacks'] ?? 0,
    );
  }
}

class EmployeePerformanceItem {
  final String employeeId;
  final String name;
  final String email;
  final int assignedLeads;
  final int callsToday;
  final int dailyTarget;
  final int callsTotal;
  final int completedLeads;
  final int callbacksDue;
  final int callbacksDone;
  final int callbacksOverdue;
  final String? lastActivity;

  EmployeePerformanceItem({
    required this.employeeId,
    required this.name,
    required this.email,
    required this.assignedLeads,
    required this.callsToday,
    required this.dailyTarget,
    required this.callsTotal,
    required this.completedLeads,
    required this.callbacksDue,
    required this.callbacksDone,
    required this.callbacksOverdue,
    this.lastActivity,
  });

  factory EmployeePerformanceItem.fromJson(Map<String, dynamic> json) {
    return EmployeePerformanceItem(
      employeeId: json['employee_id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      assignedLeads: json['assigned_leads'] ?? 0,
      callsToday: json['calls_today'] ?? 0,
      dailyTarget: json['daily_target'] ?? 50,
      callsTotal: json['calls_total'] ?? 0,
      completedLeads: json['completed_leads'] ?? 0,
      callbacksDue: json['callbacks_due'] ?? 0,
      callbacksDone: json['callbacks_done'] ?? 0,
      callbacksOverdue: json['callbacks_overdue'] ?? 0,
      lastActivity: json['last_activity'],
    );
  }
}
