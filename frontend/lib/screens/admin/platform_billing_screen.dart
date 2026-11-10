import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/app_back_button.dart';
import '../../routes/app_routes.dart';
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
    final totalCompanies = billing?['total_companies'] ?? companies.length;
    final activeSubs = billing?['active_subscribers'] ?? companies.where((c) => c.isActive).length;
    final breakdown = (billing?['plan_breakdown'] as List<dynamic>?) ?? [];

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

              // KPI Cards Row
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Monthly Recurring (MRR)',
                      value: '₹${mrr.toStringAsFixed(0)}',
                      subtitle: 'Active platform MRR',
                      icon: Icons.monetization_on_rounded,
                      color: const Color(0xFF047857),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Annual Run-Rate (ARR)',
                      value: '₹${arr.toStringAsFixed(0)}',
                      subtitle: 'Projected annual revenue',
                      icon: Icons.trending_up_rounded,
                      color: const Color(0xFFD4AF37),
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Active Subscribers',
                        value: '$activeSubs',
                        subtitle: '$totalCompanies total tenants',
                        icon: Icons.business_rounded,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ],
              ),
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
                                Text('₹${pRev.toStringAsFixed(0)}/mo', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF047857))),
                                Text('$pSubs active companies', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    Text('Tenant Subscription Statuses', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                    const SizedBox(height: 12),

                    GlassCard(
                      opacity: 0.95,
                      borderRadius: BorderRadius.circular(18),
                      padding: EdgeInsets.all(isMobile ? 14 : 18),
                      child: companies.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text('No tenant companies recorded yet.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: companies.length,
                              separatorBuilder: (_, __) => const Divider(color: Color(0xFFE2E8F0), height: 16),
                              itemBuilder: (ctx, i) {
                                final c = companies[i];
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
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.apartment_rounded, size: 20, color: Color(0xFF334155)),
                                        ),
                                        const SizedBox(width: 12),
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(c.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              Text('${c.adminEmail} • ${c.userCount} users', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFD4AF37)),
                                          ),
                                          child: Text(
                                            c.planName,
                                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: c.isActive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: c.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                          ),
                                          child: Text(
                                            c.isActive ? 'Active' : 'Suspended',
                                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: c.isActive ? const Color(0xFF047857) : const Color(0xFFDC2626)),
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

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return GlassCard(
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
    );
  }
}
