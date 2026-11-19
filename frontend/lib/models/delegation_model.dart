class PermissionItemModel {
  final String key;
  final String label;
  final String description;

  PermissionItemModel({
    required this.key,
    required this.label,
    this.description = '',
  });

  factory PermissionItemModel.fromJson(Map<String, dynamic> json) {
    return PermissionItemModel(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }
}

class PermissionGroupModel {
  final String key;
  final String label;
  final String menuKey;
  final String icon;
  final List<PermissionItemModel> permissions;

  PermissionGroupModel({
    required this.key,
    required this.label,
    required this.menuKey,
    this.icon = 'security',
    this.permissions = const [],
  });

  factory PermissionGroupModel.fromJson(Map<String, dynamic> json) {
    final rawPerms = json['permissions'] as List<dynamic>? ?? [];
    return PermissionGroupModel(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      menuKey: json['menu_key']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'security',
      permissions: rawPerms
          .whereType<Map<String, dynamic>>()
          .map((e) => PermissionItemModel.fromJson(e))
          .toList(),
    );
  }
}

class SectionDelegationModel {
  final String id;
  final String delegatorId;
  final String delegatorName;
  final String delegatorEmail;
  final String delegateeId;
  final String delegateeName;
  final String delegateeEmail;
  final String title;
  final List<String> sections;
  final List<String> permissions;
  final String startDate;
  final String endDate;
  final String reason;
  final bool isActive;
  final bool isCurrentlyEffective;
  final String? revokedAt;
  final String revokedByName;
  final String createdAt;

  SectionDelegationModel({
    required this.id,
    required this.delegatorId,
    required this.delegatorName,
    this.delegatorEmail = '',
    required this.delegateeId,
    required this.delegateeName,
    this.delegateeEmail = '',
    this.title = '',
    this.sections = const [],
    this.permissions = const [],
    required this.startDate,
    required this.endDate,
    this.reason = '',
    this.isActive = true,
    this.isCurrentlyEffective = false,
    this.revokedAt,
    this.revokedByName = '',
    this.createdAt = '',
  });

  factory SectionDelegationModel.fromJson(Map<String, dynamic> json) {
    return SectionDelegationModel(
      id: json['id']?.toString() ?? '',
      delegatorId: json['delegator']?.toString() ?? '',
      delegatorName: json['delegator_name']?.toString() ?? '',
      delegatorEmail: json['delegator_email']?.toString() ?? '',
      delegateeId: json['delegatee']?.toString() ?? '',
      delegateeName: json['delegatee_name']?.toString() ?? '',
      delegateeEmail: json['delegatee_email']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      sections: (json['sections'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      permissions: (json['permissions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      isActive: json['is_active'] == true,
      isCurrentlyEffective: json['is_currently_effective'] == true,
      revokedAt: json['revoked_at']?.toString(),
      revokedByName: json['revoked_by_name']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class PermissionAuditLogModel {
  final String id;
  final String actorName;
  final String onBehalfOfName;
  final String action;
  final String targetModel;
  final String targetId;
  final Map<String, dynamic> details;
  final String ipAddress;
  final String createdAt;

  PermissionAuditLogModel({
    required this.id,
    required this.actorName,
    this.onBehalfOfName = '',
    required this.action,
    this.targetModel = '',
    this.targetId = '',
    this.details = const {},
    this.ipAddress = '',
    required this.createdAt,
  });

  factory PermissionAuditLogModel.fromJson(Map<String, dynamic> json) {
    return PermissionAuditLogModel(
      id: json['id']?.toString() ?? '',
      actorName: json['actor_name']?.toString() ?? 'System',
      onBehalfOfName: json['on_behalf_of_name']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      targetModel: json['target_model']?.toString() ?? '',
      targetId: json['target_id']?.toString() ?? '',
      details: (json['details'] as Map<String, dynamic>?) ?? {},
      ipAddress: json['ip_address']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

