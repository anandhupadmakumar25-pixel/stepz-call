class CallbackModel {
  final String id;
  final String leadId;
  final String leadName;
  final String leadPhone;
  final String assignedEmployeeId;
  final String assignedEmployeeName;
  final String scheduledAt;
  final String status;
  final String initialNotes;
  final String completionNotes;
  final String? completedAt;
  final int rescheduledCount;

  CallbackModel({
    required this.id,
    required this.leadId,
    required this.leadName,
    required this.leadPhone,
    required this.assignedEmployeeId,
    required this.assignedEmployeeName,
    required this.scheduledAt,
    required this.status,
    required this.initialNotes,
    required this.completionNotes,
    this.completedAt,
    required this.rescheduledCount,
  });

  factory CallbackModel.fromJson(Map<String, dynamic> json) {
    return CallbackModel(
      id: json['id']?.toString() ?? '',
      leadId: json['lead']?.toString() ?? '',
      leadName: json['lead_name'] ?? 'Lead',
      leadPhone: json['lead_phone'] ?? '',
      assignedEmployeeId: json['assigned_employee']?.toString() ?? '',
      assignedEmployeeName: json['assigned_employee_name'] ?? '',
      scheduledAt: json['scheduled_at'] ?? '',
      status: json['status'] ?? 'SCHEDULED',
      initialNotes: json['initial_notes'] ?? '',
      completionNotes: json['completion_notes'] ?? '',
      completedAt: json['completed_at'],
      rescheduledCount: json['rescheduled_count'] ?? 0,
    );
  }
}
