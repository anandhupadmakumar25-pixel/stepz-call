import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kpi_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../providers/dashboard_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().fetchAdminDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();
    final kpis = dash.adminKpis;
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    if (dash.isLoading && dash.activityTimeline.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => context.read<DashboardProvider>().fetchAdminDashboard(),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Refresh
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operational Overview',
                        style: GoogleFonts.inter(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Real-time telephony performance & lead pipeline',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => context.read<DashboardProvider>().fetchAdminDashboard(),
                  tooltip: 'Refresh Metrics',
                ),
              ],
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
                  title: 'Total Registered Leads',
                  value: '${kpis.totalRegisteredLeads}',
                  subtitle: '${kpis.newlyImportedLeads} new this week',
                  icon: Icons.contacts_outlined,
                  iconColor: AppColors.info,
                ),
                KpiCard(
                  title: 'Assigned Leads',
                  value: '${kpis.assignedLeads}',
                  subtitle: '${kpis.unassignedLeads} unassigned in pool',
                  icon: Icons.assignment_ind_outlined,
                  iconColor: AppColors.accentViolet,
                ),
                KpiCard(
                  title: 'Calls Logged Today',
                  value: '${kpis.callsLoggedToday}',
                  subtitle: '${kpis.callsLoggedTotal} lifetime attempts',
                  icon: Icons.phone_callback_outlined,
                  iconColor: AppColors.success,
                ),
                KpiCard(
                  title: 'Overdue Callbacks',
                  value: '${kpis.overdueCallbacks}',
                  subtitle: '${kpis.scheduledCallbacks} upcoming scheduled',
                  icon: Icons.alarm_off_outlined,
                  iconColor: AppColors.danger,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Charts Section
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildWeeklyActivityChart(dash.activityTimeline)),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: _buildOutcomesChart(dash.outcomeCounts)),
                ],
              )
            else ...[
              _buildWeeklyActivityChart(dash.activityTimeline),
              const SizedBox(height: 14),
              _buildOutcomesChart(dash.outcomeCounts),
            ],
            const SizedBox(height: 20),

            // Employee Performance Table
            _buildEmployeeTable(dash.employeePerformance),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyActivityChart(List<dynamic> timeline) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Call Activity (Last 7 Days)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 190,
              child: timeline.isEmpty
                  ? Center(child: Text('No call activity logged yet', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 20,
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                int idx = value.toInt();
                                if (idx >= 0 && idx < timeline.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      timeline[idx]['day'] ?? '',
                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                        barGroups: timeline.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          final count = (item['calls'] as num?)?.toDouble() ?? 0.0;
                          return BarChartGroupData(
                            x: idx,
                            barRods: [
                              BarChartRodData(
                                toY: count > 0 ? count : 0.5,
                                color: AppColors.accentViolet,
                                width: 16,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutcomesChart(List<dynamic> outcomes) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Call Outcome Distribution', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (outcomes.isEmpty)
              SizedBox(
                height: 190,
                child: Center(
                  child: Text('No calls logged yet', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ),
              )
            else
              Column(
                children: outcomes.take(5).map((o) {
                  final outcome = o['outcome'] ?? 'OTHER';
                  final count = o['count'] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: StatusBadge(status: outcome)),
                        const SizedBox(width: 8),
                        Text(
                          '$count calls',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeTable(List<dynamic> employees) {
    final horizontalScrollController = ScrollController();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Telecaller Team Performance',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${employees.length} callers active',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Scrollbar(
              controller: horizontalScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 880),
                  child: DataTable(
                    headingRowHeight: 42,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    columns: const [
                      DataColumn(label: Text('EMPLOYEE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                      DataColumn(label: Text('ASSIGNED', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                      DataColumn(label: Text('CALLS TODAY', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                      DataColumn(label: Text('TARGET', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                      DataColumn(label: Text('LIFETIME CALLS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                      DataColumn(label: Text('DUE CALLBACKS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                      DataColumn(label: Text('COMPLETED', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                      DataColumn(label: Text('OVERDUE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                    ],
                    rows: employees.map((emp) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 13,
                                  backgroundColor: AppColors.accentVioletLight,
                                  child: Text(
                                    emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentViolet),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 160),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        emp.name,
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        emp.email,
                                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text('${emp.assignedLeads}', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: emp.callsToday >= emp.dailyTarget ? AppColors.successLight : AppColors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${emp.callsToday}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  color: emp.callsToday >= emp.dailyTarget ? AppColors.success : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text('${emp.dailyTarget}', style: GoogleFonts.inter(color: AppColors.textSecondary))),
                          DataCell(Text('${emp.callsTotal}', style: GoogleFonts.inter(fontWeight: FontWeight.w500))),
                          DataCell(
                            Text(
                              '${emp.callbacksDue}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: emp.callbacksDue > 0 ? AppColors.warning : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          DataCell(Text('${emp.callbacksDone}', style: GoogleFonts.inter(color: AppColors.success, fontWeight: FontWeight.w600))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: emp.callbacksOverdue > 0 ? AppColors.dangerLight : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${emp.callbacksOverdue}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  color: emp.callbacksOverdue > 0 ? AppColors.danger : AppColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
