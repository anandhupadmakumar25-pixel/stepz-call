import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/animated_status_badge.dart';
import '../../providers/lead_provider.dart';
import '../../providers/employee_provider.dart';

class BulkAssignDialog extends StatefulWidget {
  final List<String> selectedLeadIds;

  const BulkAssignDialog({super.key, required this.selectedLeadIds});

  @override
  State<BulkAssignDialog> createState() => _BulkAssignDialogState();
}

class _BulkAssignDialogState extends State<BulkAssignDialog> {
  final Set<String> _selectedEmployeeIds = {};
  final String _method = 'EQUAL';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeProvider>().fetchEmployees();
    });
  }

  Future<void> _commitAssignment() async {
    if (_selectedEmployeeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one active employee.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final leadProvider = context.read<LeadProvider>();

    final allocations = _selectedEmployeeIds.map((empId) {
      return {'employee_id': empId};
    }).toList();

    final result = await leadProvider.bulkAssign(
      widget.selectedLeadIds,
      allocations,
      _method,
    );

    setState(() => _isSubmitting = false);

    if (result != null && mounted) {
      final assigned = result['assigned_count'] ?? 0;
      final blocked = result['blocked_count'] ?? 0;

      Navigator.of(context).pop();
      final blockedMsg = blocked > 0 ? ' ($blocked permanently blocked numbers skipped)' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('Assigned $assigned leads successfully!$blockedMsg')),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(leadProvider.errorMessage ?? 'Bulk assignment failed.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final empProvider = context.watch<EmployeeProvider>();
    final activeEmployees = empProvider.employees.where((e) => e['is_active'] == true).toList();
    final isMobile = ResponsiveLayout.isMobile(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: GlassCard(
          blur: 24,
          opacity: 0.2,
          borderRadius: BorderRadius.circular(24),
          padding: EdgeInsets.all(isMobile ? 18 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.neonViolet.withValues(alpha: 0.4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.assignment_ind_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bulk Lead Allocation',
                                style: GoogleFonts.inter(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                '${widget.selectedLeadIds.length} leads selected for distribution',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  DialogCloseButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Strategy Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.neonCyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Equal Round-Robin Distribution',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                          ),
                          Text(
                            _selectedEmployeeIds.isNotEmpty
                                ? '~${(widget.selectedLeadIds.length / _selectedEmployeeIds.length).ceil()} leads will be assigned per selected telecaller'
                                : 'Select telecallers below to view estimated distribution',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Select All / Telecallers Counter Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Select Telecallers (${_selectedEmployeeIds.length}/${activeEmployees.length})',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (_selectedEmployeeIds.length == activeEmployees.length) {
                          _selectedEmployeeIds.clear();
                        } else {
                          _selectedEmployeeIds.addAll(activeEmployees.map((e) => e['id'].toString()));
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Text(
                        _selectedEmployeeIds.length == activeEmployees.length ? 'Deselect All' : 'Select All',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.neonCyan),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Telecallers List
              Expanded(
                child: activeEmployees.isEmpty
                    ? Center(
                        child: Text(
                          'No active telecallers found in company.',
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: activeEmployees.length,
                          separatorBuilder: (_, __) => const Divider(color: Color(0xFFE2E8F0), height: 1),
                          itemBuilder: (context, index) {
                            final emp = activeEmployees[index];
                            final id = emp['id'].toString();
                            final isChecked = _selectedEmployeeIds.contains(id);
                            final name = emp['full_name'] ?? emp['username'] ?? 'User';
                            final email = emp['email'] ?? '';
                            final assignedLeads = emp['assigned_leads_count'] ?? 0;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (isChecked) {
                                    _selectedEmployeeIds.remove(id);
                                  } else {
                                    _selectedEmployeeIds.add(id);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isChecked ? AppColors.neonViolet.withValues(alpha: 0.12) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: isChecked,
                                      activeColor: AppColors.neonViolet,
                                      checkColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedEmployeeIds.add(id);
                                          } else {
                                            _selectedEmployeeIds.remove(id);
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        gradient: isChecked ? AppColors.primaryGradient : null,
                                        color: isChecked ? null : const Color(0xFFF1F5F9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: isChecked ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          Text(
                                            email,
                                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    AnimatedStatusBadge(
                                      label: '$assignedLeads Active',
                                      statusColor: isChecked ? AppColors.neonCyan : AppColors.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 18),
                padding: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0x33D4AF37), width: 1)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    GlassSecondaryButton(
                      text: 'Cancel',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    GradientPrimaryButton(
                      text: 'Assign (${_selectedEmployeeIds.length} Telecallers)',
                      icon: Icons.send_rounded,
                      gradient: AppColors.sunsetGradient,
                      isLoading: _isSubmitting,
                      onPressed: _selectedEmployeeIds.isNotEmpty ? _commitAssignment : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
