class LeadModel {
  final String id;
  final String firstName;
  final String lastName;
  final String fullName;
  final String rawPhone;
  final String normalizedPhone;
  final String email;
  final String city;
  final String state;
  final String source;
  final String status;
  final String? assignedTo;
  final String? assignedToName;
  final String? assignedAt;
  final bool isAssignedEver;
  final int callAttemptsCount;
  final int callbacksCount;
  final String createdAt;

  LeadModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.rawPhone,
    required this.normalizedPhone,
    required this.email,
    required this.city,
    required this.state,
    required this.source,
    required this.status,
    this.assignedTo,
    this.assignedToName,
    this.assignedAt,
    this.isAssignedEver = false,
    this.callAttemptsCount = 0,
    this.callbacksCount = 0,
    required this.createdAt,
  });

  factory LeadModel.fromJson(Map<String, dynamic> json) {
    return LeadModel(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      fullName: json['full_name'] ?? '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim(),
      rawPhone: json['raw_phone'] ?? '',
      normalizedPhone: json['normalized_phone'] ?? '',
      email: json['email'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      source: json['source'] ?? 'MANUAL',
      status: json['status'] ?? 'UNASSIGNED',
      assignedTo: json['assigned_to']?.toString(),
      assignedToName: json['assigned_to_name'],
      assignedAt: json['assigned_at'],
      isAssignedEver: json['is_assigned_ever'] ?? false,
      callAttemptsCount: json['call_attempts_count'] ?? 0,
      callbacksCount: json['callbacks_count'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class ImportBatchModel {
  final String id;
  final String fileName;
  final int totalRows;
  final int validNewCount;
  final int duplicateInFileCount;
  final int previouslyRegisteredCount;
  final int permanentlyBlockedCount;
  final int invalidRowsCount;
  final String status;
  final List<dynamic> stagingData;
  final List<dynamic> rowErrors;

  ImportBatchModel({
    required this.id,
    required this.fileName,
    required this.totalRows,
    required this.validNewCount,
    required this.duplicateInFileCount,
    required this.previouslyRegisteredCount,
    required this.permanentlyBlockedCount,
    required this.invalidRowsCount,
    required this.status,
    this.stagingData = const [],
    this.rowErrors = const [],
  });

  factory ImportBatchModel.fromJson(Map<String, dynamic> json) {
    return ImportBatchModel(
      id: json['id']?.toString() ?? '',
      fileName: json['file_name'] ?? '',
      totalRows: json['total_rows'] ?? 0,
      validNewCount: json['valid_new_count'] ?? 0,
      duplicateInFileCount: json['duplicate_in_file_count'] ?? 0,
      previouslyRegisteredCount: json['previously_registered_count'] ?? 0,
      permanentlyBlockedCount: json['permanently_blocked_count'] ?? 0,
      invalidRowsCount: json['invalid_rows_count'] ?? 0,
      status: json['status'] ?? 'PENDING',
      stagingData: json['staging_data'] ?? [],
      rowErrors: json['row_errors'] ?? [],
    );
  }
}
