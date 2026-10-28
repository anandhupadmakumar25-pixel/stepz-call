import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/responsive/responsive_layout.dart';
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
  DateTime? _dueDate;

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
    if (hex == null || hex.isEmpty) return AppColors.accentViolet;
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return AppColors.accentViolet;
  }

  @override
  Widget build(BuildContext context) {
    final leadProvider = context.watch<LeadProvider>();
    final empProvider = context.watch<EmployeeProvider>();
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    // Filter available leads based on search query
    final availableLeads = leadProvider.leads.where((l) {
      if (_leadSearchQuery.isEmpty) return true;
      final q = _leadSearchQuery.toLowerCase();
      return l.fullName.toLowerCase().contains(q) ||
          l.normalizedPhone.contains(q) ||
          l.city.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Create Calling Task', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: leadProvider.isLoading || _selectedLeadIds.isEmpty
                  ? null
                  : _submitTask,
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: Text('Assign Task (${_selectedLeadIds.length} Leads)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentViolet,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1: Task Configuration
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accentVioletLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.assignment_outlined, color: AppColors.accentViolet, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text('Task Details & Assignment', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Title & Description
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Task Title *',
                      hintText: 'e.g. Branch X - Academy Admissions Calling',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Calling Instructions / Script Pitch',
                      hintText: 'e.g. Pitch course discount, check weekend batch preference, and log notes.',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),

                  // Branch, Category, Employee, Priority, Due Date in Responsive Grid
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: isDesktop ? 220 : double.infinity,
                        child: DropdownButtonFormField<String?>(
                          initialValue: _selectedBranchId,
                          decoration: const InputDecoration(
                            labelText: 'Filter Branch (Target)',
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Branches')),
                            ...leadProvider.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _selectedBranchId = v;
                              _selectedLeadIds.clear();
                            });
                            _onFilterChanged();
                          },
                        ),
                      ),
                      SizedBox(
                        width: isDesktop ? 220 : double.infinity,
                        child: DropdownButtonFormField<String?>(
                          initialValue: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Filter Category (Target)',
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Categories')),
                            ...leadProvider.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _selectedCategoryId = v;
                              _selectedLeadIds.clear();
                            });
                            _onFilterChanged();
                          },
                        ),
                      ),
                      SizedBox(
                        width: isDesktop ? 240 : double.infinity,
                        child: DropdownButtonFormField<String?>(
                          initialValue: _selectedEmployeeId,
                          decoration: const InputDecoration(
                            labelText: 'Assign To Employee *',
                            isDense: true,
                          ),
                          items: empProvider.employees.map((e) {
                            final name = e['full_name'] ?? e['email'];
                            final bName = e['branch_name'] != null ? ' (${e['branch_name']})' : '';
                            return DropdownMenuItem<String?>(
                              value: e['id']?.toString(),
                              child: Text('$name$bName', maxLines: 1, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedEmployeeId = v),
                        ),
                      ),
                      SizedBox(
                        width: isDesktop ? 160 : double.infinity,
                        child: DropdownButtonFormField<String>(
                          initialValue: _priority,
                          decoration: const InputDecoration(labelText: 'Priority', isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'LOW', child: Text('Low')),
                            DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                            DropdownMenuItem(value: 'HIGH', child: Text('High')),
                            DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                          ],
                          onChanged: (v) => setState(() => _priority = v!),
                        ),
                      ),
                      SizedBox(
                        width: isDesktop ? 180 : double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().add(const Duration(days: 3)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => _dueDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(_dueDate == null
                              ? 'Set Due Date'
                              : '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 2: Lead Selection Table
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Toolbar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Select Leads & Phone Numbers', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                            Text(
                              '${_selectedLeadIds.length} of ${availableLeads.length} leads selected for this task',
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                if (_selectedLeadIds.length == availableLeads.length) {
                                  _selectedLeadIds.clear();
                                } else {
                                  _selectedLeadIds.addAll(availableLeads.map((l) => l.id));
                                }
                              });
                            },
                            child: Text(_selectedLeadIds.length == availableLeads.length
                                ? 'Deselect All'
                                : 'Select All (${availableLeads.length})'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Search field
                  SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search by lead name, phone number, city...',
                        prefixIcon: const Icon(Icons.search, size: 16),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        suffixIcon: _leadSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _leadSearchQuery = '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) => setState(() => _leadSearchQuery = val.trim()),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Leads Table
                  if (availableLeads.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Text('No unassigned leads match the selected branch/category filters.', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                    )
                  else
                    Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 750),
                          child: DataTable(
                            headingRowHeight: 40,
                            dataRowMinHeight: 46,
                            dataRowMaxHeight: 52,
                            columns: const [
                              DataColumn(label: Text('SELECT')),
                              DataColumn(label: Text('NAME')),
                              DataColumn(label: Text('PHONE NUMBER')),
                              DataColumn(label: Text('BRANCH')),
                              DataColumn(label: Text('CATEGORY')),
                              DataColumn(label: Text('CITY')),
                            ],
                            rows: availableLeads.map((lead) {
                              final isSelected = _selectedLeadIds.contains(lead.id);
                              final catColor = _parseColor(lead.categoryColor);

                              return DataRow(
                                selected: isSelected,
                                onSelectChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedLeadIds.add(lead.id);
                                    } else {
                                      _selectedLeadIds.remove(lead.id);
                                    }
                                  });
                                },
                                cells: [
                                  DataCell(
                                    Checkbox(
                                      value: isSelected,
                                      activeColor: AppColors.accentViolet,
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
                                  ),
                                  DataCell(Text(lead.fullName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600))),
                                  DataCell(Text(lead.normalizedPhone, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                                  DataCell(Text(lead.branchName ?? '—', style: GoogleFonts.inter(fontSize: 12))),
                                  DataCell(
                                    lead.categoryName != null
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: catColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(lead.categoryName!, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: catColor)),
                                          )
                                        : const Text('—'),
                                  ),
                                  DataCell(Text(lead.city.isNotEmpty ? lead.city : '—', style: GoogleFonts.inter(fontSize: 12))),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
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

  void _submitTask() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title.'), backgroundColor: AppColors.danger),
      );
      return;
    }
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an employee to assign this task.'), backgroundColor: AppColors.danger),
      );
      return;
    }
    if (_selectedLeadIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 lead to assign.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final leadProvider = context.read<LeadProvider>();
    final nav = Navigator.of(context);
    final scaf = ScaffoldMessenger.of(context);

    final ok = await leadProvider.createTask({
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'branch_id': _selectedBranchId,
      'category_id': _selectedCategoryId,
      'assigned_to_id': _selectedEmployeeId,
      'priority': _priority,
      'due_date': _dueDate != null
          ? '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}'
          : null,
      'lead_ids': _selectedLeadIds.toList(),
    });

    if (ok) {
      scaf.showSnackBar(
        SnackBar(
          content: Text('Calling Task created with ${_selectedLeadIds.length} assigned leads!'),
          backgroundColor: AppColors.success,
        ),
      );
      nav.pop();
    }
  }
}
