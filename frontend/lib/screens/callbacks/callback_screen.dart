import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/glass_text_field.dart';
import '../../core/widgets/glass/animated_status_badge.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../routes/app_routes.dart';
import '../../providers/callback_provider.dart';
import '../../providers/call_provider.dart';
import '../../providers/recording_provider.dart';
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
          barrierColor: Colors.black.withValues(alpha: 0.7),
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: GlassCard(
                blur: 24,
                opacity: 0.18,
                borderRadius: BorderRadius.circular(20),
                borderColor: AppColors.glassBorderHighlight,
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
                            child: Text(
                              'Reschedule Callback',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A)),
                            ),
                          ),
                          DialogCloseButton(onPressed: () => Navigator.of(ctx).pop(false)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'New time: ${DateFormat('EEE, MMM d, yyyy @ h:mm a').format(newDateTime)}',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.neonCyan, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      GlassTextField(
                        label: 'Reason for Rescheduling *',
                        hintText: 'e.g. Lead requested call next morning.',
                        controller: reasonController,
                        maxLines: 2,
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
                              onPressed: () => Navigator.of(ctx).pop(false),
                            ),
                            GradientPrimaryButton(
                              text: 'Confirm Reschedule',
                              icon: Icons.check_rounded,
                              gradient: AppColors.coralGradient,
                              onPressed: () {
                                if (reasonController.text.trim().isNotEmpty) {
                                  Navigator.of(ctx).pop(true);
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
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: GlassCard(
            blur: 24,
            opacity: 0.18,
            borderRadius: BorderRadius.circular(20),
            borderColor: AppColors.glassBorderHighlight,
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
                          gradient: AppColors.cyanGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Complete Callback',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A)),
                        ),
                      ),
                      DialogCloseButton(onPressed: () => Navigator.of(ctx).pop(false)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Record notes for completed callback with ${cb.leadName}:',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  GlassTextField(
                    label: 'Completion Notes *',
                    hintText: 'e.g. Connected successfully. Converted to customer.',
                    controller: notesController,
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
                          onPressed: () => Navigator.of(ctx).pop(false),
                        ),
                        GradientPrimaryButton(
                          text: 'Mark Completed',
                          icon: Icons.check_circle_rounded,
                          onPressed: () {
                            if (notesController.text.trim().isNotEmpty) {
                              Navigator.of(ctx).pop(true);
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

    if (confirmed == true && mounted) {
      final success = await context.read<CallbackProvider>().completeCallback(cb.id, notesController.text.trim());
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Callback marked as completed.'), backgroundColor: AppColors.success),
        );
      }
    }
  }

  Future<void> _callLead(CallbackModel cb) async {
    final recProv = context.read<RecordingProvider>();
    final callProv = context.read<CallProvider>();
    await recProv.ensurePermissions();
    await recProv.startRecording(
      leadId: cb.leadId,
      leadName: cb.leadName,
      leadPhone: cb.leadPhone,
    );
    await callProv.initiateCall(cb.leadId, cb.leadPhone);
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CallOutcomeDialog(
        leadId: cb.leadId,
        leadName: cb.leadName,
        leadPhone: cb.leadPhone,
      ),
    ).then((_) {
      if (!mounted) return;
      context.read<CallbackProvider>().fetchCallbacks(status: _tabs[_tabController.index]);
    });
  }

  Color _getCallbackColor(String status) {
    switch (status.toUpperCase()) {
      case 'OVERDUE':
        return AppColors.neonCoral;
      case 'DUE':
        return const Color(0xFFF59E0B);
      case 'COMPLETED':
        return const Color(0xFF10B981);
      default:
        return AppColors.neonCyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cbProvider = context.watch<CallbackProvider>();
    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 12 : 24,
            isMobile ? 6 : 16,
            isMobile ? 12 : 24,
            isMobile ? 10 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                              Text(
                                'Callback Scheduling & Reminders',
                                style: GoogleFonts.inter(
                                  fontSize: isMobile ? 18 : 22,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Active follow-up queue with automated reminders and priority ordering',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.neonCyan),
                      onPressed: () => _fetchTabCallbacks(_tabs[_tabController.index]),
                      tooltip: 'Refresh Callbacks',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Frosted Glass Tabs
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.all(5),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: isMobile,
                  tabAlignment: isMobile ? TabAlignment.start : null,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonViolet.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                  tabs: const [
                    Tab(text: 'ALL'),
                    Tab(text: 'DUE TODAY'),
                    Tab(text: 'UPCOMING'),
                    Tab(text: 'OVERDUE'),
                    Tab(text: 'COMPLETED'),
                  ],
                ),
              ),
                const SizedBox(height: 16),

                // Callback List
                Expanded(
                  child: cbProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : cbProvider.callbacks.isEmpty
                          ? Center(
                              child: GlassCard(
                                blur: 16,
                                opacity: 0.12,
                                borderColor: AppColors.glassBorderHighlight,
                                padding: const EdgeInsets.all(36),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppColors.neonCyan.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.event_available_rounded, size: 44, color: AppColors.neonCyan),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'No Callbacks Found',
                                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'No callbacks scheduled in this category.',
                                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: cbProvider.callbacks.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final cb = cbProvider.callbacks[index];
                                final statusColor = _getCallbackColor(cb.status);

                                return GlassCard(
                                  blur: 20,
                                  opacity: 0.12,
                                  borderRadius: BorderRadius.circular(16),
                                  borderColor: AppColors.glassBorder,
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                            ),
                                            child: Icon(
                                              cb.status == 'OVERDUE' ? Icons.warning_amber_rounded : Icons.alarm_rounded,
                                              color: statusColor,
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Wrap(
                                                  spacing: 10,
                                                  runSpacing: 6,
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  children: [
                                                    Text(
                                                      cb.leadName,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w800,
                                                        color: const Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.neonCyan.withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
                                                      ),
                                                      child: Text(
                                                        cb.leadPhone,
                                                        style: GoogleFonts.robotoMono(
                                                          fontSize: 12,
                                                          color: AppColors.neonCyan,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                    AnimatedStatusBadge(label: cb.status, statusColor: statusColor),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Wrap(
                                                  spacing: 14,
                                                  runSpacing: 6,
                                                  children: [
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.schedule_rounded, size: 14, color: AppColors.neonViolet),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          'Scheduled: ${cb.scheduledAt.replaceAll('T', ' ').substring(0, 16)}',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w600,
                                                            color: const Color(0xFF475569),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          'Caller: ${cb.assignedEmployeeName}',
                                                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                if (cb.initialNotes.isNotEmpty) ...[
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    'Notes: ${cb.initialNotes}',
                                                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      if (cb.status != 'COMPLETED') ...[
                                        const SizedBox(height: 14),
                                        Divider(color: const Color(0xFFE2E8F0), height: 1),
                                        const SizedBox(height: 14),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            GradientPrimaryButton(
                                              text: 'Call Now',
                                              icon: Icons.phone_in_talk_rounded,
                                              gradient: AppColors.primaryGradient,
                                              onPressed: () => _callLead(cb),
                                            ),
                                            GlassSecondaryButton(
                                              text: 'Reschedule',
                                              icon: Icons.alarm_add_rounded,
                                              onPressed: () => _reschedule(cb),
                                            ),
                                            GlassSecondaryButton(
                                              text: 'Mark Complete',
                                              icon: Icons.check_circle_outline_rounded,
                                              onPressed: () => _complete(cb),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}
