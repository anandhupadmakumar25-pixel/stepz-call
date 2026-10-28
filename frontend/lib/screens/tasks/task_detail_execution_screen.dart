import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../providers/lead_provider.dart';
import '../../models/lead_model.dart';
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
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.note_alt_outlined, color: AppColors.accentViolet, size: 20),
            const SizedBox(width: 8),
            Text('Update Note: ${lead.fullName}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Number: ${lead.normalizedPhone}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Call Notes / Customer Feedback',
                hintText: 'e.g. Interested in course; asked for pricing brochure on WhatsApp.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
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
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  void _showRescheduleDialog(LeadModel lead) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 11, minute: 0);
    final noteCtrl = TextEditingController(text: 'Customer requested reschedule.');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.alarm_add_outlined, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text('Reschedule Call: ${lead.fullName}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Number: ${lead.normalizedPhone}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
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
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setDlgState(() => selectedTime = picked);
                        }
                      },
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(selectedTime.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Callback Reason / Notes',
                  hintText: 'e.g. Call after 2 PM tomorrow, spoke with parent.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final scheduledDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );
                final nav = Navigator.of(ctx);
                final scaf = ScaffoldMessenger.of(context);
                final ok = await context.read<LeadProvider>().scheduleLeadCallback(
                  lead.id,
                  scheduledDateTime,
                  noteCtrl.text.trim(),
                );
                if (ok) {
                  nav.pop();
                  scaf.showSnackBar(
                    const SnackBar(content: Text('Callback scheduled & lead updated!'), backgroundColor: AppColors.success),
                  );
                }
              },
              child: const Text('Schedule Callback'),
            ),
          ],
        ),
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
      case 'CALLBACK_REQUESTED':
        return AppColors.warning;
      case 'NOT_INTERESTED':
      case 'BLOCKED':
        return AppColors.danger;
      default:
        return AppColors.accentViolet;
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
    final leadProvider = context.watch<LeadProvider>();
    final task = leadProvider.selectedTask;
    final leads = leadProvider.taskLeads;
    final isMobile = ResponsiveLayout.isMobile(context);

    if (task == null && leadProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Calling Task')),
        body: const Center(child: Text('Calling task not found.')),
      );
    }

    final catColor = _parseColor(task.categoryColor);

    // Filter leads
    final filteredLeads = leads.where((l) {
      if (_statusFilter != 'ALL' && l.status != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return l.fullName.toLowerCase().contains(q) ||
            l.normalizedPhone.contains(q) ||
            l.city.toLowerCase().contains(q) ||
            l.notes.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(task.title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 1,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(task.status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              task.status,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _getStatusColor(task.status)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Task Info Banner
            Container(
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (task.branchName != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(task.categoryName!, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: catColor)),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSecondary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Priority: ${task.priority}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                          if (task.dueDate != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Due: ${task.dueDate}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                            ),
                        ],
                      ),
                      Text(
                        '${task.completedLeadsCount} of ${task.totalLeadsCount} Completed (${task.progressPercent}%)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: task.totalLeadsCount > 0 ? (task.completedLeadsCount / task.totalLeadsCount) : 0,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        task.progressPercent == 100 ? AppColors.success : AppColors.accentViolet,
                      ),
                      minHeight: 8,
                    ),
                  ),

                  // Calling Script / Instructions
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentVioletLight.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.accentViolet.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline, size: 18, color: AppColors.accentViolet),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Calling Script / Instructions:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentViolet)),
                                const SizedBox(height: 2),
                                Text(task.description, style: GoogleFonts.inter(fontSize: 12)),
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
            const SizedBox(height: 14),

            // Toolbar with Status Filters & Search
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
                    width: isMobile ? double.infinity : 220,
                    height: 38,
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search in task leads...',
                        prefixIcon: const Icon(Icons.search, size: 16),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14),
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
                  SizedBox(
                    width: 170,
                    height: 38,
                    child: DropdownButtonFormField<String>(
                      initialValue: _statusFilter,
                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'ASSIGNED', child: Text('Pending Call')),
                        DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress')),
                        DropdownMenuItem(value: 'CALLBACK_REQUESTED', child: Text('Callback')),
                        DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                        DropdownMenuItem(value: 'QUALIFIED', child: Text('Qualified')),
                        DropdownMenuItem(value: 'NOT_INTERESTED', child: Text('Not Interested')),
                      ],
                      onChanged: (v) => setState(() => _statusFilter = v ?? 'ALL'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Lead Cards / List
            if (filteredLeads.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                alignment: Alignment.center,
                child: Text('No leads match the filter.', style: GoogleFonts.inter(color: AppColors.textSecondary)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredLeads.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final lead = filteredLeads[i];
                  return _buildLeadItem(lead);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadItem(LeadModel lead) {
    final statusColor = _getStatusColor(lead.status);

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
          // Top Row: Name, Phone, Status Dropdown
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lead.fullName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 14, color: AppColors.accentViolet),
                        const SizedBox(width: 4),
                        Text(lead.normalizedPhone, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w600)),
                        if (lead.city.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text('• ${lead.city}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Status Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButton<String>(
                  value: lead.status,
                  underline: const SizedBox(),
                  icon: Icon(Icons.arrow_drop_down, color: statusColor, size: 18),
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                  items: const [
                    DropdownMenuItem(value: 'ASSIGNED', child: Text('Pending Call')),
                    DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress')),
                    DropdownMenuItem(value: 'CALLBACK_REQUESTED', child: Text('Callback')),
                    DropdownMenuItem(value: 'QUALIFIED', child: Text('Qualified')),
                    DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                    DropdownMenuItem(value: 'NOT_INTERESTED', child: Text('Not Interested')),
                  ],
                  onChanged: (newStatus) {
                    if (newStatus != null) {
                      context.read<LeadProvider>().updateLeadStatus(lead.id, newStatus);
                    }
                  },
                ),
              ),
            ],
          ),

          // Notes Row
          if (lead.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notes, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lead.notes,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Actions Row: Call, Update Note, Reschedule Callback
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LeadDetailScreen(leadId: lead.id)),
                  );
                },
                icon: const Icon(Icons.phone_in_talk, size: 14),
                label: const Text('Call & Log Outcome'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showUpdateNoteDialog(lead),
                icon: const Icon(Icons.edit_note, size: 16),
                label: Text(lead.notes.isEmpty ? 'Add Note' : 'Update Note'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showRescheduleDialog(lead),
                icon: const Icon(Icons.alarm_add, size: 16, color: AppColors.warning),
                label: const Text('Reschedule / Callback'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
