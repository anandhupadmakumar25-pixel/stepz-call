import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/date_range_filter_bar.dart';
import '../../core/widgets/glass/animated_status_badge.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/glass_scaffold.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../models/lead_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/lead_provider.dart';
import '../../routes/app_routes.dart';
import 'create_calling_task_screen.dart';
import 'task_detail_execution_screen.dart';

class CallingTasksScreen extends StatefulWidget {
  final String? initialEmployeeId;
  final String? employeeName;

  const CallingTasksScreen({
    super.key,
    this.initialEmployeeId,
    this.employeeName,
  });

  @override
  State<CallingTasksScreen> createState() => _CallingTasksScreenState();
}

class _CallingTasksScreenState extends State<CallingTasksScreen> {
  String _selectedBranch = 'ALL';
  String _selectedRole = 'ALL';
  String _selectedStatus = 'ALL';
  String? _selectedEmployeeId;
  String? _dateFrom;
  String? _dateTo;
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
    leadProvider.fetchTasks(
      branchId: _selectedBranch,
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

  bool _matchesDateRange(CallingTaskModel task) {
    if ((_dateFrom == null || _dateFrom!.isEmpty) &&
        (_dateTo == null || _dateTo!.isEmpty)) {
      return true;
    }
    final raw = (task.dueDate != null && task.dueDate!.isNotEmpty)
        ? task.dueDate!
        : task.createdAt;
    if (raw.trim().isEmpty) return false;
    final day = raw.trim().length >= 10
        ? raw.trim().substring(0, 10)
        : raw.trim();
    if (_dateFrom != null &&
        _dateFrom!.isNotEmpty &&
        day.compareTo(_dateFrom!) < 0) {
      return false;
    }
    if (_dateTo != null &&
        _dateTo!.isNotEmpty &&
        day.compareTo(_dateTo!) > 0) {
      return false;
    }
    return true;
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'URGENT':
        return const Color(0xFFDC2626);
      case 'HIGH':
        return const Color(0xFFD97706);
      case 'LOW':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF0284C7);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return const Color(0xFF059669);
      case 'IN_PROGRESS':
        return const Color(0xFF2563EB);
      case 'CANCELLED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFD97706);
    }
  }

  String _formatTaskType(String raw) {
    switch (raw.toUpperCase()) {
      case 'CALLING':
        return 'Calling';
      case 'FIELD_VISIT':
        return 'Field Visit';
      case 'FOLLOW_UP':
        return 'Follow-Up';
      case 'SUPPORT':
        return 'Support';
      case 'ADMIN_WORK':
        return 'Admin';
      default:
        return 'General';
    }
  }

  void _showSubmitReportDialog(CallingTaskModel task) {
    String selectedStatus =
        task.status == 'PENDING' ? 'IN_PROGRESS' : task.status;
    final reportCtrl = TextEditingController(text: task.completionReport);
    bool isSaving = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) {
          final isMobile = ResponsiveLayout.isMobile(dlgCtx);
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 14 : 24,
              vertical: 20,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: GlassCard(
                blur: 22,
                opacity: 0.97,
                borderRadius: BorderRadius.circular(18),
                padding: EdgeInsets.all(isMobile ? 16 : 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assignment_turned_in_rounded,
                            color: Color(0xFF047857), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Task Report & Status',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.title,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Task Status',
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'PENDING', child: Text('Pending')),
                        DropdownMenuItem(
                            value: 'IN_PROGRESS', child: Text('In Progress')),
                        DropdownMenuItem(
                            value: 'COMPLETED', child: Text('Completed')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDlgState(() => selectedStatus = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reportCtrl,
                      maxLines: 4,
                      style: GoogleFonts.inter(fontSize: 12.5),
                      decoration: InputDecoration(
                        labelText: 'Completion / Work Report *',
                        hintText:
                            'Summarize work completed, findings, or follow-up notes...',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GlassSecondaryButton(
                          text: 'Cancel',
                          onPressed:
                              isSaving ? null : () => Navigator.pop(ctx),
                        ),
                        const SizedBox(width: 10),
                        GradientPrimaryButton(
                          text: isSaving ? 'Saving...' : 'Submit Report',
                          icon: Icons.check_rounded,
                          height: 38,
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setDlgState(() => isSaving = true);
                                  final ok = await context
                                      .read<LeadProvider>()
                                      .submitTaskReport(
                                        taskId: task.id,
                                        status: selectedStatus,
                                        completionReport: reportCtrl.text,
                                      );
                                  if (!mounted) return;
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok
                                          ? 'Task report saved!'
                                          : 'Failed to save report.'),
                                      backgroundColor: ok
                                          ? AppColors.success
                                          : AppColors.danger,
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final leadProvider = context.watch<LeadProvider>();
    final user = auth.currentUser;
    final isSuperAdmin = user?.isSuperAdmin ?? false;
    final canViewAll =
        isSuperAdmin || (user?.hasPermission('tasks.view_all') ?? false);
    final isEmployeeOnly = (user?.isEmployee ?? true) && !canViewAll;
    final canManageTasks = !isEmployeeOnly ||
        (user?.hasPermission('tasks.manage_team') ?? false) ||
        (user?.isCompanyAdmin ?? false);
    final isMobile = ResponsiveLayout.isMobile(context);

    final allTasks = leadProvider.tasks;
    final availableRoles = allTasks
        .map((t) => t.assignedToRole.trim())
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final tasks = allTasks.where((t) {
      if (!_matchesDateRange(t)) return false;
      if (_selectedRole != 'ALL' &&
          t.assignedToRole.trim() != _selectedRole) {
        return false;
      }
      return true;
    }).toList();

    return GlassScaffold(
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 12 : 24,
          isMobile ? 8 : 16,
          isMobile ? 12 : 24,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            LayoutBuilder(
              builder: (ctx, headerConstraints) {
                final titleBlock = Row(
                  children: [
                    const AppBackButton(fallbackRoute: AppRoutes.dashboard),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.employeeName != null
                                      ? '${widget.employeeName} — Tasks'
                                      : (isEmployeeOnly
                                          ? 'My Assigned Tasks'
                                          : 'Employee Tasks'),
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
                              const SizedBox(width: 8),
                              AnimatedStatusBadge(
                                label: '${tasks.length} Tasks',
                                statusColor: AppColors.neonCyan,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEmployeeOnly
                                ? 'View assigned tasks, complete work, and submit your reports'
                                : 'Assign tasks across employee roles and review submitted reports',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final assignBtn = canManageTasks
                    ? GradientPrimaryButton(
                        text: 'Assign Task',
                        icon: Icons.add_task_rounded,
                        height: 36,
                        borderRadius: 10,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreateCallingTaskScreen(),
                            ),
                          ).then((_) => _loadData());
                        },
                      )
                    : null;

                if (!isMobile && headerConstraints.maxWidth >= 680) {
                  return Row(
                    children: [
                      Expanded(child: titleBlock),
                      if (assignBtn != null) ...[
                        const SizedBox(width: 16),
                        assignBtn,
                      ],
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    if (assignBtn != null) ...[
                      const SizedBox(height: 10),
                      assignBtn,
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 14),

            // Filter Toolbar
            GlassCard(
              blur: 18,
              opacity: 0.96,
              borderRadius: BorderRadius.circular(16),
              borderColor: const Color(0xFFE2E8F0),
              padding: EdgeInsets.all(isMobile ? 12 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DateRangeFilterBar(
                    onChanged: (from, to) {
                      setState(() {
                        _dateFrom = from;
                        _dateTo = to;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (ctx, c) {
                      final searchBox = SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) {
                            _searchQuery = v.trim();
                            _loadData();
                          },
                          style: GoogleFonts.inter(fontSize: 12.5),
                          decoration: InputDecoration(
                            hintText: 'Search task title, instructions...',
                            hintStyle: GoogleFonts.inter(
                                fontSize: 12, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search_rounded,
                                size: 17, color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                        ),
                      );

                      final roleFilter = _buildDropdownFilter(
                        value: availableRoles.contains(_selectedRole)
                            ? _selectedRole
                            : 'ALL',
                        items: [
                          const DropdownMenuItem(
                              value: 'ALL', child: Text('All Roles')),
                          ...availableRoles.map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedRole = v ?? 'ALL'),
                      );

                      final branchFilter = _buildDropdownFilter(
                        value: _selectedBranch,
                        items: [
                          const DropdownMenuItem(
                              value: 'ALL', child: Text('All Branches')),
                          ...leadProvider.branches.map((b) => DropdownMenuItem(
                              value: b.id,
                              child:
                                  Text(b.name, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedBranch = v ?? 'ALL');
                          _loadData();
                        },
                      );

                      final statusFilter = _buildDropdownFilter(
                        value: _selectedStatus,
                        items: const [
                          DropdownMenuItem(
                              value: 'ALL', child: Text('All Statuses')),
                          DropdownMenuItem(
                              value: 'PENDING', child: Text('Pending')),
                          DropdownMenuItem(
                              value: 'IN_PROGRESS', child: Text('In Progress')),
                          DropdownMenuItem(
                              value: 'COMPLETED', child: Text('Completed')),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedStatus = v ?? 'ALL');
                          _loadData();
                        },
                      );

                      if (!isMobile && c.maxWidth >= 740) {
                        return Row(
                          children: [
                            Expanded(flex: 3, child: searchBox),
                            const SizedBox(width: 8),
                            Expanded(flex: 2, child: roleFilter),
                            const SizedBox(width: 8),
                            Expanded(flex: 2, child: branchFilter),
                            const SizedBox(width: 8),
                            Expanded(flex: 2, child: statusFilter),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          searchBox,
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: roleFilter),
                              const SizedBox(width: 8),
                              Expanded(child: statusFilter),
                            ],
                          ),
                          const SizedBox(height: 8),
                          branchFilter,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tasks ExpansionTile List
            Expanded(
              child: leadProvider.isLoading && tasks.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : tasks.isEmpty
                      ? GlassCard(
                          opacity: 0.96,
                          borderRadius: BorderRadius.circular(16),
                          borderColor: const Color(0xFFE2E8F0),
                          padding: const EdgeInsets.all(28),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.task_alt_rounded,
                                    size: 46, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 10),
                                Text(
                                  'No Employee Tasks Found',
                                  style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  canManageTasks
                                      ? 'Click "Assign Task" to assign work to an employee.'
                                      : 'No tasks assigned to you in this filter.',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => _loadData(),
                          child: ListView.separated(
                            itemCount: tasks.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (ctx, i) => _buildTaskExpansionTile(
                              tasks[i],
                              canManageTasks: canManageTasks,
                              isMobile: isMobile,
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskExpansionTile(
    CallingTaskModel task, {
    required bool canManageTasks,
    required bool isMobile,
  }) {
    final priorityColor = _getPriorityColor(task.priority);
    final statusColor = _getStatusColor(task.status);
    final hasReport = task.completionReport.trim().isNotEmpty;

    return GlassCard(
      opacity: 0.96,
      borderRadius: BorderRadius.circular(14),
      borderColor: const Color(0xFFE2E8F0),
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16, vertical: 4),
          childrenPadding: EdgeInsets.fromLTRB(
              isMobile ? 12 : 16, 0, isMobile ? 12 : 16, 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          collapsedShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              task.status == 'COMPLETED'
                  ? Icons.check_circle_rounded
                  : Icons.assignment_outlined,
              color: statusColor,
              size: 20,
            ),
          ),
          title: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                task.title,
                style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A)),
              ),
              _buildBadge(
                  _formatTaskType(task.taskType),
                  const Color(0xFF4338CA),
                  const Color(0xFFEEF2FF)),
              _buildBadge(
                  task.status.replaceAll('_', ' '),
                  statusColor,
                  statusColor.withValues(alpha: 0.12)),
              _buildBadge(
                  task.priority,
                  priorityColor,
                  priorityColor.withValues(alpha: 0.12)),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '${task.assignedToName ?? "Employee"}'
              '${task.assignedToRole.isNotEmpty ? " (${task.assignedToRole})" : ""}'
              '${task.dueDate != null && task.dueDate!.isNotEmpty ? " · Due: ${task.dueDate}" : ""}'
              '${hasReport ? " · Report Submitted" : " · Pending Report"}',
              style: GoogleFonts.inter(
                  fontSize: 11.5, color: const Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          children: [
            const Divider(color: Color(0xFFE2E8F0), height: 14),
            if (task.description.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Instructions: ${task.description}',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFF334155)),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hasReport
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasReport
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasReport ? 'Submitted Report' : 'Employee Report',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: hasReport
                          ? const Color(0xFF047857)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasReport
                        ? task.completionReport
                        : 'No report submitted yet.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    height: 34,
                    child: ElevatedButton.icon(
                      onPressed: () => _showSubmitReportDialog(task),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.rate_review_outlined, size: 14.5),
                      label: Text(
                        hasReport ? 'Update Report' : 'Submit Report',
                        style: GoogleFonts.inter(
                            fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (task.totalLeadsCount > 0)
                    SizedBox(
                      height: 34,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TaskDetailExecutionScreen(taskId: task.id),
                            ),
                          ).then((_) => _loadData());
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                          backgroundColor: const Color(0xFFEFF6FF),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.list_alt_rounded,
                            size: 14.5, color: Color(0xFF1D4ED8)),
                        label: Text(
                          'Task Leads (${task.totalLeadsCount})',
                          style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1D4ED8)),
                        ),
                      ),
                    ),
                  if (canManageTasks)
                    SizedBox(
                      height: 34,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.read<LeadProvider>().deleteTask(task.id),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFECDD3)),
                          backgroundColor: const Color(0xFFFFF1F2),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 14.5, color: Color(0xFFDC2626)),
                        label: Text(
                          'Delete',
                          style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFDC2626)),
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

  Widget _buildBadge(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
            fontSize: 9.5, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: Colors.white,
          style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
