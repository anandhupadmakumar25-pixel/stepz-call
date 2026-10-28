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

    if (dash.isLoading && dash.activityTimeline.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => context.read<DashboardProvider>().fetchAdminDashboard(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Refresh
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operational Overview',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Real-time telephony performance and lead pipeline metrics',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => context.read<DashboardProvider>().fetchAdminDashboard(),
                  tooltip: 'Refresh Metrics',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // KPI Grid
            GridView.count(
              crossAxisCount: isDesktop ? 4 : (ResponsiveLayout.isTablet(context) ? 2 : 1),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.2,
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
            const SizedBox(height: 24),

            // Charts Section
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildWeeklyActivityChart(dash.activityTimeline)),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _buildOutcomesChart(dash.outcomeCounts)),
                ],
              )
            else ...[
              _buildWeeklyActivityChart(dash.activityTimeline),
              const SizedBox(height: 16),
              _buildOutcomesChart(dash.outcomeCounts),
            ],
            const SizedBox(height: 24),

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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Call Activity (Last 7 Days)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
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
                                width: 18,
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Call Outcome Distribution', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (outcomes.isEmpty)
              SizedBox(
                height: 200,
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
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            StatusBadge(status: outcome),
                          ],
                        ),
                        Text(
                          '$count calls',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Telecaller Team Performance', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${employees.length} active callers', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 52,
                columns: const [
                  DataColumn(label: Text('Employee')),
                  DataColumn(label: Text('Assigned Leads')),
                  DataColumn(label: Text('Calls Today')),
                  DataColumn(label: Text('Daily Target')),
                  DataColumn(label: Text('Total Calls')),
                  DataColumn(label: Text('Callbacks Due')),
                  DataColumn(label: Text('Callbacks Done')),
                  DataColumn(label: Text('Overdue')),
                ],
                rows: employees.map((emp) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(emp.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(emp.email, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      DataCell(Text('${emp.assignedLeads}')),
                      DataCell(
                        Text(
                          '${emp.callsToday}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: emp.callsToday >= emp.dailyTarget ? AppColors.success : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      DataCell(Text('${emp.dailyTarget}')),
                      DataCell(Text('${emp.callsTotal}')),
                      DataCell(Text('${emp.callbacksDue}')),
                      DataCell(Text('${emp.callbacksDone}')),
                      DataCell(
                        Text(
                          '${emp.callbacksOverdue}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: emp.callbacksOverdue > 0 ? AppColors.danger : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
