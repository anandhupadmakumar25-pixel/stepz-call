import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lead_provider.dart';
import '../../providers/employee_provider.dart';
import '../../models/lead_model.dart';
import '../leads/lead_detail_screen.dart';

class CallingTasksScreen extends StatefulWidget {
  const CallingTasksScreen({super.key});

  @override
  State<CallingTasksScreen> createState() => _CallingTasksScreenState();
}

class _CallingTasksScreenState extends State<CallingTasksScreen> {
  String _selectedBranch = 'ALL';
  String _selectedCategory = 'ALL';
  String _selectedStatus = 'ALL';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final leadProvider = context.read<LeadProvider>();
    leadProvider.fetchBranches();
    leadProvider.fetchCategories();
    leadProvider.fetchTasks(
      branchId: _selectedBranch,
      categoryId: _selectedCategory,
      status: _selectedStatus,
      search: _searchQuery,
    );
    context.read<EmployeeProvider>().fetchEmployees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateTaskDialog() {
    final leadProvider = context.read<LeadProvider>();
    final empProvider = context.read<EmployeeProvider>();

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final countCtrl = TextEditingController(text: '20');
    String? selectedBranchId;
    String? selectedCategoryId;
    String? selectedEmployeeId;
    String priority = 'MEDIUM';
    DateTime? dueDate;

    if (empProvider.employees.isNotEmpty) {
      selectedEmployeeId = empProvider.employees.first['id']?.toString();
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentVioletLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.assignment_outlined, color: AppColors.accentViolet, size: 20),
              ),
              const SizedBox(width: 10),
              Text('Create Calling Task', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Task Title *',
                      hintText: 'e.g. Branch X - Academy Admissions Calling',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Calling Instructions / Script Pitch',
                      hintText: 'e.g. Pitch 15% weekend discount; follow up on enquiry form',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: selectedBranchId,
                          decoration: const InputDecoration(labelText: 'Branch (Target)'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Global (Any Branch)')),
                            ...leadProvider.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                          ],
                          onChanged: (val) => setDlgState(() => selectedBranchId = val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: selectedCategoryId,
                          decoration: const InputDecoration(labelText: 'Category (Target)'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Categories')),
                            ...leadProvider.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                          ],
                          onChanged: (val) => setDlgState(() => selectedCategoryId = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: selectedEmployeeId,
                          decoration: const InputDecoration(labelText: 'Assign To Employee *'),
                          items: empProvider.employees.map((e) {
                            final name = e['full_name'] ?? e['email'];
                            final branch = e['branch_name'] != null ? ' (${e['branch_name']})' : '';
                            return DropdownMenuItem<String?>(
                              value: e['id']?.toString(),
                              child: Text('$name$branch', maxLines: 1, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) => setDlgState(() => selectedEmployeeId = val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: priority,
                          decoration: const InputDecoration(labelText: 'Priority'),
                          items: const [
                            DropdownMenuItem(value: 'LOW', child: Text('Low')),
                            DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                            DropdownMenuItem(value: 'HIGH', child: Text('High')),
                            DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                          ],
                          onChanged: (val) => setDlgState(() => priority = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: countCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Number of Unassigned Leads',
                            hintText: 'e.g. 25',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().add(const Duration(days: 3)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDlgState(() => dueDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(dueDate == null
                              ? 'Target Due Date'
                              : '${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || selectedEmployeeId == null) {
                  return;
                }
                final nav = Navigator.of(ctx);
                final scaf = ScaffoldMessenger.of(context);
                final ok = await leadProvider.createTask({
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'branch_id': selectedBranchId,
                  'category_id': selectedCategoryId,
                  'assigned_to_id': selectedEmployeeId,
                  'priority': priority,
                  'due_date': dueDate != null ? '${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}' : null,
                  'lead_count': int.tryParse(countCtrl.text) ?? 0,
                });
                if (ok) {
                  nav.pop();
                  scaf.showSnackBar(
                    const SnackBar(content: Text('Calling Task created & leads assigned!'), backgroundColor: AppColors.success),
                  );
                }
              },
              child: const Text('Create & Assign Task'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskLeadsDialog(CallingTaskModel task) async {
    final leadProvider = context.read<LeadProvider>();
    await leadProvider.fetchTaskDetail(task.id);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Consumer<LeadProvider>(
        builder: (context, provider, _) {
          final leads = provider.taskLeads;
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(
                        'Assigned to: ${task.assignedToName ?? 'Telecaller'} • ${leads.length} Leads',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700, maxHeight: 500),
              child: leads.isEmpty
                  ? Center(
                      child: Text(
                        'No leads currently attached to this task.',
                        style: GoogleFonts.inter(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: leads.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final lead = leads[idx];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          title: Text(lead.fullName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text('${lead.normalizedPhone} • ${lead.city.isNotEmpty ? lead.city : 'No City'}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(lead.status).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(lead.status, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _getStatusColor(lead.status))),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.phone_in_talk, color: AppColors.success, size: 20),
                                tooltip: 'Open Lead & Call',
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => LeadDetailScreen(leadId: lead.id)),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'COMPLETED':
      case 'QUALIFIED':
        return AppColors.success;
      case 'IN_PROGRESS':
        return AppColors.info;
      case 'NOT_INTERESTED':
      case 'BLOCKED':
        return AppColors.danger;
      default:
        return AppColors.accentViolet;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'URGENT':
        return AppColors.danger;
      case 'HIGH':
        return AppColors.warning;
      case 'LOW':
        return AppColors.textSecondary;
      default:
        return AppColors.info;
    }
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
    final auth = context.watch<AuthProvider>();
    final leadProvider = context.watch<LeadProvider>();
    final isTelecaller = auth.currentUser?.isEmployee ?? true;
    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTelecaller ? 'My Calling Tasks' : 'Calling Tasks & Assignments',
                        style: GoogleFonts.inter(fontSize: isMobile ? 16 : 20, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isTelecaller
                            ? 'Your assigned calling tasks, targets, and progress'
                            : 'Organize leads into actionable calling tasks with target branches, categories, and deadlines',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!isTelecaller)
                  ElevatedButton.icon(
                    onPressed: _showCreateTaskDialog,
                    icon: const Icon(Icons.add_task, size: 16),
                    label: const Text('Create Task'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentViolet,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Toolbar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isMobile ? double.infinity : 200,
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search tasks...',
                        prefixIcon: const Icon(Icons.search, size: 16),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                        isDense: true,
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                  _loadData();
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim());
                        _loadData();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    height: 38,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedBranch,
                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: [
                        const DropdownMenuItem(value: 'ALL', child: Text('All Branches')),
                        ...leadProvider.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedBranch = v ?? 'ALL');
                        _loadData();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    height: 38,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: [
                        const DropdownMenuItem(value: 'ALL', child: Text('All Categories')),
                        ...leadProvider.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedCategory = v ?? 'ALL');
                        _loadData();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    height: 38,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                        DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress')),
                        DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedStatus = v ?? 'ALL');
                        _loadData();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tasks List
            Expanded(
              child: leadProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : leadProvider.tasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.assignment_turned_in_outlined, size: 48, color: AppColors.textSecondary),
                              const SizedBox(height: 12),
                              Text('No calling tasks found', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                isTelecaller
                                    ? 'No tasks assigned to you currently.'
                                    : 'Click "Create Task" above to assign leads as a structured calling batch.',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: leadProvider.tasks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final task = leadProvider.tasks[i];
                            return _buildTaskCard(task, isTelecaller);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(CallingTaskModel task, bool isTelecaller) {
    final catColor = _parseColor(task.categoryColor);
    final priColor = _getPriorityColor(task.priority);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(task.title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: priColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            task.priority,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: priColor),
                          ),
                        ),
                      ],
                    ),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (val) async {
                  if (val == 'IN_PROGRESS' || val == 'COMPLETED' || val == 'PENDING') {
                    await context.read<LeadProvider>().updateTaskStatus(task.id, val);
                  } else if (val == 'DELETE') {
                    await context.read<LeadProvider>().deleteTask(task.id);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'IN_PROGRESS', child: Text('Mark In Progress')),
                  const PopupMenuItem(value: 'COMPLETED', child: Text('Mark Completed')),
                  if (!isTelecaller)
                    const PopupMenuItem(value: 'DELETE', child: Text('Cancel Task', style: TextStyle(color: AppColors.danger))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Badges Row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (task.branchName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storefront, size: 12, color: AppColors.accentViolet),
                      const SizedBox(width: 4),
                      Text(task.branchName!, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              if (task.categoryName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task.categoryName!,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: catColor),
                  ),
                ),
              if (task.assignedToName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('Assigned: ${task.assignedToName!}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              if (task.dueDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_outlined, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('Due: ${task.dueDate}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${task.completedLeadsCount} of ${task.totalLeadsCount} leads completed (${task.progressPercent}%)',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showTaskLeadsDialog(task),
                    icon: const Icon(Icons.phone_in_talk, size: 14),
                    label: Text(isTelecaller ? 'Start Calling' : 'View Task Leads'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: task.totalLeadsCount > 0 ? (task.completedLeadsCount / task.totalLeadsCount) : 0,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    task.progressPercent == 100 ? AppColors.success : AppColors.accentViolet,
                  ),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
