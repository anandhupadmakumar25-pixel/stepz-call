import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kpi_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../providers/dashboard_provider.dart';

class TelecallerDashboardScreen extends StatefulWidget {
  const TelecallerDashboardScreen({super.key});

  @override
  State<TelecallerDashboardScreen> createState() => _TelecallerDashboardScreenState();
}

class _TelecallerDashboardScreenState extends State<TelecallerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().fetchTelecallerDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    final targetPct = dash.telecallerDailyTarget > 0
        ? (dash.telecallerCallsToday / dash.telecallerDailyTarget).clamp(0.0, 1.0)
        : 0.0;

    return RefreshIndicator(
      onRefresh: () => context.read<DashboardProvider>().fetchTelecallerDashboard(),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Target Progress Banner
            Card(
              color: AppColors.primaryDark,
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 18 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Today's Calling Target",
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentViolet,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(targetPct * 100).toInt()}% Done',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${dash.telecallerCallsToday}',
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 26 : 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          ' / ${dash.telecallerDailyTarget} calls completed',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: targetPct,
                        minHeight: 8,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentViolet),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // KPI Grid
            GridView.count(
              crossAxisCount: isDesktop ? 4 : (ResponsiveLayout.isTablet(context) ? 2 : 1),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: isDesktop ? 2.3 : (ResponsiveLayout.isTablet(context) ? 2.0 : 2.5),
              children: [
                KpiCard(
                  title: 'Assigned Leads',
                  value: '${dash.telecallerAssignedLeads}',
                  subtitle: '${dash.telecallerCompletedLeads} completed',
                  icon: Icons.people_outline,
                  iconColor: AppColors.info,
                ),
                KpiCard(
                  title: 'Callbacks Due Today',
                  value: '${dash.telecallerCallbacksDueToday}',
                  subtitle: 'Scheduled for today',
                  icon: Icons.alarm,
                  iconColor: AppColors.warning,
                ),
                KpiCard(
                  title: 'Upcoming Callbacks',
                  value: '${dash.telecallerCallbacksUpcoming}',
                  subtitle: 'Future follow-ups',
                  icon: Icons.event_note,
                  iconColor: AppColors.accentViolet,
                ),
                KpiCard(
                  title: 'Overdue Callbacks',
                  value: '${dash.telecallerCallbacksOverdue}',
                  subtitle: 'Requires immediate action',
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppColors.danger,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Recent Calls Logged
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Calls Logged',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    if (dash.telecallerRecentCalls.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'No calls logged yet today.',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: dash.telecallerRecentCalls.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final call = dash.telecallerRecentCalls[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.phone_outlined, size: 18),
                            ),
                            title: Text(
                              call.leadName,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              call.notes,
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: StatusBadge(status: call.outcome),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
