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
    final isMobile = ResponsiveLayout.isMobile(context);

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
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Customer Profile Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: isMobile ? 22 : 28,
                          backgroundColor: AppColors.accentVioletLight,
                          child: Text(
                            lead.firstName.isNotEmpty ? lead.firstName[0].toUpperCase() : 'L',
                            style: GoogleFonts.inter(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.w700, color: AppColors.accentViolet),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    lead.fullName,
                                    style: GoogleFonts.inter(fontSize: isMobile ? 17 : 20, fontWeight: FontWeight.w700),
                                  ),
                                  StatusBadge(status: lead.status),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.phone_outlined, size: 15, color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        lead.normalizedPhone,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                                      ),
                                    ],
                                  ),
                                  if (lead.email.isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.email_outlined, size: 15, color: AppColors.textSecondary),
                                        const SizedBox(width: 4),
                                        Text(lead.email, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  if (lead.city.isNotEmpty || lead.state.isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textMuted),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${lead.city}${lead.city.isNotEmpty && lead.state.isNotEmpty ? ', ' : ''}${lead.state}',
                                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 14),

                    // Overflow-Proof Action Buttons
                    if (isMobile)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            onPressed: _initiateCall,
                            icon: const Icon(Icons.phone, size: 18, color: Colors.white),
                            label: Text(
                              'Call Customer (Launch Dialer)',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
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
                            icon: const Icon(Icons.note_alt_outlined, size: 16),
                            label: const Text('Log Outcome Directly'),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: _initiateCall,
                              icon: const Icon(Icons.phone, size: 18, color: Colors.white),
                              label: Text(
                                'Call Customer (Launch Dialer)',
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
            const SizedBox(height: 20),

            // Call Attempts History & Scheduled Callbacks Sections
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildCallHistoryCard(calls)),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _buildCallbacksCard(callbacks)),
                ],
              )
            else ...[
              _buildCallHistoryCard(calls),
              const SizedBox(height: 16),
              _buildCallbacksCard(callbacks),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCallHistoryCard(List<dynamic> calls) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Call Attempts History', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${calls.length} logged', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 14),
            if (calls.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text('No call attempts logged yet for this lead.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: calls.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final call = calls[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatusBadge(status: call.outcome),
                              const SizedBox(width: 8),
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
                      const SizedBox(height: 6),
                      Text(
                        call.notes,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallbacksCard(List<dynamic> callbacks) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scheduled Callbacks', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            if (callbacks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text('No callbacks scheduled.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: callbacks.length,
                separatorBuilder: (_, __) => const Divider(height: 14),
                itemBuilder: (context, index) {
                  final cb = callbacks[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          StatusBadge(status: cb.status, isCallback: true),
                          Text(
                            cb.scheduledAt.isNotEmpty ? cb.scheduledAt.substring(0, 16).replaceAll('T', ' ') : '',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
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
    );
  }
}
