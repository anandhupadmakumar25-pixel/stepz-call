import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/glass_text_field.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/animated_status_badge.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../providers/company_provider.dart';
import '../../models/company_policy_model.dart';

class CompanyRulesTab extends StatefulWidget {
  const CompanyRulesTab({super.key});

  @override
  State<CompanyRulesTab> createState() => _CompanyRulesTabState();
}

class _CompanyRulesTabState extends State<CompanyRulesTab> {
  // Baseline Policy Controllers
  final _shiftStartCtrl = TextEditingController(text: '09:30 AM');
  final _shiftEndCtrl = TextEditingController(text: '06:30 PM');
  final _gracePeriodCtrl = TextEditingController(text: '15');
  final _fullDayHoursCtrl = TextEditingController(text: '8.0');
  final _halfDayHoursCtrl = TextEditingController(text: '4.5');
  final _salaryCycleStartCtrl = TextEditingController(text: '1');

  bool _allowOutOfFence = true;
  bool _strictGeofence = false;
  String _payBasis = 'CALENDAR_DAYS';
  bool _isSavingPolicy = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final compProv = context.read<CompanyProvider>();
    await Future.wait([
      compProv.fetchPayrollPolicy(),
      compProv.fetchCompanyRules(),
    ]);

    final policy = compProv.payrollPolicy;
    if (policy != null && mounted) {
      setState(() {
        _shiftStartCtrl.text = _formatTimeString(policy.shiftStartTime);
        _shiftEndCtrl.text = _formatTimeString(policy.shiftEndTime);
        _gracePeriodCtrl.text = policy.gracePeriodMinutes.toString();
        _fullDayHoursCtrl.text = policy.fullDayHours.toString();
        _halfDayHoursCtrl.text = policy.halfDayHours.toString();
        _salaryCycleStartCtrl.text = policy.salaryCycleStartDay.toString();
        _allowOutOfFence = policy.allowOutOfFencePunch;
        _strictGeofence = policy.strictGeofenceBlock;
        _payBasis = policy.payCalculationBasis;
        _initialized = true;
      });
    } else {
      setState(() => _initialized = true);
    }
  }

  String _formatTimeString(String raw) {
    try {
      final parts = raw.split(':');
      if (parts.length >= 2) {
        int h = int.parse(parts[0]);
        int m = int.parse(parts[1]);
        final ampm = h >= 12 ? 'PM' : 'AM';
        h = h % 12;
        if (h == 0) h = 12;
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm';
      }
    } catch (_) {}
    return raw;
  }

  String _to24HourString(String formatted) {
    try {
      final parts = formatted.trim().split(' ');
      if (parts.length == 2) {
        final timeParts = parts[0].split(':');
        int h = int.parse(timeParts[0]);
        int m = int.parse(timeParts[1]);
        final ampm = parts[1].toUpperCase();
        if (ampm == 'PM' && h < 12) h += 12;
        if (ampm == 'AM' && h == 12) h = 0;
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00';
      }
    } catch (_) {}
    return '09:30:00';
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
    );
    if (picked != null) {
      final h = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final m = picked.minute.toString().padLeft(2, '0');
      final ampm = picked.period == DayPeriod.pm ? 'PM' : 'AM';
      setState(() {
        controller.text = '${h.toString().padLeft(2, '0')}:$m $ampm';
      });
    }
  }

  Future<void> _saveBaselinePolicy() async {
    setState(() => _isSavingPolicy = true);
    final compProv = context.read<CompanyProvider>();
    final ok = await compProv.updatePayrollPolicy({
      'shift_start_time': _to24HourString(_shiftStartCtrl.text),
      'shift_end_time': _to24HourString(_shiftEndCtrl.text),
      'grace_period_minutes': int.tryParse(_gracePeriodCtrl.text) ?? 15,
      'full_day_hours': double.tryParse(_fullDayHoursCtrl.text) ?? 8.0,
      'half_day_hours': double.tryParse(_halfDayHoursCtrl.text) ?? 4.5,
      'salary_cycle_start_day': int.tryParse(_salaryCycleStartCtrl.text) ?? 1,
      'allow_out_of_fence_punch': _allowOutOfFence,
      'strict_geofence_block': _strictGeofence,
      'pay_calculation_basis': _payBasis,
    });
    setState(() => _isSavingPolicy = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Company policy & shift timings saved!' : 'Failed to save policy.'),
          backgroundColor: ok ? AppColors.success : AppColors.neonCoral,
        ),
      );
    }
  }

  Future<void> _applyPreset(String key, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Apply "$title" Preset?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'This will configure standard shift timings, grace periods, and late penalty rules for your company.',
          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonCyan),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply Preset', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final compProv = context.read<CompanyProvider>();
    final ok = await compProv.loadRulePreset(key, replaceExisting: false);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Preset "$title" applied successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadData();
    }
  }

  void _showAddEditRuleDialog([CompanyCustomRuleModel? existingRule]) {
    final isEditing = existingRule != null;
    final nameCtrl = TextEditingController(text: existingRule?.name ?? '');
    final descCtrl = TextEditingController(text: existingRule?.description ?? '');
    String category = existingRule?.category ?? 'LATE_ARRIVAL';
    String triggerMetric = existingRule?.triggerMetric ?? 'LATE_COUNT';
    String operator = existingRule?.operator ?? 'EVERY_N';
    final thresholdCtrl = TextEditingController(
      text: existingRule != null ? existingRule.thresholdValue.toStringAsFixed(0) : '3',
    );
    final freeAllowanceCtrl = TextEditingController(
      text: existingRule != null ? existingRule.freeAllowanceCount.toString() : '3',
    );
    String actionType = existingRule?.actionType ?? 'LOP_DAYS';
    final actionValueCtrl = TextEditingController(
      text: existingRule != null ? existingRule.actionValue.toString() : '0.5',
    );

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) {
        final isMobile = ResponsiveLayout.isMobile(ctx);
        return StatefulBuilder(
          builder: (context, setDlgState) {
            // Compute real-time preview sentence
            final freeVal = int.tryParse(freeAllowanceCtrl.text) ?? 0;
            final threshVal = thresholdCtrl.text.isNotEmpty ? thresholdCtrl.text : '3';
            final actVal = actionValueCtrl.text.isNotEmpty ? actionValueCtrl.text : '0.5';

            String liveSummary = '';
            if (triggerMetric == 'LATE_COUNT') {
              if (operator == 'EVERY_N') {
                final freeText = freeVal > 0 ? ' (beyond $freeVal free days)' : '';
                liveSummary = 'Every $threshVal Late Arrivals$freeText in a month ';
              } else {
                liveSummary = 'Reaching $threshVal or more Late Arrivals in a month ';
              }
            } else if (triggerMetric == 'WORKING_HOURS_BELOW') {
              liveSummary = 'Working less than $threshVal hours on any shift ';
            } else if (triggerMetric == 'GEOFENCE_OUT_COUNT') {
              liveSummary = 'Accumulating $threshVal unverified Out-of-Fence check-ins ';
            }

            if (actionType == 'LOP_DAYS') {
              liveSummary += 'deducts $actVal Day(s) Loss of Pay (LOP) from salary.';
            } else if (actionType == 'FLAT_AMOUNT') {
              liveSummary += 'deducts a flat fine of ₹$actVal.';
            } else if (actionType == 'PERCENTAGE') {
              liveSummary += 'deducts $actVal% of monthly basic pay.';
            } else if (actionType == 'WARNING') {
              liveSummary += 'automatically sends a formal warning notice.';
            } else if (actionType == 'BONUS_AMOUNT') {
              liveSummary += 'awards a bonus addition of ₹$actVal.';
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: GlassCard(
                  blur: 24,
                  opacity: 0.98,
                  borderRadius: BorderRadius.circular(20),
                  borderColor: AppColors.glassBorderHighlight,
                  padding: EdgeInsets.all(isMobile ? 18 : 24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.rule_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isEditing ? 'Edit Company Rule' : 'Create Custom Company Rule',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            DialogCloseButton(onPressed: () => Navigator.pop(ctx)),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Rule Name
                        GlassTextField(
                          label: 'Rule Name *',
                          hintText: 'e.g. Late Arrival LOP Penalty',
                          controller: nameCtrl,
                        ),
                        const SizedBox(height: 12),

                        // Category Dropdown
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('RULE CATEGORY', style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.glassBorder),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: category,
                                  items: const [
                                    DropdownMenuItem(value: 'LATE_ARRIVAL', child: Text('Late Coming & Punctuality')),
                                    DropdownMenuItem(value: 'WORKING_HOURS', child: Text('Working Hours & Half-Day')),
                                    DropdownMenuItem(value: 'GEOFENCE', child: Text('Geofence & Absence')),
                                    DropdownMenuItem(value: 'OVERTIME', child: Text('Overtime & Incentives')),
                                    DropdownMenuItem(value: 'DEDUCTION', child: Text('Custom Penalties & Deductions')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setDlgState(() {
                                        category = v;
                                        if (category == 'LATE_ARRIVAL') triggerMetric = 'LATE_COUNT';
                                        if (category == 'WORKING_HOURS') triggerMetric = 'WORKING_HOURS_BELOW';
                                        if (category == 'GEOFENCE') triggerMetric = 'GEOFENCE_OUT_COUNT';
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Condition Builder Section
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RULE TRIGGER CONDITION',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.neonViolet),
                              ),
                              const SizedBox(height: 10),
                              if (category == 'LATE_ARRIVAL') ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: GlassTextField(
                                        label: 'Free Lates Allowed / Month',
                                        hintText: '3',
                                        controller: freeAllowanceCtrl,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setDlgState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: GlassTextField(
                                        label: 'Every N Late Days',
                                        hintText: '3',
                                        controller: thresholdCtrl,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setDlgState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (category == 'WORKING_HOURS') ...[
                                GlassTextField(
                                  label: 'Hours Threshold (Less Than)',
                                  hintText: '4.5',
                                  controller: thresholdCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setDlgState(() {}),
                                ),
                              ] else ...[
                                GlassTextField(
                                  label: 'Threshold Count',
                                  hintText: '3',
                                  controller: thresholdCtrl,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setDlgState(() {}),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Consequence / Action Builder Section
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CONSEQUENCE / PENALTY ACTION',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.neonCyan),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppColors.glassBorder),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          value: actionType,
                                          items: const [
                                            DropdownMenuItem(value: 'LOP_DAYS', child: Text('Loss of Pay (Days)')),
                                            DropdownMenuItem(value: 'FLAT_AMOUNT', child: Text('Flat Deduction (₹)')),
                                            DropdownMenuItem(value: 'PERCENTAGE', child: Text('Percentage Deduction (%)')),
                                            DropdownMenuItem(value: 'WARNING', child: Text('Formal Warning')),
                                            DropdownMenuItem(value: 'BONUS_AMOUNT', child: Text('Incentive Addition (+₹)')),
                                          ],
                                          onChanged: (v) {
                                            if (v != null) {
                                              setDlgState(() => actionType = v);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: GlassTextField(
                                      label: actionType == 'LOP_DAYS' ? 'Days (e.g. 0.5)' : 'Amount / Value',
                                      hintText: '0.5',
                                      controller: actionValueCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (_) => setDlgState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Live Dynamic Preview Box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.neonCyan.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome_rounded, color: AppColors.neonCyan, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('LIVE RULE EVALUATION', style: GoogleFonts.robotoMono(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.neonCyan)),
                                    const SizedBox(height: 2),
                                    Text(liveSummary, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GlassSecondaryButton(
                              text: 'Cancel',
                              onPressed: () => Navigator.pop(ctx),
                            ),
                            const SizedBox(width: 10),
                            GradientPrimaryButton(
                              text: isEditing ? 'Save Changes' : 'Create Rule',
                              icon: Icons.check_rounded,
                              onPressed: () async {
                                final name = nameCtrl.text.trim();
                                if (name.isEmpty) return;

                                final compProv = context.read<CompanyProvider>();
                                final payload = {
                                  'name': name,
                                  'category': category,
                                  'description': descCtrl.text.trim(),
                                  'trigger_metric': triggerMetric,
                                  'operator': operator,
                                  'free_allowance_count': int.tryParse(freeAllowanceCtrl.text) ?? 0,
                                  'threshold_value': double.tryParse(thresholdCtrl.text) ?? 3.0,
                                  'action_type': actionType,
                                  'action_value': double.tryParse(actionValueCtrl.text) ?? 0.5,
                                  'is_active': true,
                                };

                                final messenger = ScaffoldMessenger.of(context);
                                Navigator.pop(ctx);
                                bool ok;
                                if (isEditing) {
                                  ok = await compProv.updateCompanyRule(existingRule.id, payload);
                                } else {
                                  ok = await compProv.createCompanyRule(payload);
                                }

                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(ok ? 'Rule saved successfully!' : 'Failed to save rule.'),
                                    backgroundColor: ok ? AppColors.success : AppColors.neonCoral,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteRule(CompanyCustomRuleModel rule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete "${rule.name}"?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to permanently remove this rule?', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonCoral),
            onPressed: () async {
              Navigator.pop(ctx);
              final compProv = context.read<CompanyProvider>();
              await compProv.deleteCompanyRule(rule.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compProv = context.watch<CompanyProvider>();
    final isMobile = ResponsiveLayout.isMobile(context);
    final rules = compProv.companyRules;

    if (!_initialized || compProv.isLoadingPolicy) {
      return const Center(child: CircularProgressIndicator(color: AppColors.neonCyan));
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Preset Quick Action Bar ─────────────────────────────────────────
          GlassCard(
            blur: 16,
            opacity: 0.12,
            borderRadius: BorderRadius.circular(16),
            borderColor: AppColors.glassBorder,
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('QUICK POLICY PRESETS', style: GoogleFonts.robotoMono(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.neonCyan)),
                    const SizedBox(height: 2),
                    Text('Apply standardized enterprise attendance & payroll templates', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PresetButton(
                      label: 'Corporate Standard',
                      icon: Icons.apartment_rounded,
                      color: AppColors.neonCyan,
                      onPressed: () => _applyPreset('STANDARD', 'Corporate Standard'),
                    ),
                    _PresetButton(
                      label: 'Strict Attendance',
                      icon: Icons.timer_rounded,
                      color: const Color(0xFFF59E0B),
                      onPressed: () => _applyPreset('STRICT', 'Strict Attendance'),
                    ),
                    _PresetButton(
                      label: 'Flexible Startup',
                      icon: Icons.spa_rounded,
                      color: const Color(0xFF10B981),
                      onPressed: () => _applyPreset('FLEXIBLE', 'Flexible Startup'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Card 1: Baseline Timings & Shift Hours ─────────────────────────
          GlassCard(
            blur: 18,
            opacity: 0.12,
            borderRadius: BorderRadius.circular(18),
            borderColor: AppColors.glassBorder,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.schedule_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Shift Timings & Grace Period', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                            Text('Default working hours across company departments', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                    GradientPrimaryButton(
                      text: _isSavingPolicy ? 'Saving...' : 'Save Timings',
                      icon: Icons.save_rounded,
                      onPressed: _isSavingPolicy ? null : _saveBaselinePolicy,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 14),

                // Times Row
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: isMobile ? double.infinity : 180,
                      child: InkWell(
                        onTap: () => _pickTime(_shiftStartCtrl),
                        child: IgnorePointer(
                          child: GlassTextField(
                            label: 'Shift Start Time',
                            hintText: '09:30 AM',
                            controller: _shiftStartCtrl,
                            suffixIcon: const Icon(Icons.access_time_rounded, size: 18, color: AppColors.neonCyan),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: isMobile ? double.infinity : 180,
                      child: InkWell(
                        onTap: () => _pickTime(_shiftEndCtrl),
                        child: IgnorePointer(
                          child: GlassTextField(
                            label: 'Shift End Time',
                            hintText: '06:30 PM',
                            controller: _shiftEndCtrl,
                            suffixIcon: const Icon(Icons.access_time_filled_rounded, size: 18, color: AppColors.neonCyan),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: isMobile ? double.infinity : 180,
                      child: GlassTextField(
                        label: 'Grace Period (mins)',
                        hintText: '15',
                        controller: _gracePeriodCtrl,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(
                      width: isMobile ? double.infinity : 180,
                      child: GlassTextField(
                        label: 'Full-Day Min Hours',
                        hintText: '8.0',
                        controller: _fullDayHoursCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    SizedBox(
                      width: isMobile ? double.infinity : 180,
                      child: GlassTextField(
                        label: 'Half-Day Min Hours',
                        hintText: '4.5',
                        controller: _halfDayHoursCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Geofence & Salary Cycle Options
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: _allowOutOfFence,
                            activeThumbColor: AppColors.neonCyan,
                            onChanged: (v) => setState(() => _allowOutOfFence = v),
                          ),
                          const SizedBox(width: 6),
                          Text('Allow Out-of-Fence Punch (With Warning)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: _strictGeofence,
                            activeThumbColor: const Color(0xFFEF4444),
                            onChanged: (v) => setState(() => _strictGeofence = v),
                          ),
                          const SizedBox(width: 6),
                          Text('Strict Block if Outside Fence', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Card 2: Dynamic Company Rules List ─────────────────────────────
          GlassCard(
            blur: 18,
            opacity: 0.12,
            borderRadius: BorderRadius.circular(18),
            borderColor: AppColors.glassBorder,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: AppColors.cyanGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.gavel_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Company Rules & Deduction Engine (${rules.length})',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                            ),
                            Text('Automated late penalties, working hour thresholds & LOP calculations', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                    GradientPrimaryButton(
                      text: '+ Add Custom Rule',
                      icon: Icons.add_circle_outline_rounded,
                      gradient: AppColors.primaryGradient,
                      onPressed: () => _showAddEditRuleDialog(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 14),

                if (rules.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.rule_folder_rounded, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            'No custom company rules created yet.',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Click one of the Quick Presets above or tap "+ Add Custom Rule" to build your dynamic late and payroll rules.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rules.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final r = rules[i];
                      Color badgeColor = AppColors.neonCyan;
                      if (r.category == 'WORKING_HOURS') badgeColor = AppColors.neonViolet;
                      if (r.category == 'GEOFENCE') badgeColor = const Color(0xFFF59E0B);
                      if (r.category == 'DEDUCTION') badgeColor = const Color(0xFFEF4444);

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: r.isActive ? Colors.white.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: r.isActive ? AppColors.glassBorder : Colors.transparent),
                        ),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      r.category == 'LATE_ARRIVAL'
                                          ? Icons.alarm_rounded
                                          : r.category == 'WORKING_HOURS'
                                              ? Icons.hourglass_bottom_rounded
                                              : r.category == 'GEOFENCE'
                                                  ? Icons.share_location_rounded
                                                  : Icons.monetization_on_rounded,
                                      color: badgeColor,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(r.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                        const SizedBox(width: 8),
                                        AnimatedStatusBadge(
                                          label: r.categoryDisplay.isNotEmpty ? r.categoryDisplay : r.category,
                                          statusColor: badgeColor,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      r.humanReadableSummary,
                                      style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                    ),
                                    if (r.description.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(r.description, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Text(r.isActive ? 'Active' : 'Paused', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: r.isActive ? const Color(0xFF10B981) : Colors.grey)),
                                    Switch(
                                      value: r.isActive,
                                      activeThumbColor: const Color(0xFF10B981),
                                      onChanged: (v) {
                                        compProv.updateCompanyRule(r.id, {'is_active': v});
                                      },
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF475569)),
                                  tooltip: 'Edit Rule',
                                  onPressed: () => _showAddEditRuleDialog(r),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                  tooltip: 'Delete Rule',
                                  onPressed: () => _confirmDeleteRule(r),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _PresetButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}
