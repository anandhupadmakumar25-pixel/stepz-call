import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/app_background.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/animated_status_badge.dart';
import '../../core/widgets/glass/recording_indicator.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/services/pdf_invoice_service.dart';
import '../../routes/app_routes.dart';
import '../../providers/lead_provider.dart';
import '../../providers/call_provider.dart';
import '../../providers/callback_provider.dart';
import '../../providers/recording_provider.dart';
import '../../providers/billing_provider.dart';
import '../../models/lead_model.dart';
import '../../models/quotation_model.dart';
import '../../models/invoice_model.dart';
import '../calls/call_outcome_dialog.dart';
import '../quotations/quotation_form_dialog.dart';
import '../quotations/quotation_detail_dialog.dart';
import '../billing/record_payment_dialog.dart';
import 'edit_lead_dialog.dart';

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
    final recordingProvider = context.read<RecordingProvider>();
    final billingProvider = context.read<BillingProvider>();

    _lead = await leadProvider.fetchLeadDetail(widget.leadId);
    await callProvider.fetchCalls(leadId: widget.leadId);
    await callbackProvider.fetchCallbacks(status: 'ALL');
    await recordingProvider.fetchRecordings(leadId: widget.leadId);
    await billingProvider.fetchQuotations(leadId: widget.leadId);
    await billingProvider.fetchInvoices(leadId: widget.leadId);
    setState(() => _isLoading = false);
  }

  Future<void> _initiateCall() async {
    if (_lead == null) return;
    final callProvider = context.read<CallProvider>();
    final recordingProvider = context.read<RecordingProvider>();

    await recordingProvider.ensurePermissions();
    await recordingProvider.startRecording(
      leadId: _lead!.id,
      leadName: _lead!.fullName,
      leadPhone: _lead!.normalizedPhone,
    );

    await callProvider.launchDialer(_lead!.normalizedPhone);

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

  void _openEditDialog() async {
    if (_lead == null) return;
    final updated = await showDialog<LeadModel>(
      context: context,
      builder: (_) => EditLeadDialog(lead: _lead!),
    );
    if (updated != null && mounted) {
      setState(() => _lead = updated);
      _loadData();
    }
  }

  void _openQuotationDialog() {
    if (_lead == null) return;
    showDialog(
      context: context,
      builder: (_) => QuotationFormDialog(lead: _lead),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final calls = context.watch<CallProvider>().calls;
    final recordings = context.watch<RecordingProvider>().recordings.where((r) => r.leadId == widget.leadId).toList();
    final billing = context.watch<BillingProvider>();
    final quotes = billing.quotations.where((q) => q.leadId == widget.leadId).toList();
    final invoices = billing.invoices.where((inv) => inv.leadId == widget.leadId).toList();
    final isMobile = ResponsiveLayout.isMobile(context);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_lead == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: GlassCard(
            blur: 16,
            opacity: 0.95,
            borderColor: const Color(0xFFE2E8F0),
            padding: const EdgeInsets.all(32),
            child: Text(
              'Lead could not be found or you do not have permission.',
              style: GoogleFonts.inter(color: const Color(0xFF64748B)),
            ),
          ),
        ),
      );
    }

    final lead = _lead!;
    final isInterested = lead.status == 'INTERESTED';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: AppBackground(
        preset: AppBackgroundPreset.pastelSky,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Nav Row
                Row(
                  children: [
                    const AppBackButton(fallbackRoute: AppRoutes.leads),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        lead.fullName,
                        style: GoogleFonts.inter(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB), size: 20),
                        onPressed: _loadData,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Interested Glowing Banner
                if (isInterested) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Customer is Marked as INTERESTED!',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF065F46)),
                              ),
                              Text(
                                'Quickly create a custom quotation / estimate and send it directly via WhatsApp.',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF047857)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GradientPrimaryButton(
                          text: 'Create Quotation',
                          icon: Icons.request_quote_rounded,
                          gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
                          onPressed: _openQuotationDialog,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Customer Profile Glass Card
                GlassCard(
                  blur: 20,
                  opacity: 0.95,
                  borderRadius: BorderRadius.circular(20),
                  borderColor: const Color(0xFFE2E8F0),
                  padding: EdgeInsets.all(isMobile ? 18 : 26),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: isMobile ? 48 : 56,
                            height: isMobile ? 48 : 56,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                lead.firstName.isNotEmpty ? lead.firstName[0].toUpperCase() : 'L',
                                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 10,
                                  runSpacing: 6,
                                  children: [
                                    Text(
                                      lead.fullName,
                                      style: GoogleFonts.inter(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                    ),
                                    AnimatedStatusBadge(
                                      label: lead.status,
                                      statusColor: isInterested ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                                    ),
                                    if (lead.branchName != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text('📍 ${lead.branchName}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                                      ),
                                    if (lead.categoryName != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                                        ),
                                        child: Text('🏷 ${lead.categoryName}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF8B5CF6))),
                                      ),
                                    if (lead.assignedToName != null && lead.assignedToName!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Text('👤 Assigned: ${lead.assignedToName}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 14,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.phone_rounded, size: 14, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 5),
                                        Text(
                                          lead.normalizedPhone,
                                          style: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                                        ),
                                      ],
                                    ),
                                    if (lead.email.isNotEmpty)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.email_outlined, size: 14, color: Color(0xFF64748B)),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              lead.email,
                                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (lead.city.isNotEmpty || lead.state.isNotEmpty)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              '${lead.city}${lead.city.isNotEmpty && lead.state.isNotEmpty ? ', ' : ''}${lead.state}',
                                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                if (lead.notes.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Notes: ${lead.notes}',
                                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155), fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(color: Color(0xFFE2E8F0), height: 1),
                      const SizedBox(height: 16),

                      // Actions Row
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          GradientPrimaryButton(
                            text: 'Call Customer (Launch Dialer)',
                            icon: Icons.phone_in_talk_rounded,
                            gradient: AppColors.primaryGradient,
                            onPressed: _initiateCall,
                          ),
                          GlassSecondaryButton(
                            text: 'Edit Lead Details',
                            icon: Icons.edit_note_rounded,
                            onPressed: _openEditDialog,
                          ),
                          GlassSecondaryButton(
                            text: 'Log Outcome Manually',
                            icon: Icons.check_circle_outline_rounded,
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => CallOutcomeDialog(
                                  leadId: lead.id,
                                  leadName: lead.fullName,
                                  phoneNumber: lead.normalizedPhone,
                                ),
                              ).then((_) => _loadData());
                            },
                          ),
                          GradientPrimaryButton(
                            text: 'Generate Quotation',
                            icon: Icons.request_quote_rounded,
                            gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
                            onPressed: _openQuotationDialog,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // QUOTATIONS & INVOICES SECTION FOR THIS LEAD
                Text(
                  'Quotations & Billing Records',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),

                if (quotes.isEmpty && invoices.isEmpty)
                  GlassCard(
                    blur: 16,
                    opacity: 0.95,
                    borderRadius: BorderRadius.circular(16),
                    borderColor: const Color(0xFFE2E8F0),
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 28, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('No Quotations or Invoices yet', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                                Text('Create an estimate to send pricing directly to the customer.', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                              ],
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text('Create Quote', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                          onPressed: _openQuotationDialog,
                        ),
                      ],
                    ),
                  )
                else ...[
                  // List Quotes
                  if (quotes.isNotEmpty) ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: quotes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final q = quotes[i];
                        return _buildLeadQuotationCard(q);
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  // List Invoices
                  if (invoices.isNotEmpty) ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: invoices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final inv = invoices[i];
                        return _buildLeadInvoiceCard(inv);
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
                const SizedBox(height: 14),

                // Call Recordings for this Lead
                if (recordings.isNotEmpty) ...[
                  Text(
                    'Associated Call Recordings',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recordings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      return GlassAudioPlayerWidget(
                        recording: recordings[i],
                        onDelete: () => context.read<RecordingProvider>().deleteRecording(recordings[i].id),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // Call History Audit Trail for this Lead
                Text(
                  'Call History & Attempt Timeline',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),
                GlassCard(
                  blur: 20,
                  opacity: 0.95,
                  borderRadius: BorderRadius.circular(20),
                  borderColor: const Color(0xFFE2E8F0),
                  padding: const EdgeInsets.all(18),
                  child: calls.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text('No call attempts logged for this lead yet.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: calls.length,
                          separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 16),
                          itemBuilder: (ctx, i) {
                            final call = calls[i];
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.phone_rounded, color: Color(0xFF2563EB), size: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          Text(
                                            call.outcome,
                                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF0F172A)),
                                          ),
                                          Text(
                                            '• ${call.createdAt.length >= 16 ? call.createdAt.substring(0, 16).replaceAll('T', ' ') : call.createdAt}',
                                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                          ),
                                          Text(
                                            '• ${call.durationSeconds}s',
                                            style: GoogleFonts.robotoMono(fontSize: 11, color: const Color(0xFF2563EB), fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                      if (call.notes.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(call.notes, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155))),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadQuotationCard(QuotationModel q) {
    return GlassCard(
      blur: 16,
      opacity: 0.95,
      borderRadius: BorderRadius.circular(14),
      borderColor: const Color(0xFFE2E8F0),
      padding: const EdgeInsets.all(14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.request_quote_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(q.quotationNumber, style: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: q.status == 'CONVERTED' ? const Color(0xFFEDE9FE) : const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          q.status,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: q.status == 'CONVERTED' ? const Color(0xFF6D28D9) : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('Total: ₹${q.grandTotal.toStringAsFixed(2)} • Date: ${q.date}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                ],
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              IconButton(
                icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 18),
                tooltip: 'Share via WhatsApp',
                onPressed: () => PdfInvoiceService.shareQuotationToWhatsApp(q),
              ),
              IconButton(
                icon: const Icon(Icons.print_outlined, color: Color(0xFF475569), size: 18),
                tooltip: 'Print / PDF',
                onPressed: () => PdfInvoiceService.printQuotation(q),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => QuotationDetailDialog(quotation: q),
                  ).then((_) => _loadData());
                },
                child: Text('View Details', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeadInvoiceCard(InvoiceModel inv) {
    final isPaid = inv.paymentStatus == 'PAID';
    return GlassCard(
      blur: 16,
      opacity: 0.95,
      borderRadius: BorderRadius.circular(14),
      borderColor: const Color(0xFFE2E8F0),
      padding: const EdgeInsets.all(14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isPaid ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPaid ? Icons.check_circle_rounded : Icons.receipt_rounded,
                  color: isPaid ? const Color(0xFF047857) : const Color(0xFFB45309),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(inv.invoiceNumber, style: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPaid ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          inv.paymentStatus,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isPaid ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total: ₹${inv.grandTotal.toStringAsFixed(2)} • Due: ₹${inv.balanceDue.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              IconButton(
                icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 18),
                tooltip: 'WhatsApp Receipt',
                onPressed: () => PdfInvoiceService.shareInvoiceToWhatsApp(inv),
              ),
              IconButton(
                icon: const Icon(Icons.print_outlined, color: Color(0xFF475569), size: 18),
                tooltip: 'Print / PDF',
                onPressed: () => PdfInvoiceService.printInvoice(inv),
              ),
              if (!isPaid)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => RecordPaymentDialog(invoice: inv),
                    ).then((_) => _loadData());
                  },
                  child: Text('Pay', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
