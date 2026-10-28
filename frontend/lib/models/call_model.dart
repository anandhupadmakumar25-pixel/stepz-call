class CallAttemptModel {
  final String id;
  final String leadId;
  final String leadName;
  final String leadPhone;
  final String employeeId;
  final String employeeName;
  final String outcome;
  final String notes;
  final int durationSeconds;
  final String? dialerLaunchedAt;
  final String createdAt;

  CallAttemptModel({
    required this.id,
    required this.leadId,
    required this.leadName,
    required this.leadPhone,
    required this.employeeId,
    required this.employeeName,
    required this.outcome,
    required this.notes,
    required this.durationSeconds,
    this.dialerLaunchedAt,
    required this.createdAt,
  });

  factory CallAttemptModel.fromJson(Map<String, dynamic> json) {
    return CallAttemptModel(
      id: json['id']?.toString() ?? '',
      leadId: json['lead']?.toString() ?? '',
      leadName: json['lead_name'] ?? 'Lead',
      leadPhone: json['lead_phone'] ?? '',
      employeeId: json['employee']?.toString() ?? '',
      employeeName: json['employee_name'] ?? 'Employee',
      outcome: json['outcome'] ?? '',
      notes: json['notes'] ?? '',
      durationSeconds: json['duration_seconds'] ?? 0,
      dialerLaunchedAt: json['dialer_launched_at'],
      createdAt: json['created_at'] ?? '',
    );
  }
}
