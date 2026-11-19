import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/glass/app_background.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/glass_text_field.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../providers/employee_provider.dart';
import '../../providers/lead_provider.dart';
import '../../routes/app_routes.dart';

class CreateCallingTaskScreen extends StatefulWidget {
  const CreateCallingTaskScreen({super.key});

  @override
  State<CreateCallingTaskScreen> createState() =>
      _CreateCallingTaskScreenState();
}

class _CreateCallingTaskScreenState extends State<CreateCallingTaskScreen> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  String? _selectedEmployeeId;
  String? _selectedBranchId;
  String _taskType = 'GENERAL';
  String _priority = 'MEDIUM';
  DateTime? _dueDate;

  final Set<String> _selectedLeadIds = {};
  String _leadSearchQuery = '';

  static const List<Map<String, String>> _taskTypes = [
    {'value': 'GENERAL', 'label': 'General Task'},
    {'value': 'CALLING', 'label': 'Calling / Outreach'},
    {'value': 'FIELD_VISIT', 'label': 'Field Visit'},
    {'value': 'FOLLOW_UP', 'label': 'Follow-Up'},
    {'value': 'SUPPORT', 'label': 'Customer Support'},
    {'value': 'ADMIN_WORK', 'label': 'Admin / Backoffice'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final leadP = context.read<LeadProvider>();
      leadP.fetchBranches();
      leadP.fetchLeads(status: 'UNASSIGNED');
      final empP = context.read<EmployeeProvider>();
      empP.fetchEmployees().then((_) {
        if (empP.employees.isNotEmpty &&
            _selectedEmployeeId == null &&
            mounted) {
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

  String _roleLabelOf(Map<String, dynamic> emp) {
    final customRole = (emp['custom_role_name'] ?? '').toString().trim();
    if (customRole.isNotEmpty) return customRole;
    final roleName = (emp['role_name'] ?? '').toString().trim();
    if (roleName.isNotEmpty) return roleName;
    return (emp['role'] ?? 'EMPLOYEE').toString();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submitTask() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a task title'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    if (_selectedEmployeeId == null || _selectedEmployeeId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an employee to assign this task to'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final empList = context.read<EmployeeProvider>().employees;
    final selectedEmp = empList.cast<Map<String, dynamic>?>().firstWhere(
          (e) => e?['id']?.toString() == _selectedEmployeeId,
          orElse: () => null,
        );
    final resolvedRole =
        selectedEmp != null ? _roleLabelOf(selectedEmp) : '';

    final leadProvider = context.read<LeadProvider>();
    final success = await leadProvider.createTask(
      title: title,
      description: _descCtrl.text.trim(),
      taskType: _taskType,
      targetRole: resolvedRole,
      priority: _priority,
      branchId: _selectedBranchId,
      assignedToId: _selectedEmployeeId,
      dueDate:
          _dueDate != null ? DateFormat('yyyy-MM-dd').format(_dueDate!) : null,
      leadIds: _selectedLeadIds.toList(),
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee task assigned successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(leadProvider.errorMessage ?? 'Failed to assign task'),
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

    final activeEmployees =
        empProvider.employees.where((e) => e['is_active'] != false).toList();

    final effectiveEmployeeId = activeEmployees
            .any((e) => e['id']?.toString() == _selectedEmployeeId)
        ? _selectedEmployeeId
        : (activeEmployees.isNotEmpty
            ? activeEmployees.first['id']?.toString()
            : null);

    final availableLeads = leadProvider.leads.where((l) {
      if (_selectedBranchId != null &&
          l.branchId != null &&
          l.branchId != _selectedBranchId) {
        return false;
      }
      if (_leadSearchQuery.isEmpty) return true;
      final q = _leadSearchQuery.toLowerCase();
      return l.fullName.toLowerCase().contains(q) ||
          l.normalizedPhone.contains(q) ||
          l.city.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        preset: AppBackgroundPreset.cleanEnterprise,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    const AppBackButton(fallbackRoute: AppRoutes.tasks),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assign Employee Task',
                            style: GoogleFonts.inter(
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Assign tasks to employees across any role, set due dates, and collect completion reports',
                            style: GoogleFonts.inter(
                                fontSize: 11.5, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Task Assignment Form Card
                        GlassCard(
                          padding: EdgeInsets.all(isMobile ? 14 : 20),
                          borderRadius: BorderRadius.circular(18),
                          borderColor: const Color(0xFFE2E8F0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GlassTextField(
                                label: 'Task Title *',
                                hintText:
                                    'e.g. Follow up with pending clients / Verify branch documents',
                                controller: _titleCtrl,
                              ),
                              const SizedBox(height: 12),

                              // Employee Selection
                              _buildDropdown<String?>(
                                label: 'Assign to Employee *',
                                value: effectiveEmployeeId,
                                items: activeEmployees.isEmpty
                                    ? [
                                        const DropdownMenuItem(
                                          value: null,
                                          child: Text('No active employees'),
                                        )
                                      ]
                                    : activeEmployees.map((e) {
                                        final id = e['id']?.toString();
                                        final name =
                                            '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'
                                                .trim();
                                        final disp = name.isNotEmpty
                                            ? name
                                            : (e['email']?.toString() ??
                                                'Employee');
                                        final role = _roleLabelOf(
                                            Map<String, dynamic>.from(e));
                                        return DropdownMenuItem(
                                          value: id,
                                          child: Text(
                                            '$disp ($role)',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedEmployeeId = v),
                              ),
                              const SizedBox(height: 12),

                              // Task Type, Priority, Branch, Due Date
                              LayoutBuilder(
                                builder: (ctx, c) {
                                  final typeDrop = _buildDropdown<String>(
                                    label: 'Task Type',
                                    value: _taskType,
                                    items: _taskTypes
                                        .map((t) => DropdownMenuItem(
                                              value: t['value'],
                                              child: Text(t['label']!),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(
                                        () => _taskType = v ?? 'GENERAL'),
                                  );

                                  final priorityDrop = _buildDropdown<String>(
                                    label: 'Priority',
                                    value: _priority,
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'LOW', child: Text('Low')),
                                      DropdownMenuItem(
                                          value: 'MEDIUM',
                                          child: Text('Medium')),
                                      DropdownMenuItem(
                                          value: 'HIGH', child: Text('High')),
                                      DropdownMenuItem(
                                          value: 'URGENT',
                                          child: Text('Urgent')),
                                    ],
                                    onChanged: (v) => setState(
                                        () => _priority = v ?? 'MEDIUM'),
                                  );

                                  final branchDrop = _buildDropdown<String?>(
                                    label: 'Branch (Optional)',
                                    value: _selectedBranchId,
                                    items: [
                                      const DropdownMenuItem(
                                          value: null,
                                          child: Text('All / Company-Wide')),
                                      ...leadProvider.branches.map((b) =>
                                          DropdownMenuItem(
                                              value: b.id,
                                              child: Text(b.name))),
                                    ],
                                    onChanged: (v) => setState(
                                        () => _selectedBranchId = v),
                                  );

                                  final duePicker = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Due Date',
                                        style: GoogleFonts.inter(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF475569)),
                                      ),
                                      const SizedBox(height: 5),
                                      InkWell(
                                        onTap: _pickDueDate,
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          height: 44,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color:
                                                    const Color(0xFFE2E8F0)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                  Icons.calendar_today_rounded,
                                                  size: 15,
                                                  color: Color(0xFF64748B)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _dueDate != null
                                                      ? DateFormat(
                                                              'dd MMM yyyy')
                                                          .format(_dueDate!)
                                                      : 'Select due date',
                                                  style: GoogleFonts.inter(
                                                      fontSize: 12.5,
                                                      color: _dueDate != null
                                                          ? const Color(
                                                              0xFF0F172A)
                                                          : const Color(
                                                              0xFF94A3B8)),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (_dueDate != null)
                                                GestureDetector(
                                                  onTap: () => setState(
                                                      () => _dueDate = null),
                                                  child: const Icon(
                                                      Icons.close_rounded,
                                                      size: 16,
                                                      color: Color(0xFF64748B)),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );

                                  if (c.maxWidth >= 760) {
                                    return Row(
                                      children: [
                                        Expanded(child: typeDrop),
                                        const SizedBox(width: 10),
                                        Expanded(child: priorityDrop),
                                        const SizedBox(width: 10),
                                        Expanded(child: branchDrop),
                                        const SizedBox(width: 10),
                                        Expanded(child: duePicker),
                                      ],
                                    );
                                  }
                                  return Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: typeDrop),
                                          const SizedBox(width: 10),
                                          Expanded(child: priorityDrop),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(child: branchDrop),
                                          const SizedBox(width: 10),
                                          Expanded(child: duePicker),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 12),

                              GlassTextField(
                                label: 'Instructions & Expected Report',
                                hintText:
                                    'Describe what the employee should complete and what to include in their report...',
                                controller: _descCtrl,
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Optional Leads Attachment Section (ExpansionTile)
                        GlassCard(
                          padding: EdgeInsets.zero,
                          borderRadius: BorderRadius.circular(16),
                          borderColor: const Color(0xFFE2E8F0),
                          child: Theme(
                            data: Theme.of(context)
                                .copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              childrenPadding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              title: Row(
                                children: [
                                  const Icon(Icons.contact_phone_outlined,
                                      size: 18, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Attach Unassigned Leads (Optional · ${_selectedLeadIds.length} selected)',
                                      style: GoogleFonts.inter(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0F172A)),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                'Optional for calling/follow-up tasks; skip for general/admin/field tasks',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B)),
                              ),
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 38,
                                        child: TextField(
                                          controller: _searchCtrl,
                                          onChanged: (v) => setState(
                                              () => _leadSearchQuery = v.trim()),
                                          style: GoogleFonts.inter(
                                              fontSize: 12.5),
                                          decoration: InputDecoration(
                                            hintText:
                                                'Search unassigned leads...',
                                            prefixIcon: const Icon(
                                                Icons.search_rounded,
                                                size: 17),
                                            filled: true,
                                            fillColor: const Color(0xFFF8FAFC),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 10),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                  color: Color(0xFFE2E8F0)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          if (_selectedLeadIds.length ==
                                              availableLeads.length) {
                                            _selectedLeadIds.clear();
                                          } else {
                                            _selectedLeadIds.addAll(
                                                availableLeads
                                                    .map((l) => l.id));
                                          }
                                        });
                                      },
                                      child: Text(
                                        _selectedLeadIds.length ==
                                                    availableLeads.length &&
                                                availableLeads.isNotEmpty
                                            ? 'Clear All'
                                            : 'Select All',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (availableLeads.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    child: Text(
                                      'No unassigned leads available.',
                                      style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: const Color(0xFF64748B)),
                                    ),
                                  )
                                else
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxHeight: 240),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: availableLeads.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(
                                              height: 1,
                                              color: Color(0xFFE2E8F0)),
                                      itemBuilder: (ctx, i) {
                                        final lead = availableLeads[i];
                                        final isSelected =
                                            _selectedLeadIds.contains(lead.id);
                                        return CheckboxListTile(
                                          dense: true,
                                          value: isSelected,
                                          activeColor: const Color(0xFF047857),
                                          onChanged: (checked) {
                                            setState(() {
                                              if (checked == true) {
                                                _selectedLeadIds.add(lead.id);
                                              } else {
                                                _selectedLeadIds
                                                    .remove(lead.id);
                                              }
                                            });
                                          },
                                          title: Text(
                                            lead.fullName,
                                            style: GoogleFonts.inter(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          subtitle: Text(
                                            '${lead.normalizedPhone}${lead.branchName != null ? " · ${lead.branchName}" : ""}',
                                            style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: const Color(0xFF64748B)),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Footer Submit Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GlassSecondaryButton(
                      text: 'Cancel',
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 10),
                    GradientPrimaryButton(
                      text: leadProvider.isLoading
                          ? 'Assigning...'
                          : 'Assign Task',
                      icon: Icons.send_rounded,
                      height: 40,
                      onPressed: leadProvider.isLoading ? null : _submitTask,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569)),
        ),
        const SizedBox(height: 5),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: Colors.white,
              style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.w500),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
