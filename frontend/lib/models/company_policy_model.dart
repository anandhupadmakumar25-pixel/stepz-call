class CustomProfileFieldModel {
  final String id;
  final String label;
  final String type; // 'text', 'number', 'dropdown', 'boolean'
  final bool required;
  final List<String> options;

  CustomProfileFieldModel({
    required this.id,
    required this.label,
    this.type = 'text',
    this.required = false,
    this.options = const [],
  });

  factory CustomProfileFieldModel.fromJson(Map<String, dynamic> json) {
    return CustomProfileFieldModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      required: json['required'] == true,
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'type': type,
      'required': required,
      'options': options,
    };
  }
}

class CompanyPayrollPolicyModel {
  final String id;
  final String companyName;
  final String shiftStartTime; // e.g. "09:30:00"
  final String shiftEndTime;   // e.g. "18:30:00"
  final int gracePeriodMinutes;
  final double fullDayHours;
  final double halfDayHours;
  final bool allowOutOfFencePunch;
  final bool strictGeofenceBlock;
  final int salaryCycleStartDay;
  final String payCalculationBasis; // 'CALENDAR_DAYS' or 'FIXED_26_DAYS'
  final bool overtimeEnabled;
  final int overtimeMinMinutes;
  final double overtimeHourlyMultiplier;
  final List<CustomProfileFieldModel> customProfileFields;

  CompanyPayrollPolicyModel({
    required this.id,
    this.companyName = '',
    this.shiftStartTime = '09:30:00',
    this.shiftEndTime = '18:30:00',
    this.gracePeriodMinutes = 15,
    this.fullDayHours = 8.0,
    this.halfDayHours = 4.5,
    this.allowOutOfFencePunch = true,
    this.strictGeofenceBlock = false,
    this.salaryCycleStartDay = 1,
    this.payCalculationBasis = 'CALENDAR_DAYS',
    this.overtimeEnabled = false,
    this.overtimeMinMinutes = 60,
    this.overtimeHourlyMultiplier = 1.0,
    this.customProfileFields = const [],
  });

  factory CompanyPayrollPolicyModel.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic val, double fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? fallback;
    }

    int parseInt(dynamic val, int fallback) {
      if (val == null) return fallback;
      if (val is int) return val;
      return int.tryParse(val.toString()) ?? fallback;
    }

    return CompanyPayrollPolicyModel(
      id: json['id']?.toString() ?? '',
      companyName: json['company_name']?.toString() ?? '',
      shiftStartTime: json['shift_start_time']?.toString() ?? '09:30:00',
      shiftEndTime: json['shift_end_time']?.toString() ?? '18:30:00',
      gracePeriodMinutes: parseInt(json['grace_period_minutes'], 15),
      fullDayHours: parseNum(json['full_day_hours'], 8.0),
      halfDayHours: parseNum(json['half_day_hours'], 4.5),
      allowOutOfFencePunch: json['allow_out_of_fence_punch'] ?? true,
      strictGeofenceBlock: json['strict_geofence_block'] ?? false,
      salaryCycleStartDay: parseInt(json['salary_cycle_start_day'], 1),
      payCalculationBasis: json['pay_calculation_basis']?.toString() ?? 'CALENDAR_DAYS',
      overtimeEnabled: json['overtime_enabled'] ?? false,
      overtimeMinMinutes: parseInt(json['overtime_min_minutes'], 60),
      overtimeHourlyMultiplier: parseNum(json['overtime_hourly_multiplier'], 1.0),
      customProfileFields: (json['custom_profile_fields'] as List<dynamic>?)
              ?.map((e) => CustomProfileFieldModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shift_start_time': shiftStartTime,
      'shift_end_time': shiftEndTime,
      'grace_period_minutes': gracePeriodMinutes,
      'full_day_hours': fullDayHours,
      'half_day_hours': halfDayHours,
      'allow_out_of_fence_punch': allowOutOfFencePunch,
      'strict_geofence_block': strictGeofenceBlock,
      'salary_cycle_start_day': salaryCycleStartDay,
      'pay_calculation_basis': payCalculationBasis,
      'overtime_enabled': overtimeEnabled,
      'overtime_min_minutes': overtimeMinMinutes,
      'overtime_hourly_multiplier': overtimeHourlyMultiplier,
      'custom_profile_fields': customProfileFields.map((f) => f.toJson()).toList(),
    };
  }
}

