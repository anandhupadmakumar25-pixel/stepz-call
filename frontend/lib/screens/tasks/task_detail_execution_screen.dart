import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/app_background.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/glass_text_field.dart';
import '../../core/widgets/glass/animated_status_badge.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../routes/app_routes.dart';
import '../../providers/lead_provider.dart';
import '../../providers/call_provider.dart';
import '../../providers/recording_provider.dart';
import '../../models/lead_model.dart';
import '../calls/call_outcome_dialog.dart';
import '../leads/lead_detail_screen.dart';

class TaskDetailExecutionScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailExecutionScreen({super.key, required this.taskId});

  @override
  State<TaskDetailExecutionScreen> createState() => _TaskDetailExecutionScreenState();
}

class _TaskDetailExecutionScreenState extends State<TaskDetailExecutionScreen> {
  String _statusFilter = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeadProvider>().fetchTaskDetail(widget.taskId);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showUpdateNoteDialog(LeadModel lead) {
    final noteCtrl = TextEditingController(text: lead.notes);

    showDialog(
      context: context,
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.35),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: GlassCard(
            blur: 24,
            opacity: 0.98,
            borderRadius: BorderRadius.circular(20),
            borderColor: const Color(0xFFE2E8F0),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.note_alt_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Update Notes: ${lead.fullName}',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                            ),
                            Text(
                              lead.normalizedPhone,
                              style: GoogleFonts.robotoMono(fontSize: 12, color: const Color(0xFF2563EB), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      DialogCloseButton(onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GlassTextField(
                    label: 'Call Notes & Feedback',
                    hintText: 'e.g. Customer interested in corporate license; send quotation.',
                    controller: noteCtrl,
                    maxLines: 4,
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 24),
                    padding: const EdgeInsets.only(top: 18),
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
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        GradientPrimaryButton(
                          text: 'Save Note',
                          icon: Icons.check_rounded,
                          onPressed: () async {
                            final nav = Navigator.of(ctx);
                            final scaf = ScaffoldMessenger.of(context);
                            final ok = await context.read<LeadProvider>().updateLeadNote(lead.id, noteCtrl.text.trim());
                            if (ok) {
                              nav.pop();
                              scaf.showSnackBar(
                                const SnackBar(content: Text('Note updated successfully!'), backgroundColor: AppColors.success),
                              );
                            }
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
      ),
    );
  }

  void _showRescheduleDialog(LeadModel lead) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 11, minute: 0);
    final noteCtrl = TextEditingController(text: 'Customer requested follow-up reschedule.');

    showDialog(
      context: context,
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.35),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: GlassCard(
              blur: 24,
              opacity: 0.98,
              borderRadius: BorderRadius.circular(20),
              borderColor: const Color(0xFFE2E8F0),
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: AppColors.coralGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.alarm_add_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reschedule Callback: ${lead.fullName}',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                              ),
                              Text(
                                lead.normalizedPhone,
                                style: GoogleFonts.robotoMono(fontSize: 12, color: AppColors.neonCoral, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        DialogCloseButton(onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: GlassSecondaryButton(
                            text: '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                            icon: Icons.calendar_today_rounded,
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 90)),
                              );
                              if (picked != null) {
                                setDlgState(() => selectedDate = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GlassSecondaryButton(
                            text: selectedTime.format(context),
                            icon: Icons.access_time_rounded,
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                              );
                              if (picked != null) {
                                setDlgState(() => selectedTime = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GlassTextField(
                      label: 'Callback Reason / Notes',
                      hintText: 'e.g. Call after 2 PM tomorrow, spoke with decision maker.',
                      controller: noteCtrl,
                      maxLines: 3,
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 24),
                      padding: const EdgeInsets.only(top: 18),
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
                            onPressed: () => Navigator.pop(ctx),
                          ),
                          GradientPrimaryButton(
                            text: 'Confirm Reschedule',
                            icon: Icons.schedule_rounded,
                            gradient: AppColors.coralGradient,
                            onPressed: () async {
                              final nav = Navigator.of(ctx);
                              final scaf = ScaffoldMessenger.of(context);
                              final scheduledAt = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );
                              final ok = await context.read<LeadProvider>().rescheduleLeadCallback(
                                    lead.id,
                                    scheduledAt.toIso8601String(),
                                    noteCtrl.text.trim(),
                                  );
                              if (ok) {
                                nav.pop();
                                scaf.showSnackBar(
                                  const SnackBar(content: Text('Callback scheduled successfully!'), backgroundColor: AppColors.success),
                                );
                              }
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
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'QUALIFIED':
      case 'COMPLETED':
        return const Color(0xFF10B981);
      case 'CALLBACK_REQUESTED':
      case 'IN_PROGRESS':
        return const Color(0xFFF59E0B);
      case 'BUSY':
      case 'NO_ANSWER':
        return const Color(0xFFF97316);
      case 'NOT_INTERESTED':
      case 'BLOCKED':
        return AppColors.neonCoral;
      default:
        return const Color(0xFF2563EB);
    }
  }

  static const Map<String, String> _leadStatusLabels = {
    'ASSIGNED': 'Pending Call',
    'IN_PROGRESS': 'In Progress',
    'CALLBACK_REQUESTED': 'Callback',
    'BUSY': 'Busy',
    'NO_ANSWER': 'No Answer',
    'QUALIFIED': 'Qualified',
    'COMPLETED': 'Completed',
    'NOT_INTERESTED': 'Not Interested',
    'UNASSIGNED': 'Unassigned',
    'BLOCKED': 'Blocked',
    'ARCHIVED': 'Archived',
  };

  List<DropdownMenuItem<String>> _buildLeadStatusDropdownItems(String currentStatus) {
    final statusMap = Map<String, String>.from(_leadStatusLabels);
    if (!statusMap.containsKey(currentStatus)) {
      statusMap[currentStatus] = currentStatus.replaceAll('_', ' ');
    }
    return statusMap.entries.map((entry) {
      return DropdownMenuItem<String>(
        value: entry.key,
        child: Text(entry.value),
      );
    }).toList();
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF2563EB);
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return const Color(0xFF2563EB);
  }

  @override
  Widget build(BuildContext context) {
    final leadProv = context.watch<LeadProvider>();
    final task = leadProv.activeTaskDetail;
    final isMobile = ResponsiveLayout.isMobile(context);

    if (leadProv.isLoadingTaskDetail || task == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final catColor = _parseColor(task.categoryColor);

    final filteredLeads = leadProv.taskLeads.where((l) {
      if (_statusFilter != 'ALL' && l.status != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return l.fullName.toLowerCase().contains(q) ||
            l.normalizedPhone.contains(q) ||
            l.notes.toLowerCase().contains(q);
      }
      return true;
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
                // Header with Back Button
                Row(
                  children: [
                    const AppBackButton(fallbackRoute: AppRoutes.tasks),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  task.title,
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
                                label: task.status,
                                statusColor: _getStatusColor(task.status),
                              ),
                            ],
                          ),
                          Text(
                            'Live Telecalling Queue Execution Studio',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Task Info Banner Glass Card
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
                        spacing: 10,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (task.branchName != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.storefront_rounded, size: 13, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 5),
                                      Text(task.branchName!, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                                    ],
                                  ),
                                ),
                              if (task.categoryName != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: catColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(task.categoryName!, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: catColor)),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Priority: ${task.priority}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                              ),
                              if (task.dueDate != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('Due: ${task.dueDate}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569))),
                                ),
                            ],
                          ),
                          Text(
                            '${task.completedLeadsCount} / ${task.totalLeadsCount} Completed (${task.progressPercent}%)',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 8,
                          color: const Color(0xFFE2E8F0),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: task.totalLeadsCount > 0 ? (task.completedLeadsCount / task.totalLeadsCount).clamp(0.0, 1.0) : 0.0,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: AppColors.primaryGradient,
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.format_quote_rounded, size: 20, color: Color(0xFF2563EB)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Calling Pitch / Guidelines:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB))),
                                    const SizedBox(height: 4),
                                    Text(task.description, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155), height: 1.3)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Toolbar with Status Filters & Search
                GlassCard(
                  blur: 16,
                  opacity: 0.95,
                  borderRadius: BorderRadius.circular(16),
                  borderColor: const Color(0xFFE2E8F0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: isMobile ? double.infinity : 260,
                        height: 40,
                        child: TextField(
                          controller: _searchCtrl,
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'Search in task leads...',
                            hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF2563EB)),
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
                              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            isDense: true,
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 14, color: Color(0xFF64748B)),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v.trim()),
                        ),
                      ),
                      Container(
                        width: isMobile ? double.infinity : 180,
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _statusFilter,
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B), size: 20),
                            items: const [
                              DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                              DropdownMenuItem(value: 'ASSIGNED', child: Text('Pending Call')),
                              DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress')),
                              DropdownMenuItem(value: 'CALLBACK_REQUESTED', child: Text('Callback')),
                              DropdownMenuItem(value: 'BUSY', child: Text('Busy')),
                              DropdownMenuItem(value: 'NO_ANSWER', child: Text('No Answer')),
                              DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                              DropdownMenuItem(value: 'QUALIFIED', child: Text('Qualified')),
                              DropdownMenuItem(value: 'NOT_INTERESTED', child: Text('Not Interested')),
                            ],
                            onChanged: (v) => setState(() => _statusFilter = v ?? 'ALL'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Lead Cards / List
                if (filteredLeads.isEmpty)
                  GlassCard(
                    blur: 16,
                    opacity: 0.95,
                    borderColor: const Color(0xFFE2E8F0),
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Text('No leads match the filter.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredLeads.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final lead = filteredLeads[i];
                      return _buildLeadGlassItem(lead);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadGlassItem(LeadModel lead) {
    final statusColor = _getStatusColor(lead.status);

    return GlassCard(
      blur: 20,
      opacity: 0.95,
      borderRadius: BorderRadius.circular(20),
      borderColor: const Color(0xFFE2E8F0),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Name, Phone, Status Dropdown
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.fullName,
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone_rounded, size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Text(
                          lead.normalizedPhone,
                          style: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                        ),
                        if (lead.city.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '• ${lead.city}',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
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
              // Status Pill with Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: Builder(
                    builder: (context) {
                      final statusItems = _buildLeadStatusDropdownItems(lead.status);
                      final effectiveValue = statusItems.any((item) => item.value == lead.status)
                          ? lead.status
                          : statusItems.first.value;

                      return DropdownButton<String>(
                        value: effectiveValue,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        icon: Icon(Icons.arrow_drop_down, color: statusColor, size: 20),
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                        items: statusItems,
                        onChanged: (newStatus) {
                          if (newStatus != null) {
                            context.read<LeadProvider>().updateLeadStatus(lead.id, newStatus);
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          // Notes Row
          if (lead.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notes_rounded, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lead.notes,
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Actions Row: Call, View Details, Update Note, Reschedule Callback
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GradientPrimaryButton(
                text: 'Call & Log Outcome',
                icon: Icons.phone_in_talk_rounded,
                gradient: AppColors.primaryGradient,
                onPressed: () async {
                  final callProvider = context.read<CallProvider>();
                  final recordingProvider = context.read<RecordingProvider>();
                  await recordingProvider.ensurePermissions();
                  await recordingProvider.startRecording(
                    leadId: lead.id,
                    leadName: lead.fullName,
                    leadPhone: lead.normalizedPhone,
                  );
                  await callProvider.launchDialer(lead.normalizedPhone);
                  if (mounted) {
                    await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => CallOutcomeDialog(
                        leadId: lead.id,
                        leadName: lead.fullName,
                        phoneNumber: lead.normalizedPhone,
                      ),
                    );
                    if (mounted) {
                      context.read<LeadProvider>().fetchTaskDetail(widget.taskId);
                    }
                  }
                },
              ),
              GlassSecondaryButton(
                text: 'Lead Details',
                icon: Icons.open_in_new_rounded,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LeadDetailScreen(leadId: lead.id)),
                  ).then((_) {
                    if (mounted) {
                      context.read<LeadProvider>().fetchTaskDetail(widget.taskId);
                    }
                  });
                },
              ),
              GlassSecondaryButton(
                text: lead.notes.isEmpty ? 'Add Note' : 'Update Note',
                icon: Icons.edit_note_rounded,
                onPressed: () => _showUpdateNoteDialog(lead),
              ),
              GlassSecondaryButton(
                text: 'Reschedule',
                icon: Icons.alarm_add_rounded,
                onPressed: () => _showRescheduleDialog(lead),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
