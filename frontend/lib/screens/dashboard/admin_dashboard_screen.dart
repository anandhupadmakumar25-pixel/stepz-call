import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/company_logo_view.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../models/company_model.dart';
import '../../models/company_renewal_request_model.dart';
import '../../models/company_subscription_history_model.dart';
import '../../models/plan_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _companyFilter = 'ALL'; // ALL, ACTIVE, SUSPENDED, EXPIRING

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    final compProv = context.read<CompanyProvider>();
    await Future.wait([
      compProv.fetchCompanies(),
      compProv.fetchBillingOverview(),
      compProv.fetchRenewalRequests(),
      compProv.fetchSubscriptionHistory(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final compProv = context.watch<CompanyProvider>();
    final user = auth.currentUser;
    final isMobile = ResponsiveLayout.isMobile(context);

    final companies = compProv.companies;
    final totalCompanies = companies.length;
    final activeCompanies = companies.where((c) => c.isActive).length;
    final suspendedCompanies = companies.where((c) => c.isSuspended).length;
    final expiringSoonCompanies =
        companies.where((c) => c.isExpiringSoon || c.isPlanOverdue).toList();

    // Billing & Earnings (scoped to this Super Admin)
    final billing = compProv.billingOverview ?? {};
    final double mrr = (billing['monthly_recurring_revenue'] as num?)?.toDouble() ??
        companies
            .where((c) => c.isActive)
            .fold<double>(0.0, (sum, c) => sum + c.planPriceMonthly);
    final double arr =
        (billing['annual_recurring_revenue'] as num?)?.toDouble() ?? (mrr * 12.0);
    final String primaryCurrency = companies.isNotEmpty
        ? companies.first.planCurrency
        : (billing['currency']?.toString() ?? 'INR');
    final String currencySymbol = companies.isNotEmpty
        ? companies.first.planCurrencySymbol
        : PlanModel.getSymbolForCurrency(primaryCurrency);

    final historyMetrics = compProv.historyMetrics;
    final renewalMetrics = compProv.renewalRequestMetrics;
    final pendingRequests = compProv.renewalRequests
        .where((r) => r.status.toUpperCase() == 'PENDING')
        .toList();
    final recentHistory = compProv.subscriptionHistory.take(6).toList();

    final filteredCompanies = companies.where((c) {
      if (_companyFilter == 'ACTIVE') return c.isActive;
      if (_companyFilter == 'SUSPENDED') return c.isSuspended;
      if (_companyFilter == 'EXPIRING') return c.isExpiringSoon || c.isPlanOverdue;
      return true;
    }).toList();

    final isInitialLoading = compProv.isLoading && companies.isEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: const Color(0xFF047857),
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isMobile ? 12 : 24,
            isMobile ? 8 : 16,
            isMobile ? 12 : 24,
            isMobile ? 16 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Clean Standard Header
              _buildHeader(
                fullName: user?.fullName ?? 'Super Admin',
                isMobile: isMobile,
                isLoading: compProv.isLoading || compProv.isLoadingHistory,
              ),
              SizedBox(height: isMobile ? 12 : 18),

              // 2. Primary Portfolio & Earnings KPIs (4 cards, responsive 2x2 / 4-col)
              _buildKpiGrid(
                isMobile: isMobile,
                totalCompanies: totalCompanies,
                activeCompanies: activeCompanies,
                suspendedCompanies: suspendedCompanies,
                expiringCount: expiringSoonCompanies.length,
                mrr: mrr,
                arr: arr,
                totalRenewalRevenue: historyMetrics.totalRevenue,
                totalRenewals: historyMetrics.totalRenewals,
                pendingRenewals: renewalMetrics['pending_count'] ?? pendingRequests.length,
                currencySymbol: currencySymbol,
              ),
              SizedBox(height: isMobile ? 12 : 18),

              if (isInitialLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                // 3. Renewals & Billing Earnings Section (Responsive 2-column on desktop)
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final useTwoCols = !isMobile && constraints.maxWidth >= 820;
                    final renewalsCard = _buildRenewalsOverviewCard(
                      pendingRequests: pendingRequests,
                      expiringCompanies: expiringSoonCompanies,
                      pendingCount: renewalMetrics['pending_count'] ?? pendingRequests.length,
                      approvedCount: renewalMetrics['approved_count'] ?? 0,
                      rejectedCount: renewalMetrics['rejected_count'] ?? 0,
                    );
                    final billingCard = _buildBillingEarningsCard(
                      currencySymbol: currencySymbol,
                      mrr: mrr,
                      arr: arr,
                      totalRevenue: historyMetrics.totalRevenue,
                      monthlyCount: historyMetrics.monthlyCount,
                      yearlyCount: historyMetrics.yearlyCount,
                      recentHistory: recentHistory,
                    );

                    if (useTwoCols) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: renewalsCard),
                          const SizedBox(width: 14),
                          Expanded(child: billingCard),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        renewalsCard,
                        const SizedBox(height: 14),
                        billingCard,
                      ],
                    );
                  },
                ),
                SizedBox(height: isMobile ? 12 : 18),

                // 4. My Companies Directory Summary
                _buildCompaniesSection(
                  isMobile: isMobile,
                  allCount: companies.length,
                  activeCount: activeCompanies,
                  suspendedCount: suspendedCompanies,
                  expiringCount: expiringSoonCompanies.length,
                  filteredCompanies: filteredCompanies,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required String fullName,
    required bool isMobile,
    required bool isLoading,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Portfolio Dashboard',
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 19 : 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Welcome, $fullName · Track your created companies, billing earnings, and renewals',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: isLoading ? null : _loadDashboardData,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 14,
              vertical: isMobile ? 8 : 10,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: Icon(
            Icons.refresh_rounded,
            size: 16,
            color: isLoading ? const Color(0xFF94A3B8) : const Color(0xFF047857),
          ),
          label: Text(
            'Refresh',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGrid({
    required bool isMobile,
    required int totalCompanies,
    required int activeCompanies,
    required int suspendedCompanies,
    required int expiringCount,
    required double mrr,
    required double arr,
    required double totalRenewalRevenue,
    required int totalRenewals,
    required int pendingRenewals,
    required String currencySymbol,
  }) {
    final fmt = NumberFormat('#,##0');

    final card1 = _buildKpiTile(
      icon: Icons.apartment_rounded,
      label: 'Total Companies',
      value: '$totalCompanies',
      subtitle: '$activeCompanies Active · $suspendedCompanies Suspended',
      color: const Color(0xFF0284C7),
      bg: const Color(0xFFF0F9FF),
    );
    final card2 = _buildKpiTile(
      icon: Icons.verified_rounded,
      label: 'Active Companies',
      value: '$activeCompanies',
      subtitle: expiringCount > 0 ? '$expiringCount Expiring / Overdue' : 'All plans healthy',
      color: const Color(0xFF059669),
      bg: const Color(0xFFECFDF5),
    );
    final card3 = _buildKpiTile(
      icon: Icons.payments_outlined,
      label: 'Monthly Billing (MRR)',
      value: '$currencySymbol${fmt.format(mrr)}',
      subtitle: 'ARR $currencySymbol${fmt.format(arr)}',
      color: const Color(0xFF4338CA),
      bg: const Color(0xFFEEF2FF),
    );
    final card4 = _buildKpiTile(
      icon: Icons.account_balance_wallet_outlined,
      label: 'Total Billed & Renewals',
      value: '$currencySymbol${fmt.format(totalRenewalRevenue)}',
      subtitle: '$totalRenewals Bills · $pendingRenewals Pending',
      color: const Color(0xFFD97706),
      bg: const Color(0xFFFFFBEB),
    );

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isNarrow = isMobile || constraints.maxWidth < 780;
        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 8),
                  Expanded(child: card2),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: card3),
                  const SizedBox(width: 8),
                  Expanded(child: card4),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: card1),
            const SizedBox(width: 12),
            Expanded(child: card2),
            const SizedBox(width: 12),
            Expanded(child: card3),
            const SizedBox(width: 12),
            Expanded(child: card4),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRenewalsOverviewCard({
    required List<CompanyRenewalRequestModel> pendingRequests,
    required List<CompanyModel> expiringCompanies,
    required int pendingCount,
    required int approvedCount,
    required int rejectedCount,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      opacity: 0.94,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.autorenew_rounded, size: 18, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Renewals & Expiring Plans',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildCountPill('$pendingCount Pending', const Color(0xFFD97706), const Color(0xFFFFFBEB)),
              _buildCountPill('$approvedCount Approved', const Color(0xFF059669), const Color(0xFFECFDF5)),
              _buildCountPill('$rejectedCount Rejected', const Color(0xFF64748B), const Color(0xFFF1F5F9)),
              _buildCountPill('${expiringCompanies.length} Expiring/Overdue', const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),
          if (pendingRequests.isEmpty && expiringCompanies.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No pending renewal requests or expiring companies.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ),
            )
          else ...[
            ...pendingRequests.take(4).map((req) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req.companyName,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${req.planName.isNotEmpty ? req.planName : "Plan"} · ${req.billingCycle}${req.paymentReference.isNotEmpty ? " · Ref: ${req.paymentReference}" : ""}',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge('PENDING', const Color(0xFFD97706), const Color(0xFFFEF3C7)),
                    ],
                  ),
                )),
            ...expiringCompanies.take(4).map((comp) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              comp.name,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${comp.planName} · ${comp.isPlanOverdue ? "Expired" : "Expires in ${comp.daysUntilExpiry ?? 0}d"}',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB91C1C)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(
                        comp.isPlanOverdue ? 'OVERDUE' : 'EXPIRING',
                        const Color(0xFFDC2626),
                        Colors.white,
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildBillingEarningsCard({
    required String currencySymbol,
    required double mrr,
    required double arr,
    required double totalRevenue,
    required int monthlyCount,
    required int yearlyCount,
    required List<CompanySubscriptionHistoryModel> recentHistory,
  }) {
    final fmt = NumberFormat('#,##0.00');
    return GlassCard(
      padding: const EdgeInsets.all(16),
      opacity: 0.94,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF059669)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bills & Earnings Summary',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildCountPill('MRR: $currencySymbol${NumberFormat('#,##0').format(mrr)}', const Color(0xFF4338CA), const Color(0xFFEEF2FF)),
              _buildCountPill('Collected: $currencySymbol${fmt.format(totalRevenue)}', const Color(0xFF059669), const Color(0xFFECFDF5)),
              _buildCountPill('Monthly: $monthlyCount · Yearly: $yearlyCount', const Color(0xFF0284C7), const Color(0xFFF0F9FF)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),
          if (recentHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No billing or renewal transactions recorded yet.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ),
            )
          else
            ...recentHistory.map((item) {
              final itemSymbol = PlanModel.getSymbolForCurrency(item.currency);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.companyName.isNotEmpty ? item.companyName : 'Tenant Company',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${item.planName} · ${item.billingCycleDisplay} · ${item.formattedCreatedAt}',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$itemSymbol${NumberFormat('#,##0').format(item.amountPaid)}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCompaniesSection({
    required bool isMobile,
    required int allCount,
    required int activeCount,
    required int suspendedCount,
    required int expiringCount,
    required List<CompanyModel> filteredCompanies,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      opacity: 0.94,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'My Created Companies ($allCount)',
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildFilterChip('ALL', 'All ($allCount)'),
                  _buildFilterChip('ACTIVE', 'Active ($activeCount)'),
                  _buildFilterChip('SUSPENDED', 'Suspended ($suspendedCount)'),
                  _buildFilterChip('EXPIRING', 'Expiring ($expiringCount)'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),
          if (filteredCompanies.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No companies match the selected filter.',
                  style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredCompanies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _buildCompanyRow(filteredCompanies[i], isMobile),
            ),
        ],
      ),
    );
  }

  Widget _buildCompanyRow(CompanyModel comp, bool isMobile) {
    final statusColor = comp.isActive
        ? (comp.isPlanOverdue || comp.isExpiringSoon
            ? const Color(0xFFD97706)
            : const Color(0xFF059669))
        : const Color(0xFFDC2626);
    final statusBg = comp.isActive
        ? (comp.isPlanOverdue || comp.isExpiringSoon
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFECFDF5))
        : const Color(0xFFFEF2F2);
    final statusText = comp.isSuspended
        ? 'SUSPENDED'
        : (comp.isPlanOverdue
            ? 'EXPIRED'
            : (comp.isExpiringSoon
                ? 'EXPIRING IN ${comp.daysUntilExpiry ?? 0}D'
                : 'ACTIVE'));

    final priceText = comp.planBillingCycle == 'YEARLY'
        ? '${comp.planCurrencySymbol}${comp.planPriceYearly.toStringAsFixed(0)}/yr'
        : '${comp.planCurrencySymbol}${comp.planPriceMonthly.toStringAsFixed(0)}/mo';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CompanyLogoView(
            logo: comp.logo,
            companyName: comp.name,
            size: 36,
            borderRadius: BorderRadius.circular(9),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comp.name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${comp.planName} ($priceText) · ${comp.userCount} Users · ${comp.adminEmail}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildStatusBadge(statusText, statusColor, statusBg),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _companyFilter == key;
    return InkWell(
      onTap: () => setState(() => _companyFilter = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildCountPill(String text, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
