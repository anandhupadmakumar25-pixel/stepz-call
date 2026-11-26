import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/action_loader.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/app_back_button.dart';
import '../../models/plan_model.dart';
import '../../routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';

class PlatformBillingScreen extends StatefulWidget {
  const PlatformBillingScreen({super.key});

  @override
  State<PlatformBillingScreen> createState() => _PlatformBillingScreenState();
}

class _PlatformBillingScreenState extends State<PlatformBillingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().fetchBillingOverview();
      context.read<CompanyProvider>().fetchCompanies();
    });
  }

  @override
  Widget build(BuildContext context) {
    final compProv = context.watch<CompanyProvider>();
    final billing = compProv.billingOverview;
    final companies = compProv.companies;
    final isMobile = ResponsiveLayout.isMobile(context);

    final mrr = (billing?['monthly_recurring_revenue'] as num?)?.toDouble() ?? 0.0;
    final arr = (billing?['annual_recurring_revenue'] as num?)?.toDouble() ?? (mrr * 12);
    final actualCollected = (billing?['actual_collected_total'] as num?)?.toDouble() ?? 0.0;
    final actualYtd = (billing?['actual_collected_ytd'] as num?)?.toDouble() ?? 0.0;
    final totalDue = (billing?['total_due'] as num?)?.toDouble() ?? 0.0;
    final totalCompanies = billing?['total_companies'] ?? companies.length;
    final activeSubs = billing?['active_subscribers'] ?? companies.where((c) => c.isActive).length;
    final suspendedSubs = billing?['suspended_subscribers'] ?? (totalCompanies - activeSubs);
    final breakdown = (billing?['plan_breakdown'] as List<dynamic>?) ?? [];
    final ownerBreakdown = (billing?['owner_breakdown'] as List<dynamic>?) ?? [];
    final tenantBreakdown = (billing?['tenant_breakdown'] as List<dynamic>?) ?? [];
    final receipts = (billing?['receipts'] as List<dynamic>?) ?? [];
    final hasFx = billing?['has_fx_conversion'] == true;
    final fxMrrText = billing?['fx_mrr_text']?.toString() ?? '';
    final fxCollectedText = billing?['fx_collected_text']?.toString() ?? '';
    final fxDueText = billing?['fx_due_text']?.toString() ?? '';
    final targetCurr = billing?['currency']?.toString() ??
        (context.watch<AuthProvider>().currentUser?.companyCurrency ?? 'INR');
    final rawSym = billing?['currency_symbol']?.toString() ??
        (context.watch<AuthProvider>().currentUser?.companyCurrencySymbol ?? '₹');
    final sym = rawSym.length > 1 ? '$rawSym ' : rawSym;

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Back Button
              Row(
                children: [
                  const AppBackButton(fallbackRoute: AppRoutes.dashboard),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Platform Billing & Revenue',
                                style: GoogleFonts.inter(
                                  fontSize: isMobile ? 18 : 24,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF10B981)),
                              ),
                              child: Text(
                                'SaaS Metrics',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF047857)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Real-time overview of recurring tenant revenue, active subscriptions, and plan distribution',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // KPI Cards Row (Clickable for Super Admin & Tenant Breakdown)
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Actual Collected (Realized)',
                      value: '$sym${actualCollected.toStringAsFixed(0)}',
                      subtitle: 'This Year: $sym${actualYtd.toStringAsFixed(0)} · Tap for details',
                      icon: Icons.account_balance_wallet_rounded,
                      color: const Color(0xFF047857),
                      onTap: () => _showBreakdownDialog(
                        sym: sym,
                        targetCurr: targetCurr,
                        ownerBreakdown: ownerBreakdown,
                        tenantBreakdown: tenantBreakdown,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Pending / Due',
                      value: '$sym${totalDue.toStringAsFixed(0)}',
                      subtitle: 'Unpaid tenant balances',
                      icon: Icons.pending_actions_rounded,
                      color: totalDue > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                      onTap: () => _showBreakdownDialog(
                        sym: sym,
                        targetCurr: targetCurr,
                        ownerBreakdown: ownerBreakdown,
                        tenantBreakdown: tenantBreakdown,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Active MRR (Proj. Annual)',
                      value: '$sym${mrr.toStringAsFixed(0)}/mo',
                      subtitle: 'Proj. 12m (Active): $sym${arr.toStringAsFixed(0)}',
                      icon: Icons.trending_up_rounded,
                      color: const Color(0xFFD4AF37),
                      onTap: () => _showBreakdownDialog(
                        sym: sym,
                        targetCurr: targetCurr,
                        ownerBreakdown: ownerBreakdown,
                        tenantBreakdown: tenantBreakdown,
                      ),
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Active Subscribers',
                        value: '$activeSubs',
                        subtitle: '$totalCompanies total · $suspendedSubs suspended',
                        icon: Icons.business_rounded,
                        color: const Color(0xFF2563EB),
                        onTap: () => _showBreakdownDialog(
                          sym: sym,
                          targetCurr: targetCurr,
                          ownerBreakdown: ownerBreakdown,
                          tenantBreakdown: tenantBreakdown,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (hasFx && (fxMrrText.isNotEmpty || fxCollectedText.isNotEmpty || fxDueText.isNotEmpty)) ...[
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      dense: true,
                      leading: const Icon(Icons.currency_exchange_rounded, size: 17, color: Color(0xFFB45309)),
                      title: Text(
                        'FX Conversion Breakdown ($targetCurr)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)),
                      ),
                      children: [
                        if (fxCollectedText.isNotEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Collected: $fxCollectedText', style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFB45309))),
                          ),
                        if (fxDueText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Pending Due: $fxDueText', style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626))),
                            ),
                          ),
                        if (fxMrrText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Active MRR: $fxMrrText', style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFB45309))),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Plan Breakdown & Tenant Subscriptions
              Expanded(
                child: ListView(
                  children: [
                    if (breakdown.isNotEmpty) ...[
                      Text('Plan Revenue Breakdown', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: breakdown.map((item) {
                          final pName = item['plan_name'] ?? 'Tier';
                          final pRev = (item['monthly_revenue'] as num?)?.toDouble() ?? 0.0;
                          final pSubs = item['active_subscribers'] ?? 0;

                          return Container(
                            width: isMobile ? double.infinity : 220,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                const SizedBox(height: 6),
                                Text('$sym${pRev.toStringAsFixed(0)}/mo', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF047857))),
                                Text('$pSubs active companies', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    if (ownerBreakdown.isNotEmpty) ...[
                      Text('Individual Earnings by Super Admin / Master Admin ($targetCurr)', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: ownerBreakdown.map((o) {
                          final oAct = o['active_tenants'] ?? 0;
                          final oSusp = o['suspended_tenants'] ?? 0;
                          final oCol = (o['actual_collected'] as num?)?.toDouble() ?? 0.0;
                          final oDue = (o['due_amount'] as num?)?.toDouble() ?? 0.0;
                          final oMrr = (o['active_mrr'] as num?)?.toDouble() ?? 0.0;
                          return Container(
                            width: isMobile ? double.infinity : 260,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${o['owner_name']}', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('$oAct Active · $oSusp Suspended', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                const SizedBox(height: 8),
                                Text('Collected: $sym${oCol.toStringAsFixed(0)}', style: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF047857))),
                                Text('Due: $sym${oDue.toStringAsFixed(0)} · MRR: $sym${oMrr.toStringAsFixed(0)}/mo', style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w600, color: oDue > 0 ? const Color(0xFFDC2626) : const Color(0xFF475569))),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    Builder(
                      builder: (_) {
                        final pendingDueTenants = tenantBreakdown
                            .where((t) => ((t['due_amount'] as num?)?.toDouble() ?? 0.0) > 0)
                            .toList();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pending Dues (${pendingDueTenants.length})',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 12),
                            GlassCard(
                              opacity: 0.95,
                              borderRadius: BorderRadius.circular(18),
                              padding: EdgeInsets.all(isMobile ? 14 : 18),
                              child: pendingDueTenants.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              'All tenants are paid up — no pending dues.',
                                              style: GoogleFonts.inter(color: const Color(0xFF047857), fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: pendingDueTenants.length,
                                      separatorBuilder: (_, __) => const Divider(color: Color(0xFFE2E8F0), height: 16),
                                      itemBuilder: (ctx, i) {
                                        final t = pendingDueTenants[i];
                                        final isAct = t['status'] == 'ACTIVE';
                                        final tDue = (t['due_amount'] as num?)?.toDouble() ?? 0.0;
                                        return Wrap(
                                          spacing: 12,
                                          runSpacing: 8,
                                          alignment: WrapAlignment.spaceBetween,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEF2F2),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: const Icon(Icons.apartment_rounded, size: 20, color: Color(0xFFDC2626)),
                                                ),
                                                const SizedBox(width: 12),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('${t['name']}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                                    Text('${t['owner_name']} • ${t['plan_name']} (${t['billing_cycle']})', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEF2F2),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                                  ),
                                                  child: Text('Due: $sym${tDue.toStringAsFixed(0)}', style: GoogleFonts.robotoMono(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626))),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isAct ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: isAct ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                                  ),
                                                  child: Text(
                                                    isAct ? 'Active' : 'Suspended',
                                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isAct ? const Color(0xFF047857) : const Color(0xFFDC2626)),
                                                  ),
                                                ),
                                                OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    visualDensity: VisualDensity.compact,
                                                  ),
                                                  icon: const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFFB45309)),
                                                  label: Text('Send Bill', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFFB45309))),
                                                  onPressed: () => ActionLoader.run(
                                                    context,
                                                    message: 'Generating Bill PDF...',
                                                    task: () => _printSubscriptionReceiptPdf({
                                                      'receipt_number': 'PROFORMA',
                                                      'company_name': t['name'],
                                                      'plan_name': t['plan_name'],
                                                      'billing_cycle': t['billing_cycle'],
                                                      'currency': t['plan_currency'] ?? targetCurr,
                                                      'amount_paid': 0,
                                                      'due_amount': tDue,
                                                      'converted_paid': 0,
                                                      'payment_status': 'DUE',
                                                      'payment_mode': 'PENDING',
                                                      'approved_by_name': t['owner_name'] ?? 'Admin',
                                                      'created_at': DateTime.now().toIso8601String(),
                                                      'notes': 'Proforma subscription bill for pending payment',
                                                    }, sym, targetCurr),
                                                  ),
                                                ),
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF059669),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    visualDensity: VisualDensity.compact,
                                                  ),
                                                  icon: const Icon(Icons.payments_rounded, size: 14),
                                                  label: Text('Mark Paid', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                                  onPressed: () => _showCollectPaymentDialog(t, sym),
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    Text('Subscription Receipts & Bills (${receipts.length})', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                    const SizedBox(height: 12),
                    GlassCard(
                      opacity: 0.95,
                      borderRadius: BorderRadius.circular(18),
                      padding: EdgeInsets.all(isMobile ? 14 : 18),
                      child: receipts.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text('No subscription receipts generated yet.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: receipts.length,
                              separatorBuilder: (_, __) => const Divider(color: Color(0xFFE2E8F0), height: 14),
                              itemBuilder: (ctx, i) {
                                final r = receipts[i] as Map<String, dynamic>;
                                final origCurr = (r['currency'] ?? 'INR').toString();
                                final origSym = PlanModel.getSymbolForCurrency(origCurr);
                                final amtPaid = (r['amount_paid'] as num?)?.toDouble() ?? 0.0;
                                final convPaid = (r['converted_paid'] as num?)?.toDouble() ?? 0.0;
                                final rDue = (r['due_amount'] as num?)?.toDouble() ?? 0.0;
                                final showFxLine = origCurr != targetCurr && amtPaid > 0;
                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${r['receipt_number']} · ${r['company_name']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                                        Text(
                                          '${r['plan_name']} (${r['billing_cycle']}) · ${r['payment_mode']}${r['transaction_ref'] != null && r['transaction_ref'].toString().isNotEmpty ? " • Ref: ${r['transaction_ref']}" : ""} · By: ${r['approved_by_name']}${r['created_at'] != null && r['created_at'].toString().length >= 10 ? " · Issued: ${r['created_at'].toString().substring(0, 10)}" : ""}',
                                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              amtPaid > 0 ? '$origSym ${amtPaid.toStringAsFixed(0)}' : 'DUE: $origSym ${rDue.toStringAsFixed(0)}',
                                              style: GoogleFonts.robotoMono(fontSize: 12.5, fontWeight: FontWeight.w800, color: amtPaid > 0 ? const Color(0xFF047857) : const Color(0xFFDC2626)),
                                            ),
                                            if (showFxLine)
                                              Text(
                                                'FX ≈ $sym${convPaid.toStringAsFixed(0)}',
                                                style: GoogleFonts.robotoMono(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFB45309)),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 10),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 15, color: Color(0xFF1D4ED8)),
                                          label: Text('Receipt PDF', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8))),
                                          onPressed: () => ActionLoader.run(
                                            context,
                                            message: 'Generating Receipt PDF...',
                                            task: () => _printSubscriptionReceiptPdf(r, sym, targetCurr),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCollectPaymentDialog(Map<String, dynamic> tenant, String displaySym) {
    final planCurr = (tenant['plan_currency'] ?? 'INR').toString();
    final currSym = PlanModel.getSymbolForCurrency(planCurr);
    final defaultAmt = ((tenant['due_amount'] as num?)?.toDouble() ?? 0.0) > 0
        ? (tenant['due_amount'] as num).toDouble()
        : ((tenant['monthly_rate_raw'] as num?)?.toDouble() ?? 0.0);
    final amountCtrl = TextEditingController(text: defaultAmt > 0 ? defaultAmt.toStringAsFixed(2) : '');
    final dueCtrl = TextEditingController(text: '0.00');
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController(text: 'Subscription payment collected');
    String billingCycle = (tenant['billing_cycle'] ?? 'MONTHLY').toString();
    if (!{'MONTHLY', 'YEARLY', 'DAYS'}.contains(billingCycle)) billingCycle = 'MONTHLY';
    int extDays = billingCycle == 'YEARLY' ? 365 : 30;
    String paymentMode = 'BANK_TRANSFER';
    String? err;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDlg) => AlertDialog(
          title: Text('Mark Paid · ${tenant['name']}', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (err != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(err!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                  ),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Amount Paid ($planCurr / $currSym) *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: dueCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Remaining Due ($planCurr)'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: billingCycle,
                  decoration: const InputDecoration(labelText: 'Billing Cycle / Extension'),
                  items: const [
                    DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly (+30 Days)')),
                    DropdownMenuItem(value: 'YEARLY', child: Text('Yearly (+365 Days)')),
                    DropdownMenuItem(value: 'DAYS', child: Text('Custom (0 Days / Settle Due Only)')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDlg(() {
                        billingCycle = v;
                        extDays = v == 'YEARLY' ? 365 : (v == 'MONTHLY' ? 30 : 0);
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: paymentMode,
                  decoration: const InputDecoration(labelText: 'Payment Mode'),
                  items: const [
                    DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'UPI', child: Text('UPI / Instant')),
                    DropdownMenuItem(value: 'CARD', child: Text('Card')),
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDlg(() => paymentMode = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Transaction Ref / Receipt Note')),
                const SizedBox(height: 8),
                TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              label: const Text('Confirm & Generate Receipt'),
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (amt <= 0) {
                  setDlg(() => err = 'Enter an amount greater than 0.');
                  return;
                }
                final compProv = context.read<CompanyProvider>();
                final res = await ActionLoader.run(
                  c,
                  message: 'Recording Payment & Receipt...',
                  task: () => compProv.collectCompanyPayment(
                    tenant['id'].toString(),
                    {
                      'amount_paid': amt,
                      'due_amount': double.tryParse(dueCtrl.text.trim()) ?? 0.0,
                      'currency': planCurr,
                      'billing_cycle': billingCycle,
                      'extension_days': extDays,
                      'payment_mode': paymentMode,
                      'transaction_ref': refCtrl.text.trim(),
                      'notes': notesCtrl.text.trim(),
                    },
                  ),
                );
                if (res != null && ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message']?.toString() ?? 'Payment recorded & receipt generated!'),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                } else {
                  setDlg(() => err = compProv.errorMessage ?? 'Failed to record payment.');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printSubscriptionReceiptPdf(Map<String, dynamic> r, String targetSym, String targetCurr) async {
    final doc = pw.Document();
    final origCurr = (r['currency'] ?? 'INR').toString();
    final amtPaid = (r['amount_paid'] as num?)?.toDouble() ?? 0.0;
    final convPaid = (r['converted_paid'] as num?)?.toDouble() ?? 0.0;
    final rDue = (r['due_amount'] as num?)?.toDouble() ?? 0.0;
    final created = (r['created_at'] ?? '').toString();
    final dateStr = created.length >= 10 ? created.substring(0, 10) : created;
    final expiryRaw = (r['new_expiry'] ?? '').toString();
    final expiryStr = expiryRaw.length >= 10 ? expiryRaw.substring(0, 10) : expiryRaw;

    // Gather full payment & due history for this tenant company
    final compId = (r['company_id'] ?? '').toString();
    final compProv = context.read<CompanyProvider>();
    final allReceipts = (compProv.billingOverview?['receipts'] as List<dynamic>?) ?? [];
    final companyHistory = compId.isNotEmpty
        ? allReceipts.where((x) => (x['company_id'] ?? '').toString() == compId).toList()
        : [r];
    final totalPaidHist = companyHistory.fold<double>(
      0.0,
      (sum, x) => sum + ((x['amount_paid'] as num?)?.toDouble() ?? 0.0),
    );
    final totalDueHist = companyHistory.fold<double>(
      0.0,
      (sum, x) => sum + ((x['due_amount'] as num?)?.toDouble() ?? 0.0),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('PLATFORM SUBSCRIPTION RECEIPT', style: pw.TextStyle(color: PdfColors.white, fontSize: 15, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text('Receipt #: ${r['receipt_number']}', style: const pw.TextStyle(color: PdfColors.amber200, fontSize: 11)),
                    ],
                  ),
                  pw.Text('Date: $dateStr', style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text('Tenant Company: ${r['company_name']}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.Text('Tenant Email: ${r['company_email'] ?? '-'}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Text('Managed By: ${r['owner_name'] ?? 'Platform Master'}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              headers: ['Plan', 'Cycle', 'Valid Until', 'Mode', 'Ref', 'Amount'],
              data: [
                [
                  '${r['plan_name']}',
                  '${r['billing_cycle']}',
                  expiryStr,
                  '${r['payment_mode'] ?? 'BANK'}',
                  '${(r['transaction_ref'] ?? '').toString().isNotEmpty ? r['transaction_ref'] : '-'}',
                  '$origCurr ${amtPaid.toStringAsFixed(2)}',
                ],
              ],
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo800),
              cellStyle: const pw.TextStyle(fontSize: 9.5),
            ),
            pw.SizedBox(height: 12),
            if (origCurr != targetCurr && amtPaid > 0)
              pw.Text('FX Equivalent ($targetCurr): $targetCurr ${convPaid.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColors.amber800)),
            if (rDue > 0)
              pw.Text('Remaining Due on Entry: $origCurr ${rDue.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
            if (companyHistory.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text('Payment & Billing History (${companyHistory.length} entries)', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Receipt #', 'Mode', 'Ref', 'Paid', 'Due', 'Status'],
                data: companyHistory.map((h) {
                  final hc = (h['created_at'] ?? '').toString();
                  final hDate = hc.length >= 10 ? hc.substring(0, 10) : hc;
                  final hCurr = (h['currency'] ?? origCurr).toString();
                  final hPaid = (h['amount_paid'] as num?)?.toDouble() ?? 0.0;
                  final hDue = (h['due_amount'] as num?)?.toDouble() ?? 0.0;
                  final hRef = (h['transaction_ref'] ?? '').toString();
                  return [
                    hDate,
                    '${h['receipt_number'] ?? '-'}',
                    '${h['payment_mode'] ?? '-'}',
                    hRef.isNotEmpty ? hRef : '-',
                    '$hCurr ${hPaid.toStringAsFixed(2)}',
                    '$hCurr ${hDue.toStringAsFixed(2)}',
                    '${h['payment_status'] ?? '-'}',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Total Paid: $origCurr ${totalPaidHist.toStringAsFixed(2)}   |   Balance Due: $origCurr ${totalDueHist.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
                      color: totalDueHist > 0 ? PdfColors.red800 : PdfColors.green800,
                    ),
                  ),
                ],
              ),
            ],
            pw.SizedBox(height: 16),
            pw.Text('Collected / Approved By: ${r['approved_by_name'] ?? 'Admin'}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            if ((r['notes'] ?? '').toString().isNotEmpty)
              pw.Text('Notes: ${r['notes']}', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey600)),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: '${r['receipt_number']}.pdf');
  }

  void _showBreakdownDialog({
    required String sym,
    required String targetCurr,
    required List<dynamic> ownerBreakdown,
    required List<dynamic> tenantBreakdown,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 650),
          child: GlassCard(
            opacity: 0.98,
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics_rounded, color: Color(0xFF047857)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Earnings & Tenant Attribution ($targetCurr)',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFFE2E8F0)),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('By Super Admin / Platform Master', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF334155))),
                        const SizedBox(height: 8),
                        if (ownerBreakdown.isEmpty)
                          Text('No owner data available.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)))
                        else
                          ...ownerBreakdown.map((o) {
                            final act = o['active_tenants'] ?? 0;
                            final susp = o['suspended_tenants'] ?? 0;
                            final oMrr = (o['active_mrr'] as num?)?.toDouble() ?? 0.0;
                            final oCol = (o['actual_collected'] as num?)?.toDouble() ?? 0.0;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${o['owner_name']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                                        Text('$act Active · $susp Suspended', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Collected: $sym${oCol.toStringAsFixed(0)}', style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF047857))),
                                      Text('Active MRR: $sym${oMrr.toStringAsFixed(0)}/mo', style: GoogleFonts.robotoMono(fontSize: 11, color: const Color(0xFF475569))),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        const SizedBox(height: 16),
                        Text('By Tenant', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF334155))),
                        const SizedBox(height: 8),
                        ...tenantBreakdown.map((t) {
                          final isAct = t['status'] == 'ACTIVE';
                          final tPaid = (t['actual_paid'] as num?)?.toDouble() ?? 0.0;
                          final tMrr = (t['monthly_rate_converted'] as num?)?.toDouble() ?? 0.0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${t['name']} (${t['plan_name']})', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                      Text('Owner: ${t['owner_name']} · ${t['status']}', style: GoogleFonts.inter(fontSize: 11, color: isAct ? const Color(0xFF059669) : const Color(0xFFDC2626))),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Paid: $sym${tPaid.toStringAsFixed(0)}', style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                                    Text(isAct ? 'MRR: $sym${tMrr.toStringAsFixed(0)}/mo' : 'Stopped (Suspended)', style: GoogleFonts.inter(fontSize: 10.5, color: isAct ? const Color(0xFF64748B) : const Color(0xFFDC2626))),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: GlassCard(
        opacity: 0.95,
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
