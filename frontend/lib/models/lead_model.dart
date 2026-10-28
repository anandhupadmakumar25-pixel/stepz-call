class BranchModel {
  final String id;
  final String name;
  final String code;
  final String address;
  final bool isActive;
  final int leadCount;
  final int employeeCount;

  BranchModel({
    required this.id,
    required this.name,
    this.code = '',
    this.address = '',
    this.isActive = true,
    this.leadCount = 0,
    this.employeeCount = 0,
  });

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      address: json['address'] ?? '',
      isActive: json['is_active'] ?? true,
      leadCount: json['lead_count'] ?? 0,
      employeeCount: json['employee_count'] ?? 0,
    );
  }
}

class LeadCategoryModel {
  final String id;
  final String name;
  final String colorCode;
  final String description;
  final bool isActive;
  final int leadCount;

  LeadCategoryModel({
    required this.id,
    required this.name,
    this.colorCode = '#6366F1',
    this.description = '',
    this.isActive = true,
    this.leadCount = 0,
  });

  factory LeadCategoryModel.fromJson(Map<String, dynamic> json) {
    return LeadCategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      colorCode: json['color_code'] ?? '#6366F1',
      description: json['description'] ?? '',
      isActive: json['is_active'] ?? true,
      leadCount: json['lead_count'] ?? 0,
    );
  }
}

class CallingTaskModel {
  final String id;
  final String title;
  final String description;
  final String? branchId;
  final String? branchName;
  final String? categoryId;
  final String? categoryName;
  final String? categoryColor;
  final String? assignedToId;
  final String? assignedToName;
  final String? createdByName;
  final String priority;
  final String status;
  final String? dueDate;
  final int targetCount;
  final int totalLeadsCount;
  final int completedLeadsCount;
  final int inProgressLeadsCount;
  final double progressPercent;
  final String createdAt;

  CallingTaskModel({
    required this.id,
    required this.title,
    this.description = '',
    this.branchId,
    this.branchName,
    this.categoryId,
    this.categoryName,
    this.categoryColor,
    this.assignedToId,
    this.assignedToName,
    this.createdByName,
    this.priority = 'MEDIUM',
    this.status = 'PENDING',
    this.dueDate,
    this.targetCount = 0,
    this.totalLeadsCount = 0,
    this.completedLeadsCount = 0,
    this.inProgressLeadsCount = 0,
    this.progressPercent = 0.0,
    required this.createdAt,
  });

  factory CallingTaskModel.fromJson(Map<String, dynamic> json) {
    return CallingTaskModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      branchId: json['branch']?.toString(),
      branchName: json['branch_name'],
      categoryId: json['category']?.toString(),
      categoryName: json['category_name'],
      categoryColor: json['category_color'] ?? '#6366F1',
      assignedToId: json['assigned_to']?.toString(),
      assignedToName: json['assigned_to_name'],
      createdByName: json['created_by_name'],
      priority: json['priority'] ?? 'MEDIUM',
      status: json['status'] ?? 'PENDING',
      dueDate: json['due_date'],
      targetCount: json['target_count'] ?? 0,
      totalLeadsCount: json['total_leads_count'] ?? 0,
      completedLeadsCount: json['completed_leads_count'] ?? 0,
      inProgressLeadsCount: json['in_progress_leads_count'] ?? 0,
      progressPercent: (json['progress_percent'] is num) ? (json['progress_percent'] as num).toDouble() : 0.0,
      createdAt: json['created_at'] ?? '',
    );
  }
}

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
  final String? branchId;
  final String? branchName;
  final String? categoryId;
  final String? categoryName;
  final String? categoryColor;
  final String? taskId;
  final String? taskTitle;
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
    this.branchId,
    this.branchName,
    this.categoryId,
    this.categoryName,
    this.categoryColor,
    this.taskId,
    this.taskTitle,
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
      branchId: json['branch']?.toString(),
      branchName: json['branch_name'],
      categoryId: json['category']?.toString(),
      categoryName: json['category_name'],
      categoryColor: json['category_color'] ?? '#6366F1',
      taskId: json['task']?.toString(),
      taskTitle: json['task_title'],
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
