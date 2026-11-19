import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../models/lead_model.dart';
import '../../providers/employee_provider.dart';
import '../../providers/lead_provider.dart';

class ReassignLeadsDialog extends StatefulWidget {
  final List<LeadModel> assignedLeads;

  const ReassignLeadsDialog({super.key, required this.assignedLeads});

  @override
  State<ReassignLeadsDialog> createState() => _ReassignLeadsDialogState();
}

class _ReassignLeadsDialogState extends State<ReassignLeadsDialog> {
  String? _selectedEmployeeId;
  final TextEditingController _notesCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeProvider>().fetchEmployees();
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _commitReassign() async {
    if (_selectedEmployeeId == null || _selectedEmployeeId!.isEmpty) {
      setState(() => _errorMessage = 'Please select a target employee to reassign to.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final leadProvider = context.read<LeadProvider>();
    final res = await leadProvider.reassignLeads(
      leadIds: widget.assignedLeads.map((l) => l.id).toList(),
      targetEmployeeId: _selectedEmployeeId!,
      notes: _notesCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res != null) {
      final count = res['reassigned_count'] ?? 0;
      final skipped = res['skipped_same_employee'] ?? 0;
      final targetName = res['target_employee_name'] ?? 'new employee';
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reassigned $count lead${count == 1 ? "" : "s"} to $targetName'
            '${skipped > 0 ? " ($skipped already with this employee)" : ""}.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _errorMessage = leadProvider.errorMessage ?? 'Failed to reassign leads.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final empProvider = context.watch<EmployeeProvider>();
    final currentOwnerIds = widget.assignedLeads
        .map((l) => l.assignedTo?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final activeEmployees = empProvider.employees
        .where((e) =>
            e['is_active'] == true &&
            !currentOwnerIds.contains(e['id']?.toString() ?? ''))
        .toList();
    final isMobile = ResponsiveLayout.isMobile(context);

    final currentOwners = widget.assignedLeads
        .map((l) => l.assignedToName ?? '')
        .where((n) => n.isNotEmpty)
        .toSet()
        .join(', ');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 24,
        vertical: 20,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: GlassCard(
          blur: 24,
          opacity: 0.96,
          borderRadius: BorderRadius.circular(20),
          padding: EdgeInsets.all(isMobile ? 16 : 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: const Icon(Icons.swap_horiz_rounded,
                        color: Color(0xFF4338CA), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reassign Leads (${widget.assignedLeads.length})',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Transfer assigned leads exclusively to another employee (no duplicate assignment).',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  DialogCloseButton(onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 12),
              if (currentOwners.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'Currently assigned to: $currentOwners',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFDC2626)),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Select New Staff Owner *',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: activeEmployees.isEmpty
                    ? Center(
                        child: Text(
                          'No other active employees available to reassign to.',
                          style: GoogleFonts.inter(
                              fontSize: 12.5, color: const Color(0xFF64748B)),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(6),
                          itemCount: activeEmployees.length,
                          separatorBuilder: (_, __) => const Divider(
                              color: Color(0xFFE2E8F0), height: 1),
                          itemBuilder: (ctx, i) {
                            final emp = activeEmployees[i];
                            final id = emp['id'].toString();
                            final name =
                                emp['full_name'] ?? emp['username'] ?? 'Staff';
                            final email = emp['email'] ?? '';
                            final count = emp['assigned_leads_count'] ?? 0;
                            final isSelected = _selectedEmployeeId == id;

                            return InkWell(
                              onTap: () =>
                                  setState(() => _selectedEmployeeId = id),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFEEF2FF)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.radio_button_checked_rounded
                                          : Icons.radio_button_off_rounded,
                                      size: 18,
                                      color: isSelected
                                          ? const Color(0xFF4338CA)
                                          : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(name,
                                              style: GoogleFonts.inter(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      const Color(0xFF0F172A))),
                                          if (email.isNotEmpty)
                                            Text(email,
                                                style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    color: const Color(
                                                        0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                    Text('$count leads',
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                style: GoogleFonts.inter(fontSize: 12.5),
                decoration: InputDecoration(
                  labelText: 'Reassignment Note (Optional)',
                  hintText: 'Reason for transferring lead...',
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GlassSecondaryButton(
                    text: 'Cancel',
                    onPressed:
                        _isSubmitting ? null : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  GradientPrimaryButton(
                    text: _isSubmitting ? 'Reassigning...' : 'Confirm Reassign',
                    icon: Icons.swap_horiz_rounded,
                    height: 38,
                    onPressed: _isSubmitting ? null : _commitReassign,
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

