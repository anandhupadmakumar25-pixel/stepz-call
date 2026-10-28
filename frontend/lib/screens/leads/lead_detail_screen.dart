import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../providers/lead_provider.dart';
import '../../providers/call_provider.dart';
import '../../providers/callback_provider.dart';
import '../../models/lead_model.dart';
import '../calls/call_outcome_dialog.dart';

class LeadDetailScreen extends StatefulWidget {
  final String leadId;

  const LeadDetailScreen({super.key, required this.leadId});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  LeadModel? _lead;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final leadProvider = context.read<LeadProvider>();
    final callProvider = context.read<CallProvider>();
    final callbackProvider = context.read<CallbackProvider>();

    _lead = await leadProvider.fetchLeadDetail(widget.leadId);
    await callProvider.fetchCalls(leadId: widget.leadId);
    await callbackProvider.fetchCallbacks(status: 'ALL');
    setState(() => _isLoading = false);
  }

  Future<void> _initiateCall() async {
    if (_lead == null) return;
    final callProvider = context.read<CallProvider>();

    // 1. Launch native Android dialer
    await callProvider.launchDialer(_lead!.normalizedPhone);

    // 2. Open call outcome dialog automatically upon returning
    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => CallOutcomeDialog(
          leadId: _lead!.id,
          leadName: _lead!.fullName,
          phoneNumber: _lead!.normalizedPhone,
        ),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final calls = context.watch<CallProvider>().calls;
    final callbacks = context.watch<CallbackProvider>().callbacks.where((c) => c.leadId == widget.leadId).toList();
    final isDesktop = ResponsiveLayout.isDesktop(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Loading Lead...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_lead == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Lead Not Found')),
        body: const Center(child: Text('Lead could not be found or you do not have permission to access it.')),
      );
    }

    final lead = _lead!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(lead.fullName, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Customer Banner with Call Action
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.accentVioletLight,
                          child: Text(
                            lead.firstName.isNotEmpty ? lead.firstName[0].toUpperCase() : 'L',
                            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.accentViolet),
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
                                    lead.fullName,
                                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(width: 12),
                                  StatusBadge(status: lead.status),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.phone_outlined, size: 16, color: AppColors.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    lead.normalizedPhone,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                                  ),
                                  if (lead.email.isNotEmpty) ...[
                                    const SizedBox(width: 16),
                                    const Icon(Icons.email_outlined, size: 16, color: AppColors.textSecondary),
                                    const SizedBox(width: 6),
                                    Text(lead.email, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                                  ],
                                ],
                              ),
                              if (lead.city.isNotEmpty || lead.state.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${lead.city}${lead.city.isNotEmpty && lead.state.isNotEmpty ? ', ' : ''}${lead.state}',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Primary Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _initiateCall,
                            icon: const Icon(Icons.phone, size: 20, color: Colors.white),
                            label: Text(
                              'Call Customer (Launch Android Dialer)',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16)),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => CallOutcomeDialog(
                                leadId: lead.id,
                                leadName: lead.fullName,
                                phoneNumber: lead.normalizedPhone,
                              ),
                            ).then((val) {
                              if (val == true) _loadData();
                            });
                          },
                          icon: const Icon(Icons.note_alt_outlined, size: 18),
                          label: const Text('Log Outcome Directly'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Call Attempts History & Scheduled Callbacks
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Call History Timeline
                Expanded(
                  flex: isDesktop ? 3 : 1,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Call Attempts History', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                              Text('${calls.length} calls logged', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (calls.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Text('No call attempts logged yet for this lead.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: calls.length,
                              separatorBuilder: (_, __) => const Divider(height: 20),
                              itemBuilder: (context, index) {
                                final call = calls[index];
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            StatusBadge(status: call.outcome),
                                            const SizedBox(width: 10),
                                            Text(
                                              'by ${call.employeeName}',
                                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          call.createdAt.isNotEmpty ? call.createdAt.substring(0, 10) : '',
                                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      call.notes,
                                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                                    ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (isDesktop) ...[
                  const SizedBox(width: 16),
                  // Linked Callbacks
                  Expanded(
                    flex: 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Scheduled Callbacks', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 16),
                            if (callbacks.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: Text('No callbacks scheduled.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: callbacks.length,
                                separatorBuilder: (_, __) => const Divider(height: 16),
                                itemBuilder: (context, index) {
                                  final cb = callbacks[index];
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          StatusBadge(status: cb.status, isCallback: true),
                                          Text(
                                            cb.scheduledAt.isNotEmpty ? cb.scheduledAt.substring(0, 16).replaceAll('T', ' ') : '',
                                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        cb.initialNotes.isNotEmpty ? cb.initialNotes : 'No notes',
                                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
