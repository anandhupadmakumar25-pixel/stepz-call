class CallRecordingModel {
  final String id;
  final String leadId;
  final String? leadName;
  final String? leadPhone;
  final String? leadCity;
  final String? callAttemptId;
  final String? callOutcome;
  final String employeeId;
  final String? employeeName;
  final String? employeeEmail;
  final String? audioUrl;
  final int durationSeconds;
  final int fileSizeBytes;
  final String source;
  final String notes;
  final DateTime createdAt;

  CallRecordingModel({
    required this.id,
    required this.leadId,
    this.leadName,
    this.leadPhone,
    this.leadCity,
    this.callAttemptId,
    this.callOutcome,
    required this.employeeId,
    this.employeeName,
    this.employeeEmail,
    this.audioUrl,
    required this.durationSeconds,
    required this.fileSizeBytes,
    required this.source,
    required this.notes,
    required this.createdAt,
  });

  factory CallRecordingModel.fromJson(Map<String, dynamic> json) {
    return CallRecordingModel(
      id: json['id']?.toString() ?? '',
      leadId: json['lead']?.toString() ?? '',
      leadName: json['lead_name']?.toString(),
      leadPhone: json['lead_phone']?.toString(),
      leadCity: json['lead_city']?.toString(),
      callAttemptId: json['call_attempt']?.toString(),
      callOutcome: json['call_outcome']?.toString(),
      employeeId: json['employee']?.toString() ?? '',
      employeeName: json['employee_name']?.toString(),
      employeeEmail: json['employee_email']?.toString(),
      audioUrl: json['audio_url']?.toString() ?? json['audio_file']?.toString(),
      durationSeconds: int.tryParse(json['duration_seconds']?.toString() ?? '0') ?? 0,
      fileSizeBytes: int.tryParse(json['file_size_bytes']?.toString() ?? '0') ?? 0,
      source: json['source']?.toString() ?? 'MIC_RECORDING',
      notes: json['notes']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lead': leadId,
      'lead_name': leadName,
      'lead_phone': leadPhone,
      'lead_city': leadCity,
      'call_attempt': callAttemptId,
      'call_outcome': callOutcome,
      'employee': employeeId,
      'employee_name': employeeName,
      'employee_email': employeeEmail,
      'audio_url': audioUrl,
      'duration_seconds': durationSeconds,
      'file_size_bytes': fileSizeBytes,
      'source': source,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
