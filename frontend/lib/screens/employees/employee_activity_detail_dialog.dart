import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/network/api_client.dart';
import '../../models/lead_model.dart';
import '../../models/recording_model.dart';
import '../../models/call_model.dart';
import '../tasks/calling_tasks_screen.dart';
import '../tasks/task_detail_execution_screen.dart';
import '../calls/call_recordings_screen.dart';
import '../calls/call_history_screen.dart';
import '../leads/lead_detail_screen.dart';

class EmployeeActivityDetailDialog extends StatefulWidget {
  final Map<String, dynamic> employee;

  const EmployeeActivityDetailDialog({super.key, required this.employee});

  @override
  State<EmployeeActivityDetailDialog> createState() => _EmployeeActivityDetailDialogState();
}

class _EmployeeActivityDetailDialogState extends State<EmployeeActivityDetailDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  List<CallingTaskModel> _tasks = [];
  List<CallRecordingModel> _recordings = [];
  List<CallAttemptModel> _calls = [];
  List<LeadModel> _leads = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchEmployeeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchEmployeeData() async {
    final empId = widget.employee['id']?.toString() ?? '';
    if (empId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch Tasks
      try {
        final taskRes = await ApiClient.get('/leads/tasks/?assigned_to=$empId');
        if (taskRes is List) {
          _tasks = taskRes.map((t) => CallingTaskModel.fromJson(t)).toList();
        }
      } catch (_) {}

      // 2. Fetch Recordings
      try {
        final recRes = await ApiClient.get('/calls/recordings/?employee=$empId');
        if (recRes is List) {
          _recordings = recRes.map((r) => CallRecordingModel.fromJson(r)).toList();
        }
      } catch (_) {}

      // 3. Fetch Calls
      try {
        final callRes = await ApiClient.get('/calls/?employee=$empId');
        if (callRes is List) {
          _calls = callRes.map((c) => CallAttemptModel.fromJson(c)).toList();
        }
      } catch (_) {}

      // 4. Fetch Assigned Leads
      try {
        final leadRes = await ApiClient.get('/leads/?assigned_to=$empId');
        if (leadRes is List) {
          _leads = leadRes.map((l) => LeadModel.fromJson(l)).toList();
        } else if (leadRes is Map && leadRes['results'] is List) {
          _leads = (leadRes['results'] as List).map((l) => LeadModel.fromJson(l)).toList();
        }
      } catch (_) {}
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getTaskStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return const Color(0xFF10B981);
      case 'IN_PROGRESS':
        return const Color(0xFF2563EB);
      case 'PAUSED':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'URGENT':
        return AppColors.neonCoral;
      case 'HIGH':
        return const Color(0xFFF97316);
      case 'LOW':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF2563EB);
    }
  }

  Color _getOutcomeColor(String outcome) {
    switch (outcome.toUpperCase()) {
      case 'INTERESTED':
      case 'QUALIFIED':
        return const Color(0xFF10B981);
      case 'CALLBACK_REQUESTED':
      case 'FOLLOW_UP':
        return const Color(0xFFF59E0B);
      case 'BUSY':
      case 'NO_ANSWER':
        return const Color(0xFF8B5CF6);
      case 'NOT_INTERESTED':
      case 'WRONG_NUMBER':
        return AppColors.neonCoral;
      default:
        return const Color(0xFF64748B);
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.employee;
    final name = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.trim();
    final displayName = name.isNotEmpty ? name : (emp['email'] ?? 'Employee');
    final email = emp['email'] ?? '';
    final phone = emp['phone'] ?? '';
    final branchName = emp['branch_name'] as String?;
    final deptName = emp['department_name'] as String?;
    final target = emp['daily_call_target'] ?? 50;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 880),
        child: GlassCard(
          blur: 24,
          opacity: 0.98,
          borderRadius: BorderRadius.circular(20),
          borderColor: const Color(0xFFCBD5E1),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Profile & Close Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonViolet.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'E',
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (emp['is_active'] ?? true)
                                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                    : Colors.grey.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                (emp['is_active'] ?? true) ? 'ACTIVE' : 'INACTIVE',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: (emp['is_active'] ?? true) ? const Color(0xFF059669) : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$email${phone.isNotEmpty ? ' • $phone' : ''}',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (deptName != null && deptName.isNotEmpty)
                              _buildPill(deptName, Icons.business_rounded, const Color(0xFF6366F1)),
                            if (branchName != null && branchName.isNotEmpty)
                              _buildPill(branchName, Icons.storefront_rounded, const Color(0xFF64748B)),
                            _buildPill('Target: $target calls/day', Icons.flag_outlined, const Color(0xFF059669)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Metrics Quick Overview Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickMetric('Tasks Assigned', '${_tasks.length}', '${_tasks.where((t) => t.status == 'COMPLETED').length} done', Icons.assignment_outlined, const Color(0xFF2563EB)),
                    _buildDivider(),
                    _buildQuickMetric('Recordings', '${_recordings.length}', 'uploaded', Icons.mic_rounded, const Color(0xFF8B5CF6)),
                    _buildDivider(),
                    _buildQuickMetric('Calls Logged', '${_calls.length}', 'outcomes tracked', Icons.phone_callback_rounded, const Color(0xFF059669)),
                    _buildDivider(),
                    _buildQuickMetric('Assigned Leads', '${_leads.length}', 'in pipeline', Icons.people_outline_rounded, const Color(0xFFF59E0B)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Hub Shortcuts Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      icon: const Icon(Icons.mic_none_rounded, size: 16, color: Color(0xFF6366F1)),
                      label: Text('Open in Recordings Hub', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF4338CA))),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CallRecordingsScreen(
                              initialEmployeeId: emp['id']?.toString(),
                              employeeName: displayName,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      icon: const Icon(Icons.checklist_rounded, size: 16, color: Color(0xFF0284C7)),
                      label: Text('Open in Tasks Hub', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0369A1))),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CallingTasksScreen(
                              initialEmployeeId: emp['id']?.toString(),
                              employeeName: displayName,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      icon: const Icon(Icons.history_rounded, size: 16, color: Color(0xFF059669)),
                      label: Text('Open in Call Logs Hub', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF047857))),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CallHistoryScreen(
                              initialEmployeeId: emp['id']?.toString(),
                              employeeName: displayName,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 4. Tab Bar
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF2563EB),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFF2563EB),
                indicatorWeight: 3,
                labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                tabs: [
                  Tab(text: 'Tasks (${_tasks.length})'),
                  Tab(text: 'Audio Recordings (${_recordings.length})'),
                  Tab(text: 'Call Logs (${_calls.length})'),
                  Tab(text: 'Assigned Leads (${_leads.length})'),
                ],
              ),
              const SizedBox(height: 12),

              // 5. Tab Content Views
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline_rounded, color: AppColors.neonCoral, size: 36),
                                const SizedBox(height: 8),
                                Text('Failed to load employee activity: $_errorMessage', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13)),
                                const SizedBox(height: 12),
                                ElevatedButton(onPressed: _fetchEmployeeData, child: const Text('Retry')),
                              ],
                            ),
                          )
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildTasksTab(),
                              _buildRecordingsTab(),
                              _buildCallsTab(),
                              _buildLeadsTab(),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: CALLING TASKS
  // ==========================================
  Widget _buildTasksTab() {
    if (_tasks.isEmpty) {
      return _buildEmptyState('No Tasks Assigned', 'This employee does not have any calling tasks assigned yet.');
    }

    return ListView.separated(
      itemCount: _tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final task = _tasks[i];
        final statusColor = _getTaskStatusColor(task.status);
        final priorityColor = _getPriorityColor(task.priority);
        final pct = (task.progressPercent * 100).clamp(0, 100).toInt();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          task.priority,
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: priorityColor),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          task.status.replaceAll('_', ' '),
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (task.description.isNotEmpty) ...[
                Text(
                  task.description,
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],
              // Progress Bar
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: task.totalLeadsCount > 0 ? (task.completedLeadsCount / task.totalLeadsCount).clamp(0.0, 1.0) : 0.0,
                        backgroundColor: const Color(0xFFF1F5F9),
                        color: statusColor,
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${task.completedLeadsCount}/${task.totalLeadsCount} Leads ($pct%)',
                    style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Dates & Action Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 12,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            'Assigned: ${task.createdAt.split('T').first}',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      if (task.dueDate != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, size: 12, color: Color(0xFFEF4444)),
                            const SizedBox(width: 4),
                            Text(
                              'Due: ${task.dueDate}',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444)),
                            ),
                          ],
                        ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => TaskDetailExecutionScreen(taskId: task.id)),
                      );
                    },
                    icon: const Icon(Icons.launch_rounded, size: 13, color: Color(0xFF2563EB)),
                    label: Text('Open Execution Hub', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB))),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 2: CALL RECORDINGS
  // ==========================================
  Widget _buildRecordingsTab() {
    if (_recordings.isEmpty) {
      return _buildEmptyState('No Recordings Uploaded', 'This employee has not uploaded or recorded any call audio yet.');
    }

    return ListView.separated(
      itemCount: _recordings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final rec = _recordings[i];
        final dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(rec.createdAt.toLocal());
        final durationStr = _formatDuration(rec.durationSeconds);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.graphic_eq_rounded, color: Color(0xFF7C3AED), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            rec.leadName ?? 'Lead Contact',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            durationStr,
                            style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${rec.leadPhone ?? 'No Phone'}${rec.leadCity != null && rec.leadCity!.isNotEmpty ? ' • ${rec.leadCity}' : ''}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_outline_rounded, size: 11, color: Color(0xFF1D4ED8)),
                              const SizedBox(width: 3),
                              Text(
                                'Staff: ${rec.employeeName ?? (widget.employee['first_name'] ?? 'Staff')}',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF475569)),
                              const SizedBox(width: 3),
                              Text(
                                dateStr,
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (rec.notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          rec.notes,
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (rec.audioUrl != null && rec.audioUrl!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF2563EB), size: 28),
                  tooltip: 'Play / Open Audio File',
                  onPressed: () async {
                    final uri = Uri.parse(rec.audioUrl!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 3: CALL LOGS
  // ==========================================
  Widget _buildCallsTab() {
    if (_calls.isEmpty) {
      return _buildEmptyState('No Call Logs', 'This employee has not dialed or logged any calls yet.');
    }

    return ListView.separated(
      itemCount: _calls.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final call = _calls[i];
        final outcomeColor = _getOutcomeColor(call.outcome);
        final dateStr = call.createdAt.isNotEmpty ? call.createdAt.split('.').first.replaceAll('T', ' ') : 'Recent';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: outcomeColor.withValues(alpha: 0.12),
                child: Icon(Icons.phone_rounded, color: outcomeColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            call.leadName,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: outcomeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            call.outcome.replaceAll('_', ' '),
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: outcomeColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${call.leadPhone} • $dateStr • ${call.durationSeconds}s',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                    if (call.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        call.notes,
                        style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF334155)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 4: ASSIGNED LEADS
  // ==========================================
  Widget _buildLeadsTab() {
    if (_leads.isEmpty) {
      return _buildEmptyState('No Leads Assigned', 'There are currently no leads assigned to this employee.');
    }

    return ListView.separated(
      itemCount: _leads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final lead = _leads[i];
        final statusColor = _getOutcomeColor(lead.status);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                child: Text(
                  lead.fullName.isNotEmpty ? lead.fullName[0].toUpperCase() : 'L',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            lead.fullName,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            lead.status.replaceAll('_', ' '),
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lead.phoneNumber}${lead.city.isNotEmpty ? ' • ${lead.city}' : ''}',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                tooltip: 'View Lead Details',
                onPressed: () {
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
    );
  }

  Widget _buildQuickMetric(String title, String mainValue, String subtitle, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              mainValue,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
        Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 32, color: const Color(0xFFCBD5E1));
  }

  Widget _buildPill(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inbox_rounded, size: 36, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
            const SizedBox(height: 4),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
