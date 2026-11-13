import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/company_model.dart';
import '../../models/plan_model.dart';
import '../../providers/company_provider.dart';

class RenewPlanDialog extends StatefulWidget {
  final CompanyModel company;

  const RenewPlanDialog({
    super.key,
    required this.company,
  });

  @override
  State<RenewPlanDialog> createState() => _RenewPlanDialogState();
}

class _RenewPlanDialogState extends State<RenewPlanDialog> {
  int _selectedPresetDays = 30;
  String _selectedBillingCycle = 'MONTHLY';
  DateTime? _customExpiryDate;
  String? _selectedPlanId;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _presets = [
    {
      'label': '1 Month',
      'sublabel': '+30 Days',
      'cycle': 'MONTHLY',
      'days': 30,
      'icon': Icons.calendar_view_month_rounded,
    },
    {
      'label': '3 Months',
      'sublabel': '+90 Days (Quarterly)',
      'cycle': 'QUARTERLY',
      'days': 90,
      'icon': Icons.date_range_rounded,
    },
    {
      'label': '6 Months',
      'sublabel': '+180 Days (Half-Yearly)',
      'cycle': 'CUSTOM',
      'days': 180,
      'icon': Icons.event_repeat_rounded,
    },
    {
      'label': '1 Year',
      'sublabel': '+365 Days (Annual)',
      'cycle': 'YEARLY',
      'days': 365,
      'icon': Icons.verified_rounded,
    },
    {
      'label': 'Custom Date',
      'sublabel': 'Pick explicit end date',
      'cycle': 'CUSTOM',
      'days': 0,
      'icon': Icons.edit_calendar_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedPlanId = widget.company.planId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<CompanyProvider>();
      if (prov.plans.isEmpty) {
        prov.fetchPlans();
      }
    });
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    DateTime calculatedInitial = now.add(const Duration(days: 30));
    if (widget.company.planExpiresAt != null) {
      final parsed = DateTime.tryParse(widget.company.planExpiresAt!);
      if (parsed != null && parsed.isAfter(now)) {
        calculatedInitial = parsed.add(const Duration(days: 30));
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: calculatedInitial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() {
        _customExpiryDate = picked;
        _selectedPresetDays = 0;
        _selectedBillingCycle = 'CUSTOM';
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final companyProvider = context.read<CompanyProvider>();

    String? customIso;
    if (_selectedPresetDays == 0 && _customExpiryDate != null) {
      customIso = _customExpiryDate!.toIso8601String();
    }

    final success = await companyProvider.renewCompanyPlan(
      widget.company.id,
      billingCycle: _selectedBillingCycle,
      extensionDays: _selectedPresetDays > 0 ? _selectedPresetDays : 30,
      planId: _selectedPlanId,
      newExpiresAt: customIso,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                'Plan extended successfully for ${widget.company.name}!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  companyProvider.errorMessage ?? 'Failed to renew plan. Please try again.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyProvider = context.watch<CompanyProvider>();
    final plans = companyProvider.plans;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        color: Color(0xFF4F46E5),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Extend Subscription Plan',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.company.name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            // Content Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Status Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CURRENT PLAN',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.company.planName,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 32,
                            width: 1,
                            color: const Color(0xFFE2E8F0),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CURRENT EXPIRY',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      widget.company.isPlanOverdue
                                          ? Icons.error_rounded
                                          : Icons.event_available_rounded,
                                      size: 15,
                                      color: widget.company.isPlanOverdue
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF059669),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.company.expiryFormatted,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: widget.company.isPlanOverdue
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Extension Duration Presets
                    Text(
                      'Select Extension Duration',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 10),

                    ..._presets.map((preset) {
                      final isSelected = (_selectedPresetDays == preset['days'] &&
                          (_selectedPresetDays != 0 || _customExpiryDate != null));
                      final isCustom = preset['days'] == 0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            if (isCustom) {
                              _pickCustomDate();
                            } else {
                              setState(() {
                                _selectedPresetDays = preset['days'] as int;
                                _selectedBillingCycle = preset['cycle'] as String;
                                _customExpiryDate = null;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                                width: isSelected ? 1.6 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  preset['icon'] as IconData,
                                  size: 20,
                                  color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        preset['label'] as String,
                                        style: GoogleFonts.inter(
                                          fontSize: 13.5,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                          color: isSelected ? const Color(0xFF1E1B4B) : const Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        isCustom && _customExpiryDate != null
                                            ? 'Expires on: ${_customExpiryDate!.day.toString().padLeft(2, '0')}/${_customExpiryDate!.month.toString().padLeft(2, '0')}/${_customExpiryDate!.year}'
                                            : preset['sublabel'] as String,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: isSelected ? const Color(0xFF4338CA) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                  color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 14),

                    // Optional Plan Tier Upgrade/Change
                    if (plans.isNotEmpty) ...[
                      Text(
                        'Subscription Plan Tier',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final Map<String, PlanModel> uniqueMap = {};
                          for (final p in plans) {
                            if (p.id.isNotEmpty && !uniqueMap.containsKey(p.id)) {
                              uniqueMap[p.id] = p;
                            }
                          }
                          final uniqueList = uniqueMap.values.toList();
                          final effectiveValue = uniqueList.any((p) => p.id == _selectedPlanId)
                              ? _selectedPlanId
                              : (uniqueList.isNotEmpty ? uniqueList.first.id : null);

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: effectiveValue,
                                isExpanded: true,
                                items: uniqueList.map((p) {
                                  return DropdownMenuItem<String>(
                                    value: p.id,
                                    child: Text(
                                      '${p.name} (${p.currencySymbol}${p.priceMonthly.toStringAsFixed(0)}/mo)',
                                      style: GoogleFonts.inter(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedPlanId = val);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Modal Footer Buttons
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      foregroundColor: const Color(0xFF64748B),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bolt_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Activate & Extend Plan',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