class CompanyCustomRuleModel {
  final String id;
  final String name;
  final String category; // 'LATE_ARRIVAL', 'WORKING_HOURS', 'GEOFENCE', 'OVERTIME', 'DEDUCTION'
  final String categoryDisplay;
  final String description;
  final String triggerMetric; // 'LATE_COUNT', 'WORKING_HOURS_BELOW', 'GEOFENCE_OUT_COUNT', etc.
  final String operator; // 'EVERY_N', 'GREATER_EQUAL', 'EQUALS', 'LESS_THAN'
  final double thresholdValue;
  final int freeAllowanceCount;
  final String actionType; // 'LOP_DAYS', 'FLAT_AMOUNT', 'PERCENTAGE', 'BONUS_AMOUNT', 'WARNING'
  final String actionTypeDisplay;
  final double actionValue;
  final List<String> applicableDepartmentIds;
  final bool isActive;
  final int order;

  CompanyCustomRuleModel({
    required this.id,
    required this.name,
    this.category = 'LATE_ARRIVAL',
    this.categoryDisplay = '',
    this.description = '',
    this.triggerMetric = 'LATE_COUNT',
    this.operator = 'EVERY_N',
    this.thresholdValue = 3.0,
    this.freeAllowanceCount = 0,
    this.actionType = 'LOP_DAYS',
    this.actionTypeDisplay = '',
    this.actionValue = 0.5,
    this.applicableDepartmentIds = const [],
    this.isActive = true,
    this.order = 0,
  });

  factory CompanyCustomRuleModel.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic val, double fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? fallback;
    }

    int parseInt(dynamic val, int fallback) {
      if (val == null) return fallback;
      if (val is int) return val;
      return int.tryParse(val.toString()) ?? fallback;
    }

    return CompanyCustomRuleModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'LATE_ARRIVAL',
      categoryDisplay: json['category_display']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      triggerMetric: json['trigger_metric']?.toString() ?? 'LATE_COUNT',
      operator: json['operator']?.toString() ?? 'EVERY_N',
      thresholdValue: parseNum(json['threshold_value'], 3.0),
      freeAllowanceCount: parseInt(json['free_allowance_count'], 0),
      actionType: json['action_type']?.toString() ?? 'LOP_DAYS',
      actionTypeDisplay: json['action_type_display']?.toString() ?? '',
      actionValue: parseNum(json['action_value'], 0.5),
      applicableDepartmentIds: (json['applicable_department_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isActive: json['is_active'] ?? true,
      order: parseInt(json['order'], 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'description': description,
      'trigger_metric': triggerMetric,
      'operator': operator,
      'threshold_value': thresholdValue,
      'free_allowance_count': freeAllowanceCount,
      'action_type': actionType,
      'action_value': actionValue,
      'applicable_department_ids': applicableDepartmentIds,
      'is_active': isActive,
      'order': order,
    };
  }

  String get humanReadableSummary {
    String triggerText = '';
    if (triggerMetric == 'LATE_COUNT') {
      if (operator == 'EVERY_N') {
        final freeText = freeAllowanceCount > 0 ? ' (Beyond $freeAllowanceCount free)' : '';
        triggerText = 'Every ${thresholdValue.toStringAsFixed(0)} Late Arrivals$freeText';
      } else {
        triggerText = '${thresholdValue.toStringAsFixed(0)}+ Late Arrivals';
      }
    } else if (triggerMetric == 'WORKING_HOURS_BELOW') {
      triggerText = 'Shift Working Hours < ${thresholdValue.toStringAsFixed(1)}h';
    } else if (triggerMetric == 'GEOFENCE_OUT_COUNT') {
      triggerText = '${thresholdValue.toStringAsFixed(0)}+ Out-of-Fence Check-ins';
    } else {
      triggerText = '$triggerMetric ${operator.replaceAll('_', ' ')} ${thresholdValue.toStringAsFixed(1)}';
    }

    String actionText = '';
    if (actionType == 'LOP_DAYS') {
      actionText = 'Deducts ${actionValue.toStringAsFixed(1)} Day(s) Loss of Pay (LOP)';
    } else if (actionType == 'FLAT_AMOUNT') {
      actionText = 'Deducts ₹${actionValue.toStringAsFixed(0)} Penalty';
    } else if (actionType == 'PERCENTAGE') {
      actionText = 'Deducts ${actionValue.toStringAsFixed(1)}% Salary';
    } else if (actionType == 'BONUS_AMOUNT') {
      actionText = 'Adds ₹${actionValue.toStringAsFixed(0)} Incentive/Bonus';
    } else if (actionType == 'WARNING') {
      actionText = 'Issues Automated Formal Warning';
    }

    return '$triggerText ➔ $actionText';
  }
}

