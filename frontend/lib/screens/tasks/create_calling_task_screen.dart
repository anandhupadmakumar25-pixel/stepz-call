import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/app_background.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/glass_text_field.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../routes/app_routes.dart';
import '../../providers/lead_provider.dart';
import '../../providers/employee_provider.dart';

class CreateCallingTaskScreen extends StatefulWidget {
  const CreateCallingTaskScreen({super.key});

  @override
  State<CreateCallingTaskScreen> createState() => _CreateCallingTaskScreenState();
}

class _CreateCallingTaskScreenState extends State<CreateCallingTaskScreen> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  String? _selectedBranchId;
  String? _selectedCategoryId;
  String? _selectedEmployeeId;
  String _priority = 'MEDIUM';

  final Set<String> _selectedLeadIds = {};
  String _leadSearchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final leadP = context.read<LeadProvider>();
      leadP.fetchBranches();
      leadP.fetchCategories();
      leadP.fetchLeads(status: 'UNASSIGNED');
      final empP = context.read<EmployeeProvider>();
      empP.fetchEmployees().then((_) {
        if (empP.employees.isNotEmpty && _selectedEmployeeId == null && mounted) {
          setState(() {
            _selectedEmployeeId = empP.employees.first['id']?.toString();
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    context.read<LeadProvider>().fetchLeads(
      status: 'UNASSIGNED',
      branchId: _selectedBranchId,
      categoryId: _selectedCategoryId,
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF2563EB);
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return const Color(0xFF2563EB);
  }

  Future<void> _submitTask() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title'), backgroundColor: AppColors.danger),
      );
      return;
    }
    if (_selectedEmployeeId == null || _selectedEmployeeId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an employee to assign this task to'), backgroundColor: AppColors.danger),
      );
      return;
    }
    if (_selectedLeadIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 lead number to assign'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final leadProvider = context.read<LeadProvider>();
    final success = await leadProvider.createTask(
      title: title,
      description: _descCtrl.text.trim(),
      priority: _priority,
      branchId: _selectedBranchId,
      categoryId: _selectedCategoryId,
      assignedToId: _selectedEmployeeId,
      leadIds: _selectedLeadIds.toList(),
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calling Task created and leads dispatched!'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(leadProvider.errorMessage ?? 'Failed to create task'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadProvider = context.watch<LeadProvider>();
    final empProvider = context.watch<EmployeeProvider>();
    final isMobile = ResponsiveLayout.isMobile(context);

    final availableLeads = leadProvider.leads.where((l) {
      if (_leadSearchQuery.isEmpty) return true;
      final q = _leadSearchQuery.toLowerCase();
      return l.fullName.toLowerCase().contains(q) ||
          l.normalizedPhone.contains(q) ||
          l.city.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: AppBackground(
        preset: AppBackgroundPreset.pastelSky,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 14 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Nav Header
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppBackButton(fallbackRoute: AppRoutes.tasks),
                        const SizedBox(width: 14),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create Calling Task & Batch Assignment',
                                style: GoogleFonts.inter(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                              ),
                              Text(
                                'Assign verified leads to telecallers with instructions, branch, and category tagging',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    GradientPrimaryButton(
                      text: 'Assign (${_selectedLeadIds.length} Leads)',
                      icon: Icons.check_circle_rounded,
                      isLoading: leadProvider.isLoading,
                      onPressed: _selectedLeadIds.isEmpty ? null : _submitTask,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Section 1: Task Configuration
                GlassCard(
                  blur: 20,
                  opacity: 0.95,
                  borderRadius: BorderRadius.circular(20),
                  borderColor: const Color(0xFFE2E8F0),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.assignment_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Task Details & Scope',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      GlassTextField(
                        label: 'Task Title *',
                        hintText: 'e.g. Branch Alpha — Enterprise Cloud Migration Outreach',
                        controller: _titleCtrl,
                      ),
                      const SizedBox(height: 16),
                      GlassTextField(
                        label: 'Calling Pitch & Instructions',
                        hintText: 'e.g. Explain 20% early adopter promo, qualify user count, log feedback.',
                        controller: _descCtrl,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 18),

                      // Pickers Row
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          _buildDropdown(
                            label: 'Target Branch',
                            value: _selectedBranchId,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('No Branch (Global)')),
                              ...leadProvider.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                            ],
                            onChanged: (v) {
                              setState(() => _selectedBranchId = v);
                              _onFilterChanged();
                            },
                          ),
                          _buildDropdown(
                            label: 'Lead Category',
                            value: _selectedCategoryId,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('No Category (All)')),
                              ...leadProvider.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                            ],
                            onChanged: (v) {
                              setState(() => _selectedCategoryId = v);
                              _onFilterChanged();
                            },
                          ),
                          _buildDropdown(
                            label: 'Assign to Employee',
                            value: _selectedEmployeeId,
                            items: empProvider.employees.isEmpty
                                ? [const DropdownMenuItem(value: null, child: Text('No employees found'))]
                                : empProvider.employees.map((e) {
                                    final id = e['id']?.toString() ?? '';
                                    final name = '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'.trim();
                                    return DropdownMenuItem(value: id, child: Text(name.isNotEmpty ? name : (e['email'] ?? 'Employee')));
                                  }).toList(),
                            onChanged: (v) => setState(() => _selectedEmployeeId = v?.toString()),
                          ),
                          _buildDropdown(
                            label: 'Task Priority',
                            value: _priority,
                            items: const [
                              DropdownMenuItem(value: 'LOW', child: Text('Low Priority')),
                              DropdownMenuItem(value: 'MEDIUM', child: Text('Medium Priority')),
                              DropdownMenuItem(value: 'HIGH', child: Text('High Priority')),
                              DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                            ],
                            onChanged: (v) => setState(() => _priority = v ?? 'MEDIUM'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Section 2: Lead Selection Matrix
                GlassCard(
                  blur: 20,
                  opacity: 0.95,
                  borderRadius: BorderRadius.circular(20),
                  borderColor: const Color(0xFFE2E8F0),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: AppColors.cyanGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.playlist_add_check_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Select Leads for this Task',
                                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      '${_selectedLeadIds.length} of ${availableLeads.length} leads selected',
                                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF2563EB), fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              GlassSecondaryButton(
                                text: 'Select All (${availableLeads.length})',
                                icon: Icons.done_all_rounded,
                                onPressed: () {
                                  setState(() {
                                    for (var l in availableLeads) {
                                      _selectedLeadIds.add(l.id);
                                    }
                                  });
                                },
                              ),
                              GlassSecondaryButton(
                                text: 'Deselect All',
                                icon: Icons.clear_rounded,
                                onPressed: () => setState(() => _selectedLeadIds.clear()),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Search inside available leads
                      GlassTextField(
                        label: '',
                        hintText: 'Search leads by name, phone number, or city...',
                        controller: _searchCtrl,
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF2563EB)),
                        onChanged: (v) => setState(() => _leadSearchQuery = v.trim()),
                      ),
                      const SizedBox(height: 16),

                      // Leads list
                      if (availableLeads.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'No unassigned leads found matching current filters.',
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: availableLeads.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final lead = availableLeads[i];
                            final isSelected = _selectedLeadIds.contains(lead.id);

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedLeadIds.remove(lead.id);
                                  } else {
                                    _selectedLeadIds.add(lead.id);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.08) : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                                      activeColor: const Color(0xFF2563EB),
                                      checkColor: Colors.white,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedLeadIds.add(lead.id);
                                          } else {
                                            _selectedLeadIds.remove(lead.id);
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            lead.fullName,
                                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF0F172A)),
                                          ),
                                          Row(
                                            children: [
                                              const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF2563EB)),
                                              const SizedBox(width: 4),
                                              Text(
                                                lead.normalizedPhone,
                                                style: GoogleFonts.robotoMono(fontSize: 12, color: const Color(0xFF2563EB), fontWeight: FontWeight.w600),
                                              ),
                                              if (lead.city.isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    '• ${lead.city}',
                                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (lead.categoryName != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _parseColor(lead.categoryColor).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: _parseColor(lead.categoryColor).withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          lead.categoryName!,
                                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _parseColor(lead.categoryColor)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required dynamic value,
    required List<DropdownMenuItem<dynamic>> items,
    required ValueChanged<dynamic> onChanged,
  }) {
    final hasMatchingItem = items.any((item) => item.value == value);
    final safeValue = hasMatchingItem ? value : (items.isNotEmpty ? items.first.value : null);

    final isMobile = ResponsiveLayout.isMobile(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
        const SizedBox(height: 6),
        Container(
          width: isMobile ? double.infinity : 220,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<dynamic>(
              isExpanded: true,
              value: safeValue,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
