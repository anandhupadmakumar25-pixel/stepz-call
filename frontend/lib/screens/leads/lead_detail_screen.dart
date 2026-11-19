import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/services/pdf_invoice_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/date_range_filter_bar.dart';
import '../../core/widgets/glass/animated_status_badge.dart';
import '../../core/widgets/glass/app_background.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/recording_indicator.dart';
import '../../models/call_model.dart';
import '../../models/callback_model.dart';
import '../../models/invoice_model.dart';
import '../../models/lead_model.dart';
import '../../models/quotation_model.dart';
import '../../providers/billing_provider.dart';
import '../../providers/call_provider.dart';
import '../../providers/callback_provider.dart';
import '../../providers/lead_provider.dart';
import '../../providers/recording_provider.dart';
import '../../routes/app_routes.dart';
import '../billing/record_payment_dialog.dart';
import '../calls/call_outcome_dialog.dart';
import '../quotations/quotation_detail_dialog.dart';
import '../quotations/quotation_form_dialog.dart';
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
  String? _dateFrom;
  String? _dateTo;

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
    await Future.wait([
      callProvider.fetchCalls(leadId: widget.leadId),
      callbackProvider.fetchCallbacks(status: 'ALL'),
      recordingProvider.fetchRecordings(leadId: widget.leadId),
      billingProvider.fetchQuotations(leadId: widget.leadId),
      billingProvider.fetchInvoices(leadId: widget.leadId),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  bool _matchesDateRange(String rawDate) {
    if ((_dateFrom == null || _dateFrom!.isEmpty) &&
        (_dateTo == null || _dateTo!.isEmpty)) {
      return true;
    }
    if (rawDate.trim().isEmpty) return false;
    final dayStr = rawDate.trim().length >= 10
        ? rawDate.trim().substring(0, 10)
        : rawDate.trim();
    if (_dateFrom != null &&
        _dateFrom!.isNotEmpty &&
        dayStr.compareTo(_dateFrom!) < 0) {
      return false;
    }
    if (_dateTo != null &&
        _dateTo!.isNotEmpty &&
        dayStr.compareTo(_dateTo!) > 0) {
      return false;
    }
    return true;
  }

  String _formatDateTime(String raw) {
    if (raw.isEmpty) return '—';
    if (raw.length >= 16) {
      return raw.substring(0, 16).replaceAll('T', ' ');
    }
    return raw;
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
    final allCalls = context.watch<CallProvider>().calls;
    final allRecordings = context
        .watch<RecordingProvider>()
        .recordings
        .where((r) => r.leadId == widget.leadId)
        .toList();
    final allCallbacks = context
        .watch<CallbackProvider>()
        .callbacks
        .where((c) => c.leadId == widget.leadId)
        .toList();
    final billing = context.watch<BillingProvider>();
    final allQuotes =
        billing.quotations.where((q) => q.leadId == widget.leadId).toList();
    final allInvoices =
        billing.invoices.where((inv) => inv.leadId == widget.leadId).toList();

    // Apply Date Filter across all lead history
    final calls = allCalls.where((c) => _matchesDateRange(c.createdAt)).toList();
    final recordings = allRecordings
        .where((r) => _matchesDateRange(r.createdAt.toIso8601String()))
        .toList();
    final callbacks =
        allCallbacks.where((c) => _matchesDateRange(c.scheduledAt)).toList();
    final quotes = allQuotes
        .where((q) => _matchesDateRange(q.date.isNotEmpty ? q.date : q.createdAt))
        .toList();
    final invoices = allInvoices
        .where((inv) =>
            _matchesDateRange(inv.date.isNotEmpty ? inv.date : inv.createdAt))
        .toList();

    final isMobile = ResponsiveLayout.isMobile(context);

    if (_isLoading && _lead == null) {
      return AppBackground(
        preset: AppBackgroundPreset.cleanEnterprise,
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final lead = _lead;
    if (lead == null) {
      return AppBackground(
        preset: AppBackgroundPreset.cleanEnterprise,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Lead not found.',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A))),
                const SizedBox(height: 12),
                const AppBackButton(fallbackRoute: AppRoutes.leads),
              ],
            ),
          ),
        ),
      );
    }

    final isInterested =
        lead.status == 'QUALIFIED' || lead.status == 'COMPLETED';
    final totalQuoted =
        quotes.fold<double>(0.0, (sum, q) => sum + q.grandTotal);
    final totalBilled =
        invoices.fold<double>(0.0, (sum, i) => sum + i.grandTotal);
    final totalDue =
        invoices.fold<double>(0.0, (sum, i) => sum + i.balanceDue);

    return AppBackground(
      preset: AppBackgroundPreset.cleanEnterprise,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.white.withValues(alpha: 0.92),
          elevation: 0,
          leadingWidth: 54,
          leading: const Padding(
            padding: EdgeInsets.only(left: 10),
            child: Center(child: AppBackButton(fallbackRoute: AppRoutes.leads)),
          ),
          title: Text(
            lead.fullName,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 16.5,
                color: const Color(0xFF0F172A)),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF334155)),
              onPressed: _loadData,
              tooltip: 'Refresh Lead History',
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: RefreshIndicator(
          color: const Color(0xFF047857),
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              isMobile ? 12 : 24,
              isMobile ? 10 : 16,
              isMobile ? 12 : 24,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Lead Profile & Quick Actions Card
                _buildLeadProfileCard(lead, isInterested, isMobile),
                const SizedBox(height: 12),

                // 2. Date Filter Bar (tracks everything on this page by date)
                GlassCard(
                  blur: 16,
                  opacity: 0.96,
                  borderRadius: BorderRadius.circular(14),
                  borderColor: const Color(0xFFE2E8F0),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 14,
                    vertical: 10,
                  ),
                  child: DateRangeFilterBar(
                    onChanged: (from, to) {
                      setState(() {
                        _dateFrom = from;
                        _dateTo = to;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Responsive 4-KPI Summary Strip
                _buildSummaryKpis(
                  callsCount: calls.length,
                  quotesCount: quotes.length,
                  totalQuoted: totalQuoted,
                  invoicesCount: invoices.length,
                  totalBilled: totalBilled,
                  totalDue: totalDue,
                  callbacksCount: callbacks.length,
                ),
                const SizedBox(height: 14),

                // 4. Quotations & Bills History (ExpansionTiles)
                _buildQuotationsAndBillsSection(quotes, invoices),
                const SizedBox(height: 14),

                // 5. Call History & Employee Attempts (ExpansionTiles)
                _buildCallHistorySection(calls),
                const SizedBox(height: 14),

                // 6. Scheduled Callbacks (ExpansionTiles)
                if (callbacks.isNotEmpty) ...[
                  _buildCallbacksSection(callbacks),
                  const SizedBox(height: 14),
                ],

                // 7. Associated Call Recordings
                if (recordings.isNotEmpty) ...[
                  Text(
                    'Call Recordings (${recordings.length})',
                    style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recordings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => GlassAudioPlayerWidget(
                      recording: recordings[i],
                      onDelete: () => context
                          .read<RecordingProvider>()
                          .deleteRecording(recordings[i].id),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadProfileCard(
      LeadModel lead, bool isInterested, bool isMobile) {
    return GlassCard(
      blur: 20,
      opacity: 0.96,
      borderRadius: BorderRadius.circular(18),
      borderColor: const Color(0xFFE2E8F0),
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: isMobile ? 44 : 52,
                height: isMobile ? 44 : 52,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    lead.firstName.isNotEmpty
                        ? lead.firstName[0].toUpperCase()
                        : 'L',
                    style: GoogleFonts.inter(
                        fontSize: isMobile ? 18 : 21,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
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
                      runSpacing: 6,
                      children: [
                        Text(
                          lead.fullName,
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 17 : 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        AnimatedStatusBadge(
                          label: lead.status,
                          statusColor: isInterested
                              ? const Color(0xFF10B981)
                              : const Color(0xFF2563EB),
                        ),
                        if (lead.branchName != null &&
                            lead.branchName!.isNotEmpty)
                          _buildTagChip(
                            Icons.storefront_outlined,
                            lead.branchName!,
                            const Color(0xFF2563EB),
                            const Color(0xFFEFF6FF),
                          ),
                        if (lead.assignedToName != null &&
                            lead.assignedToName!.isNotEmpty)
                          _buildTagChip(
                            Icons.person_outline_rounded,
                            'Assigned: ${lead.assignedToName!}',
                            const Color(0xFF047857),
                            const Color(0xFFECFDF5),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.phone_rounded,
                                size: 14, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            SelectableText(
                              lead.normalizedPhone,
                              style: GoogleFonts.robotoMono(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                        if (lead.email.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.email_outlined,
                                  size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(lead.email,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B))),
                            ],
                          ),
                        if (lead.city.isNotEmpty || lead.state.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                '${lead.city}${lead.city.isNotEmpty && lead.state.isNotEmpty ? ", " : ""}${lead.state}',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (lead.notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Notes: ${lead.notes}',
                        style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF475569),
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GradientPrimaryButton(
                text: 'Call Customer',
                icon: Icons.phone_in_talk_rounded,
                height: 36,
                borderRadius: 10,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onPressed: _initiateCall,
              ),
              _buildUniformActionBtn(
                icon: Icons.edit_note_rounded,
                label: 'Edit Lead',
                color: const Color(0xFF334155),
                bgColor: Colors.white,
                borderColor: const Color(0xFFCBD5E1),
                onPressed: _openEditDialog,
              ),
              _buildUniformActionBtn(
                icon: Icons.check_circle_outline_rounded,
                label: 'Log Outcome',
                color: const Color(0xFFB45309),
                bgColor: const Color(0xFFFFFBEB),
                borderColor: const Color(0xFFFDE68A),
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
                text: 'Generate Quote',
                icon: Icons.request_quote_rounded,
                height: 36,
                borderRadius: 10,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)]),
                onPressed: _openQuotationDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryKpis({
    required int callsCount,
    required int quotesCount,
    required double totalQuoted,
    required int invoicesCount,
    required double totalBilled,
    required double totalDue,
    required int callbacksCount,
  }) {
    final k1 = _buildKpiTile(
      icon: Icons.phone_in_talk_rounded,
      label: 'Call Attempts',
      value: '$callsCount',
      subtitle: 'In selected period',
      color: const Color(0xFF2563EB),
      bg: const Color(0xFFEFF6FF),
    );
    final k2 = _buildKpiTile(
      icon: Icons.request_quote_rounded,
      label: 'Quotations ($quotesCount)',
      value: '₹${totalQuoted.toStringAsFixed(0)}',
      subtitle: 'Estimated total',
      color: const Color(0xFF7C3AED),
      bg: const Color(0xFFF5F3FF),
    );
    final k3 = _buildKpiTile(
      icon: Icons.receipt_long_rounded,
      label: 'Bills / Invoices ($invoicesCount)',
      value: '₹${totalBilled.toStringAsFixed(0)}',
      subtitle: totalDue > 0
          ? 'Due ₹${totalDue.toStringAsFixed(0)}'
          : 'All cleared',
      color: totalDue > 0 ? const Color(0xFFD97706) : const Color(0xFF059669),
      bg: totalDue > 0 ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
    );
    final k4 = _buildKpiTile(
      icon: Icons.event_available_rounded,
      label: 'Callbacks',
      value: '$callbacksCount',
      subtitle: 'Scheduled follow-ups',
      color: const Color(0xFF0284C7),
      bg: const Color(0xFFF0F9FF),
    );

    return LayoutBuilder(
      builder: (ctx, constraints) {
        if (constraints.maxWidth >= 760) {
          return Row(
            children: [
              Expanded(child: k1),
              const SizedBox(width: 10),
              Expanded(child: k2),
              const SizedBox(width: 10),
              Expanded(child: k3),
              const SizedBox(width: 10),
              Expanded(child: k4),
            ],
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: k1),
                const SizedBox(width: 8),
                Expanded(child: k2),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: k3),
                const SizedBox(width: 8),
                Expanded(child: k4),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiTile({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration:
                BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationsAndBillsSection(
      List<QuotationModel> quotes, List<InvoiceModel> invoices) {
    return GlassCard(
      blur: 18,
      opacity: 0.96,
      borderRadius: BorderRadius.circular(16),
      borderColor: const Color(0xFFE2E8F0),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Quotations & Bills (${quotes.length + invoices.length})',
                  style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A)),
                ),
              ),
              SizedBox(
                height: 32,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: Text('New Quote',
                      style: GoogleFonts.inter(
                          fontSize: 11.5, fontWeight: FontWeight.w700)),
                  onPressed: _openQuotationDialog,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (quotes.isEmpty && invoices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No quotations or bills recorded in this date range.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ),
            )
          else ...[
            ...quotes.map((q) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildLeadQuotationExpansionTile(q),
                )),
            ...invoices.map((inv) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildLeadInvoiceExpansionTile(inv),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildLeadQuotationExpansionTile(QuotationModel q) {
    final isConverted = q.status == 'CONVERTED';
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          collapsedShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.request_quote_rounded,
                color: Color(0xFF2563EB), size: 18),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  q.quotationNumber,
                  style: GoogleFonts.robotoMono(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusPill(
                q.status,
                isConverted
                    ? const Color(0xFF6D28D9)
                    : const Color(0xFF1D4ED8),
                isConverted
                    ? const Color(0xFFEDE9FE)
                    : const Color(0xFFDBEAFE),
              ),
            ],
          ),
          subtitle: Text(
            'Total: ₹${q.grandTotal.toStringAsFixed(2)} · Date: ${q.date}',
            style: GoogleFonts.inter(
                fontSize: 11, color: const Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            const Divider(color: Color(0xFFE2E8F0), height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildUniformActionBtn(
                    icon: Icons.chat_rounded,
                    label: 'WhatsApp',
                    color: const Color(0xFF15803D),
                    bgColor: const Color(0xFFDCFCE7),
                    borderColor: const Color(0xFF86EFAC),
                    onPressed: () => PdfInvoiceService.shareQuotationToWhatsApp(q),
                  ),
                  _buildUniformActionBtn(
                    icon: Icons.print_outlined,
                    label: 'PDF / Print',
                    color: const Color(0xFF334155),
                    bgColor: Colors.white,
                    borderColor: const Color(0xFFCBD5E1),
                    onPressed: () => PdfInvoiceService.printQuotation(q),
                  ),
                  _buildUniformActionBtn(
                    icon: Icons.visibility_outlined,
                    label: 'View Details',
                    color: const Color(0xFF1D4ED8),
                    bgColor: const Color(0xFFEFF6FF),
                    borderColor: const Color(0xFFBFDBFE),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => QuotationDetailDialog(quotation: q),
                      ).then((_) => _loadData());
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadInvoiceExpansionTile(InvoiceModel inv) {
    final isPaid = inv.paymentStatus == 'PAID';
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          collapsedShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color:
                  isPaid ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              isPaid ? Icons.check_circle_rounded : Icons.receipt_rounded,
              color:
                  isPaid ? const Color(0xFF047857) : const Color(0xFFB45309),
              size: 18,
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  inv.invoiceNumber,
                  style: GoogleFonts.robotoMono(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusPill(
                inv.paymentStatus,
                isPaid ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                isPaid ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
              ),
            ],
          ),
          subtitle: Text(
            'Total: ₹${inv.grandTotal.toStringAsFixed(2)} · Due: ₹${inv.balanceDue.toStringAsFixed(2)} · ${inv.date}',
            style: GoogleFonts.inter(
                fontSize: 11, color: const Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            const Divider(color: Color(0xFFE2E8F0), height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildUniformActionBtn(
                    icon: Icons.chat_rounded,
                    label: 'WhatsApp',
                    color: const Color(0xFF15803D),
                    bgColor: const Color(0xFFDCFCE7),
                    borderColor: const Color(0xFF86EFAC),
                    onPressed: () =>
                        PdfInvoiceService.shareInvoiceToWhatsApp(inv),
                  ),
                  _buildUniformActionBtn(
                    icon: Icons.print_outlined,
                    label: 'PDF / Print',
                    color: const Color(0xFF334155),
                    bgColor: Colors.white,
                    borderColor: const Color(0xFFCBD5E1),
                    onPressed: () => PdfInvoiceService.printInvoice(inv),
                  ),
                  if (!isPaid)
                    SizedBox(
                      height: 34,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.payments_outlined, size: 14),
                        label: Text('Record Payment',
                            style: GoogleFonts.inter(
                                fontSize: 11.5, fontWeight: FontWeight.w700)),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => RecordPaymentDialog(invoice: inv),
                          ).then((_) => _loadData());
                        },
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

  Widget _buildCallHistorySection(List<CallAttemptModel> calls) {
    return GlassCard(
      blur: 18,
      opacity: 0.96,
      borderRadius: BorderRadius.circular(16),
      borderColor: const Color(0xFFE2E8F0),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded,
                  size: 18, color: Color(0xFF047857)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Call History & Employee Logs (${calls.length})',
                  style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (calls.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No call attempts logged in this date range.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: calls.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _buildCallExpansionTile(calls[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildCallExpansionTile(CallAttemptModel call) {
    final outcomeText = call.outcome.replaceAll('_', ' ');
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          collapsedShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.phone_rounded,
                color: Color(0xFF2563EB), size: 17),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  call.employeeName.isNotEmpty
                      ? call.employeeName
                      : 'Staff Member',
                  style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusPill(
                outcomeText,
                const Color(0xFF1D4ED8),
                const Color(0xFFDBEAFE),
              ),
            ],
          ),
          subtitle: Text(
            '${_formatDateTime(call.createdAt)} · Duration: ${call.durationSeconds}s',
            style: GoogleFonts.inter(
                fontSize: 11, color: const Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            const Divider(color: Color(0xFFE2E8F0), height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                call.notes.isNotEmpty
                    ? 'Notes: ${call.notes}'
                    : 'No call remarks recorded.',
                style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallbacksSection(List<CallbackModel> callbacks) {
    return GlassCard(
      blur: 18,
      opacity: 0.96,
      borderRadius: BorderRadius.circular(16),
      borderColor: const Color(0xFFE2E8F0),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.alarm_on_rounded,
                  size: 18, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Text(
                'Scheduled Callbacks (${callbacks.length})',
                style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: callbacks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final cb = callbacks[i];
              final isDone = cb.status == 'COMPLETED';
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    collapsedShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    leading: Icon(
                      Icons.event_rounded,
                      color: isDone
                          ? const Color(0xFF059669)
                          : const Color(0xFFD97706),
                      size: 20,
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            cb.assignedEmployeeName.isNotEmpty
                                ? cb.assignedEmployeeName
                                : 'Assigned Staff',
                            style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusPill(
                          cb.status,
                          isDone
                              ? const Color(0xFF047857)
                              : const Color(0xFFD97706),
                          isDone
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFFFBEB),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'Scheduled: ${_formatDateTime(cb.scheduledAt)}',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    children: [
                      const Divider(color: Color(0xFFE2E8F0), height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          cb.completionNotes.isNotEmpty
                              ? cb.completionNotes
                              : (cb.initialNotes.isNotEmpty
                                  ? cb.initialNotes
                                  : 'No callback notes.'),
                          style: GoogleFonts.inter(
                              fontSize: 12, color: const Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(
      IconData icon, String label, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String text, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
            fontSize: 9.5, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  Widget _buildUniformActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 15, color: color),
        label: Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor),
          backgroundColor: bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
