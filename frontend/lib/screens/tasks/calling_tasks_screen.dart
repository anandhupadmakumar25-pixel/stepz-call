import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_scaffold.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/animated_status_badge.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lead_provider.dart';
import '../../providers/employee_provider.dart';
import '../../models/lead_model.dart';
import 'create_calling_task_screen.dart';
import 'task_detail_execution_screen.dart';

class CallingTasksScreen extends StatefulWidget {
  final String? initialEmployeeId;
  final String? employeeName;

  const CallingTasksScreen({super.key, this.initialEmployeeId, this.employeeName});

  @override
  State<CallingTasksScreen> createState() => _CallingTasksScreenState();
}

class _CallingTasksScreenState extends State<CallingTasksScreen> {
  String _selectedBranch = 'ALL';
  String _selectedCategory = 'ALL';
  String _selectedStatus = 'ALL';
  String? _selectedEmployeeId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedEmployeeId = widget.initialEmployeeId;
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
      assignedToId: _selectedEmployeeId,
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

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'URGENT':
        return AppColors.neonCoral;
      case 'HIGH':
        return AppColors.neonSunset;
      case 'LOW':
        return AppColors.textSecondary;
      default:
        return AppColors.neonCyan;
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.neonViolet;
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return AppColors.neonViolet;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final leadProvider = context.watch<LeadProvider>();
    final user = auth.currentUser;
    final isSuperAdmin = user?.isSuperAdmin ?? false;
    final canViewAll = isSuperAdmin || (user?.hasPermission('tasks.view_all') ?? false);
    final isTelecaller = (user?.isEmployee ?? true) && !canViewAll;
    final canCreateTask = isSuperAdmin || (user?.hasPermission('tasks.create') ?? false);
    final isMobile = ResponsiveLayout.isMobile(context);

    return GlassScaffold(
      backgroundImage: 'assets/images/telecaller_calling_bg.jpg',
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 12 : 24,
          isMobile ? 6 : 16,
          isMobile ? 12 : 24,
          isMobile ? 10 : 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            // Header with Back Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const AppBackButton(fallbackRoute: AppRoutes.dashboard),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    isTelecaller ? 'My Calling Tasks' : 'Calling Tasks & Assignments',
                                    style: GoogleFonts.inter(
                                      fontSize: isMobile ? 18 : 22,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                AnimatedStatusBadge(
                                  label: '${leadProvider.tasks.length} Batches',
                                  statusColor: const Color(0xFF2563EB),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isTelecaller
                                  ? 'Your assigned lead queues, live calling targets, and follow-ups'
                                  : 'Organize leads into actionable calling tasks with target branches, categories, and deadlines',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.employeeName != null && _selectedEmployeeId != null) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF93C5FD)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.person_rounded, size: 14, color: Color(0xFF1D4ED8)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Filtered by Staff: ${widget.employeeName}',
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () {
                                        setState(() => _selectedEmployeeId = null);
                                        _loadData();
                                      },
                                      child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF1D4ED8)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (canCreateTask) ...[
                  const SizedBox(width: 12),
                  GradientPrimaryButton(
                    text: 'Create Task',
                    icon: Icons.add_task_rounded,
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateCallingTaskScreen()),
                      );
                      _loadData();
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),

            // Frosted Glass Toolbar
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isMobile ? double.infinity : 220,
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Search tasks...',
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        isDense: true,
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14, color: Color(0xFF94A3B8)),
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
                  _buildDropdownFilter(
                    width: isMobile ? double.infinity : 160,
                    value: _selectedBranch,
                    items: [
                      const DropdownMenuItem(value: 'ALL', child: Text('All Branches')),
                      ...leadProvider.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedBranch = v ?? 'ALL');
                      _loadData();
                    },
                  ),
                  _buildDropdownFilter(
                    width: isMobile ? double.infinity : 160,
                    value: _selectedCategory,
                    items: [
                      const DropdownMenuItem(value: 'ALL', child: Text('All Categories')),
                      ...leadProvider.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedCategory = v ?? 'ALL');
                      _loadData();
                    },
                  ),
                  _buildDropdownFilter(
                    width: isMobile ? double.infinity : 150,
                    value: _selectedStatus,
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
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tasks List
            Expanded(
              child: leadProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : leadProvider.tasks.isEmpty
                      ? Center(
                          child: GlassCard(
                            blur: 16,
                            opacity: 0.12,
                            padding: const EdgeInsets.all(36),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.assignment_turned_in_rounded, size: 52, color: AppColors.neonCyan.withValues(alpha: 0.5)),
                                const SizedBox(height: 14),
                                Text(
                                  'No Calling Tasks Found',
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isTelecaller
                                      ? 'No tasks assigned to your queue currently.'
                                      : 'Click "Create Task" above to bundle leads into an active calling batch.',
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: leadProvider.tasks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final task = leadProvider.tasks[i];
                            return _buildTaskGlassCard(task, isTelecaller);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFilter({
    required double width,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      width: width,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTaskGlassCard(CallingTaskModel task, bool isTelecaller) {
    final catColor = _parseColor(task.categoryColor);
    final priColor = _getPriorityColor(task.priority);

    return GlassCard(
      padding: const EdgeInsets.all(20),
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
                        Flexible(
                          child: Text(
                            task.title,
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: priColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: priColor.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            task.priority,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: priColor),
                          ),
                        ),
                      ],
                    ),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        task.description,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF64748B)),
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) async {
                  if (val == 'IN_PROGRESS' || val == 'COMPLETED' || val == 'PENDING') {
                    await context.read<LeadProvider>().updateTaskStatus(task.id, val);
                  } else if (val == 'DELETE') {
                    await context.read<LeadProvider>().deleteTask(task.id);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'IN_PROGRESS', child: Text('Mark In Progress', style: TextStyle(color: Color(0xFF0F172A)))),
                  const PopupMenuItem(value: 'COMPLETED', child: Text('Mark Completed', style: TextStyle(color: Color(0xFF0F172A)))),
                  if (!isTelecaller)
                    const PopupMenuItem(value: 'DELETE', child: Text('Cancel Task', style: TextStyle(color: AppColors.neonCoral))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Chips Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (task.branchName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storefront_rounded, size: 13, color: AppColors.neonViolet),
                      const SizedBox(width: 5),
                      Text(task.branchName!, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                    ],
                  ),
                ),
              if (task.categoryName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: catColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    task.categoryName!,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: catColor),
                  ),
                ),
              if (task.assignedToName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 5),
                      Text('Assigned: ${task.assignedToName!}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                    ],
                  ),
                ),
              if (task.dueDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_outlined, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 5),
                      Text('Due: ${task.dueDate}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress & Action Row
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${task.completedLeadsCount} of ${task.totalLeadsCount} leads completed (${task.progressPercent}%)',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  ),
                  GradientPrimaryButton(
                    text: isTelecaller ? 'Start Calling (View Numbers)' : 'Open Task & Numbers',
                    icon: Icons.phone_in_talk_rounded,
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => TaskDetailExecutionScreen(taskId: task.id)),
                      );
                      _loadData();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 6,
                  color: const Color(0xFFE2E8F0),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: task.totalLeadsCount > 0 ? (task.completedLeadsCount / task.totalLeadsCount).clamp(0.0, 1.0) : 0.0,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF06B6D4), Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
