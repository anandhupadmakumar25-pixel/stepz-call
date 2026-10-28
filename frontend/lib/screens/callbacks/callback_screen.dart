import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/empty_state.dart';
import '../../providers/callback_provider.dart';
import '../../providers/call_provider.dart';
import '../../models/callback_model.dart';
import '../calls/call_outcome_dialog.dart';

class CallbackScreen extends StatefulWidget {
  const CallbackScreen({super.key});

  @override
  State<CallbackScreen> createState() => _CallbackScreenState();
}

class _CallbackScreenState extends State<CallbackScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['ALL', 'DUE', 'UPCOMING', 'OVERDUE', 'COMPLETED'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _fetchTabCallbacks(_tabs[_tabController.index]);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CallbackProvider>().fetchCallbacks(status: 'ALL');
    });
  }

  void _fetchTabCallbacks(String tab) {
    final provider = context.read<CallbackProvider>();
    if (tab == 'ALL') {
      provider.fetchCallbacks(status: 'ALL');
    } else if (tab == 'DUE') {
      provider.fetchCallbacks(status: 'DUE');
    } else if (tab == 'UPCOMING') {
      provider.fetchCallbacks(status: 'SCHEDULED', dateFilter: 'upcoming');
    } else if (tab == 'OVERDUE') {
      provider.fetchCallbacks(status: 'OVERDUE');
    } else if (tab == 'COMPLETED') {
      provider.fetchCallbacks(status: 'COMPLETED');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _reschedule(CallbackModel cb) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (pickedDate != null && mounted) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 10, minute: 30),
      );
      if (pickedTime != null && mounted) {
        final newDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        final reasonController = TextEditingController();
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Reschedule Callback', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New scheduled time: ${DateFormat('EEE, MMM d, yyyy @ h:mm a').format(newDateTime)}'),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Reason for Rescheduling *'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (reasonController.text.trim().isNotEmpty) {
                    Navigator.of(ctx).pop(true);
                  }
                },
                child: const Text('Confirm Reschedule'),
              ),
            ],
          ),
        );

        if (confirmed == true && mounted) {
          final success = await context.read<CallbackProvider>().rescheduleCallback(
                cb.id,
                newDateTime,
                reasonController.text.trim(),
              );
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Callback rescheduled successfully.'), backgroundColor: AppColors.success),
            );
          }
        }
      }
    }
  }

  Future<void> _complete(CallbackModel cb) async {
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Complete Callback', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Record notes for completed callback with ${cb.leadName}:'),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Completion Notes *'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (notesController.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Mark Completed'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context.read<CallbackProvider>().completeCallback(
            cb.id,
            notesController.text.trim(),
          );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Callback marked completed.'), backgroundColor: AppColors.success),
        );
      }
    }
  }

  Future<void> _callLead(CallbackModel cb) async {
    final callProvider = context.read<CallProvider>();
    await callProvider.launchDialer(cb.leadPhone);

    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => CallOutcomeDialog(
          leadId: cb.leadId,
          leadName: cb.leadName,
          phoneNumber: cb.leadPhone,
        ),
      );
      _fetchTabCallbacks(_tabs[_tabController.index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cbProvider = context.watch<CallbackProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Tabs Bar with Check Reminders Button
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: AppColors.accentViolet,
                        unselectedLabelColor: AppColors.textSecondary,
                        indicatorColor: AppColors.accentViolet,
                        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                        tabs: const [
                          Tab(text: 'All Callbacks'),
                          Tab(text: 'Due Now'),
                          Tab(text: 'Upcoming'),
                          Tab(text: 'Overdue'),
                          Tab(text: 'Completed'),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await cbProvider.checkReminders();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reminder engine checked & synchronized.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.sync, size: 16),
                      label: const Text('Sync Reminders'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Callback List
            Expanded(
              child: cbProvider.isLoading && cbProvider.callbacks.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : cbProvider.callbacks.isEmpty
                      ? const EmptyState(
                          icon: Icons.event_available,
                          title: 'No callbacks found',
                          description: 'No callbacks are scheduled in this category.',
                        )
                      : ListView.separated(
                          itemCount: cbProvider.callbacks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final cb = cbProvider.callbacks[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: cb.status == 'OVERDUE'
                                            ? AppColors.dangerLight
                                            : cb.status == 'DUE'
                                                ? AppColors.warningLight
                                                : AppColors.accentVioletLight,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        cb.status == 'OVERDUE'
                                            ? Icons.warning_amber_rounded
                                            : Icons.alarm,
                                        color: cb.status == 'OVERDUE'
                                            ? AppColors.danger
                                            : cb.status == 'DUE'
                                                ? AppColors.warning
                                                : AppColors.accentViolet,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                cb.leadName,
                                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '(${cb.leadPhone})',
                                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'monospace'),
                                              ),
                                              const SizedBox(width: 10),
                                              StatusBadge(status: cb.status, isCallback: true),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Scheduled: ${cb.scheduledAt.replaceAll('T', ' ').substring(0, 16)}',
                                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                              ),
                                              const SizedBox(width: 16),
                                              const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Caller: ${cb.assignedEmployeeName}',
                                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                          if (cb.initialNotes.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Notes: ${cb.initialNotes}',
                                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),

                                    // Action Buttons
                                    if (cb.status != 'COMPLETED') ...[
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                                        onPressed: () => _callLead(cb),
                                        icon: const Icon(Icons.phone, size: 16, color: Colors.white),
                                        label: const Text('Call Now'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: () => _reschedule(cb),
                                        child: const Text('Reschedule'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: () => _complete(cb),
                                        child: const Text('Complete'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
