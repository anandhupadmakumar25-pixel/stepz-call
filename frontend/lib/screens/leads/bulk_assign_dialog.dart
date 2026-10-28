import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
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
        const SnackBar(content: Text('Please select at least one active employee.')),
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
          content: Text('Assigned $assigned leads successfully!$blockedMsg'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(leadProvider.errorMessage ?? 'Bulk assignment failed.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final empProvider = context.watch<EmployeeProvider>();
    final activeEmployees = empProvider.employees.where((e) => e['is_active'] == true).toList();

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accentVioletLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.assignment_ind_outlined, color: AppColors.accentViolet, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bulk Lead Assignment', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                          Text('${widget.selectedLeadIds.length} leads selected for allocation', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),

              Text('Distribution Mode', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: AppColors.accentViolet),
                    const SizedBox(width: 8),
                    Text('Equal Distribution (Even split across selected telecallers)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Text('Select Target Telecallers', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),

              Expanded(
                child: activeEmployees.isEmpty
                    ? Center(
                        child: Text(
                          'No active telecallers found in company.',
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: activeEmployees.length,
                        itemBuilder: (context, index) {
                          final emp = activeEmployees[index];
                          final id = emp['id']?.toString() ?? '';
                          final isSelected = _selectedEmployeeIds.contains(id);

                          return CheckboxListTile(
                            title: Text(emp['full_name'] ?? emp['email'], style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                            subtitle: Text('Current assigned: ${emp['assigned_leads_count'] ?? 0} leads', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                            value: isSelected,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedEmployeeIds.add(id);
                                } else {
                                  _selectedEmployeeIds.remove(id);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),

              const Divider(height: 20),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(
                    _selectedEmployeeIds.isNotEmpty
                        ? '~${(widget.selectedLeadIds.length / _selectedEmployeeIds.length).ceil()} leads per telecaller'
                        : 'Select at least 1 telecaller',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentViolet),
                  ),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _commitAssignment,
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Confirm Assignment'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
