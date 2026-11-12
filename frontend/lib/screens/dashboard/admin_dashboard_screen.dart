import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/dashboard_model.dart';
import '../../providers/company_provider.dart';
import '../../core/widgets/company_logo_view.dart';
import '../../routes/app_routes.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _selectedRange = '3 Months';
  String _selectedCompanyFilter = 'All Companies';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().fetchAdminDashboard();
      context.read<CompanyProvider>().fetchCompanies();
    });
  }

  // ==========================================
  // REUSABLE FROSTED GLASS CONTAINER BUILDER
  // ==========================================
  Widget _buildGlassContainer({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
    double borderRadius = 18.0,
    double opacity = 0.80,
    Border? border,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: (opacity + 0.08).clamp(0.0, 0.94)),
                Colors.white.withValues(alpha: (opacity - 0.06).clamp(0.0, 0.94)),
              ],
            ),
            border: border ??
                Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.30),
                  width: 1.0,
                ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.035),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.10),
                blurRadius: 10,
                spreadRadius: -2,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();
    final kpis = dash.adminKpis;
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final now = DateTime.now();
    final dateStr = DateFormat('EEE, d MMM yyyy').format(now);
    final timeStr = DateFormat('hh:mm a').format(now);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          RefreshIndicator(
            color: const Color(0xFF6366F1),
            onRefresh: () => context.read<DashboardProvider>().fetchAdminDashboard(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 12 : 22,
                  isMobile ? 6 : 14,
                  isMobile ? 12 : 22,
                  isMobile ? 10 : 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. HERO GREETING
                    _buildTopBarAndHero(dateStr, timeStr, isDesktop, isMobile, kpis.totalCompanies),
                    const SizedBox(height: 14),

                    // 2. 5 EXECUTIVE STAT CARDS (Total Companies, Active, Suspended, Total Employees, Total Leads)
                    _buildFiveStatCardsRow(kpis, isDesktop),
                    const SizedBox(height: 16),

                    // 3. MIDDLE SECTION: Platform Overview Multi-Line Area Chart (Left) & Recent Companies (Right)
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: _buildPlatformOverviewChart()),
                          const SizedBox(width: 14),
                          Expanded(flex: 5, child: _buildRecentCompaniesCard()),
                        ],
                      )
                    else ...[
                      _buildPlatformOverviewChart(),
                      const SizedBox(height: 14),
                      _buildRecentCompaniesCard(),
                    ],
                    const SizedBox(height: 16),

                    // 4. BOTTOM SECTION: 3 Cards (Company Onboarding, Platform Activity, Quick Actions)
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: _buildOnboardingProgressCard()),
                          const SizedBox(width: 14),
                          Expanded(flex: 4, child: _buildPlatformActivityCard()),
                          const SizedBox(width: 14),
                          Expanded(flex: 4, child: _buildQuickActionsCard()),
                        ],
                      )
                    else ...[
                      _buildOnboardingProgressCard(),
                      const SizedBox(height: 14),
                      _buildPlatformActivityCard(),
                      const SizedBox(height: 14),
                      _buildQuickActionsCard(),
                    ],
                    const SizedBox(height: 16),

                    // 5. SYSTEM FOOTER
                    _buildSystemFooter(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // 1. HERO GREETING
  // ==========================================
  Widget _buildTopBarAndHero(
    String dateStr,
    String timeStr,
    bool isDesktop,
    bool isMobile,
    int totalCompanies,
  ) {
    final compCount = totalCompanies > 0 ? totalCompanies : 24;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Greeting: "Good Afternoon, Super Admin 👋"
        Text(
          'Good Afternoon, Super Admin 👋',
          style: GoogleFonts.inter(
            fontSize: isMobile ? 20 : 26,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Here's what's happening across your Telecaller CRM platform today.",
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: const Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),

        // 3 Header Pills: [Date] [Time] [Total Companies]
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _buildHeaderPill(Icons.calendar_today_rounded, dateStr),
            _buildHeaderPill(Icons.access_time_rounded, timeStr),
            _buildHeaderPill(Icons.business_rounded, 'Total Companies: $compCount'),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.35), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: const Color(0xFF047857)),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. FIVE STAT CARDS ROW
  // ==========================================
  Widget _buildFiveStatCardsRow(DashboardKpis kpis, bool isDesktop) {
    final totalComp = kpis.totalCompanies > 0 ? kpis.totalCompanies : 24;
    final activeComp = kpis.activeCompanies > 0 ? kpis.activeCompanies : 18;
    final suspendedComp = kpis.suspendedCompanies > 0 ? kpis.suspendedCompanies : 2;
    final totalEmp = kpis.totalEmployees > 0 ? kpis.totalEmployees : 342;
    final totalLeads = kpis.totalRegisteredLeads > 0 ? kpis.totalRegisteredLeads : 12584;

    final cards = [
      _StatCardData(
        title: 'Total Companies',
        value: totalComp.toString(),
        trend: '↑ 12%',
        trendSub: 'vs last month',
        isPositive: true,
        icon: Icons.storefront_rounded,
        accentColor: const Color(0xFF3B82F6),
        rightSparklineColor: const Color(0xFF8B5CF6),
      ),
      _StatCardData(
        title: 'Active Companies',
        value: activeComp.toString(),
        trend: '↑ 8%',
        trendSub: 'vs last month',
        isPositive: true,
        icon: Icons.verified_rounded,
        accentColor: const Color(0xFF10B981),
        rightSparklineColor: const Color(0xFF10B981),
      ),
      _StatCardData(
        title: 'Suspended Companies',
        value: suspendedComp.toString(),
        trend: '↓ 8%',
        trendSub: 'vs last month',
        isPositive: false,
        icon: Icons.pause_circle_outline_rounded,
        accentColor: const Color(0xFFEF4444),
        rightSparklineColor: const Color(0xFFEF4444),
      ),
      _StatCardData(
        title: 'Total Employees',
        value: totalEmp.toString(),
        trend: '↑ 15%',
        trendSub: 'vs last month',
        isPositive: true,
        icon: Icons.person_outline_rounded,
        accentColor: const Color(0xFF0284C7),
        rightSparklineColor: const Color(0xFF3B82F6),
      ),
      _StatCardData(
        title: 'Total Leads',
        value: NumberFormat('#,###').format(totalLeads),
        trend: '↑ 22%',
        trendSub: 'vs last month',
        isPositive: true,
        icon: Icons.people_alt_rounded,
        accentColor: const Color(0xFF8B5CF6),
        rightSparklineColor: const Color(0xFF8B5CF6),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildSingleStatCard(c),
          ),
        )).toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 520) {
          return Column(
            children: cards
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildSingleStatCard(c),
                    ))
                .toList(),
          );
        }
        final count = constraints.maxWidth > 700 ? 3 : 2;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.85,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          itemBuilder: (context, index) => _buildSingleStatCard(cards[index]),
        );
      },
    );
  }

  Widget _buildSingleStatCard(_StatCardData data) {
    return _buildGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      borderRadius: 16,
      opacity: 0.68,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top: Icon + Title + Chevron Right
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5.5),
                decoration: BoxDecoration(
                  color: data.accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: data.accentColor.withValues(alpha: 0.35), width: 0.8),
                ),
                child: Icon(data.icon, size: 15, color: data.accentColor),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  data.title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF94A3B8)),
            ],
          ),
          const SizedBox(height: 6),

          // Main Number
          Text(
            data.value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),

          // Bottom: Left Trend + Sparkline, Right Sparkline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Trend & Left mini sparkline
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 38,
                    height: 12,
                    child: CustomPaint(
                      painter: _MiniSparklinePainter(
                        color: data.isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        isDown: !data.isPositive,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.trend,
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: data.isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        data.trendSub,
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Right Mini Area Sparkline
              SizedBox(
                width: 44,
                height: 16,
                child: CustomPaint(
                  painter: _MiniAreaSparklinePainter(
                    color: data.rightSparklineColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. PLATFORM OVERVIEW CURVED SPLINE CHART
  // ==========================================
  Widget _buildPlatformOverviewChart() {
    final isMobile = ResponsiveLayout.isMobile(context);
    return _buildGlassContainer(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      borderRadius: 18,
      opacity: 0.68,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header: Chart Icon + "Platform Overview", "All Companies ▾"
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF047857).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bar_chart_rounded, size: 18, color: Color(0xFF047857)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Platform Overview',
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                onSelected: (val) => setState(() => _selectedCompanyFilter = val),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'All Companies', child: Text('All Companies')),
                  PopupMenuItem(value: 'Active Companies', child: Text('Active Companies')),
                  PopupMenuItem(value: 'Suspended Companies', child: Text('Suspended Companies')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _selectedCompanyFilter,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Subheader: Range Switcher (7 Days, 30 Days, 3 Months, 6 Months, 1 Year) & Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Range Switcher
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ['7 Days', '30 Days', '3 Months', '6 Months', '1 Year'].map((range) {
                      final isSelected = _selectedRange == range;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedRange = range),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF047857) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF047857).withValues(alpha: 0.35),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            range,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Legend Dots: Total Leads, Calls Logged, Completed Leads, Callbacks
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _buildLegendItem(const Color(0xFF3B82F6), 'Total Leads'),
                  _buildLegendItem(const Color(0xFF8B5CF6), 'Calls Logged'),
                  _buildLegendItem(const Color(0xFFF97316), 'Completed Leads'),
                  _buildLegendItem(const Color(0xFF06B6D4), 'Callbacks'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Smooth 4-Line Curved Spline Area Chart
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.08),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        String text = '';
                        if (value == 0) text = '0';
                        if (value == 5) text = '5K';
                        if (value == 10) text = '10K';
                        if (value == 15) text = '15K';
                        if (value == 20) text = '20K';
                        return Text(
                          text,
                          style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
                        final int idx = value.toInt();
                        if (idx >= 0 && idx < months.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              months[idx],
                              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: 20,
                lineBarsData: [
                  // Line 1: Calls Logged (Purple #8B5CF6)
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 4.8),
                      FlSpot(1, 6.2),
                      FlSpot(2, 7.5),
                      FlSpot(3, 9.8),
                      FlSpot(4, 11.8),
                      FlSpot(5, 13.5),
                      FlSpot(6, 15.2),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF8B5CF6),
                    barWidth: 2.2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3.5,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: const Color(0xFF8B5CF6),
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                          const Color(0xFF8B5CF6).withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                  // Line 2: Total Leads (Blue #3B82F6)
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 3.8),
                      FlSpot(1, 4.9),
                      FlSpot(2, 6.0),
                      FlSpot(3, 7.2),
                      FlSpot(4, 8.8),
                      FlSpot(5, 10.5),
                      FlSpot(6, 12.2),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF3B82F6),
                    barWidth: 2.0,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3,
                        color: Colors.white,
                        strokeWidth: 1.8,
                        strokeColor: const Color(0xFF3B82F6),
                      ),
                    ),
                  ),

                  // Line 3: Callbacks (Cyan #06B6D4)
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 2.5),
                      FlSpot(1, 3.2),
                      FlSpot(2, 4.1),
                      FlSpot(3, 5.0),
                      FlSpot(4, 5.8),
                      FlSpot(5, 7.2),
                      FlSpot(6, 8.5),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF06B6D4),
                    barWidth: 1.8,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 2.5,
                        color: Colors.white,
                        strokeWidth: 1.5,
                        strokeColor: const Color(0xFF06B6D4),
                      ),
                    ),
                  ),

                  // Line 4: Completed Leads (Orange #F97316)
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 1.2),
                      FlSpot(1, 1.8),
                      FlSpot(2, 2.4),
                      FlSpot(3, 3.0),
                      FlSpot(4, 3.6),
                      FlSpot(5, 4.4),
                      FlSpot(6, 5.5),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFFF97316),
                    barWidth: 1.8,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 2.5,
                        color: Colors.white,
                        strokeWidth: 1.5,
                        strokeColor: const Color(0xFFF97316),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
        ),
      ],
    );
  }

  // ==========================================
  // 4. RECENT COMPANIES CARD
  // ==========================================
  Widget _buildRecentCompaniesCard() {
    final compProv = context.watch<CompanyProvider>();
    final realCompanies = compProv.companies;

    final isMobile = ResponsiveLayout.isMobile(context);

    return _buildGlassContainer(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      borderRadius: 18,
      opacity: 0.68,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.domain_rounded, size: 18, color: Color(0xFF6366F1)),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Recent Companies',
                        style: GoogleFonts.inter(
                          fontSize: isMobile ? 14 : 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => Navigator.pushNamed(context, AppRoutes.companies),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View all',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF047857),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF047857)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (realCompanies.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No companies registered yet.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: realCompanies.length > 5 ? 5 : realCompanies.length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFFE2E8F0), height: 14),
              itemBuilder: (context, index) {
                final comp = realCompanies[index];
                final isActive = comp.status == 'ACTIVE';

                return InkWell(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.companyDetail, arguments: comp),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        CompanyLogoView(
                          logo: comp.logo,
                          companyName: comp.name,
                          size: 32,
                          borderRadius: BorderRadius.circular(8),
                          borderColor: const Color(0xFFCBD5E1),
                        ),
                        const SizedBox(width: 10),
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
                                comp.adminEmail,
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Active / Suspended Status Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF10B981).withValues(alpha: 0.16)
                                : const Color(0xFFEF4444).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isActive
                                  ? const Color(0xFF10B981).withValues(alpha: 0.35)
                                  : const Color(0xFFEF4444).withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            comp.status.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isActive ? const Color(0xFF047857) : const Color(0xFFDC2626),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF94A3B8)),
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

  // ==========================================
  // 5. BOTTOM 3 CARDS
  // ==========================================

  // Card 1: Company Onboarding Progress
  Widget _buildOnboardingProgressCard() {
    return _buildGlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      opacity: 0.68,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF047857).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF047857).withValues(alpha: 0.25), width: 0.8),
                ),
                child: const Icon(Icons.pie_chart_rounded, size: 18, color: Color(0xFF047857)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Company Onboarding Progress',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              // Circular Ring (75%)
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: 0.75,
                      strokeWidth: 7,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF047857)),
                    ),
                    Text(
                      '75%',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '18 of 24 companies completed setup',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.companies),
                      child: Text(
                        'View details →',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Checklist
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildChecklistItem('Company Details', true),
              _buildChecklistItem('Admin Account', true),
              _buildChecklistItem('Branches Setup', false),
              _buildChecklistItem('Employees Added', false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String title, bool isDone) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 13,
          color: isDone ? const Color(0xFF047857) : const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 5),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: isDone ? FontWeight.w600 : FontWeight.w400,
            color: isDone ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // Card 2: Platform Activity
  Widget _buildPlatformActivityCard() {
    final activities = [
      {
        'title': 'New company registered',
        'sub': 'Horizon Tech',
        'time': '2 hours ago',
        'icon': Icons.business_center_rounded,
        'color': const Color(0xFF047857),
      },
      {
        'title': 'Company suspended',
        'sub': 'NextGen Solutions',
        'time': '5 hours ago',
        'icon': Icons.pause_circle_filled_rounded,
        'color': const Color(0xFFEF4444),
      },
      {
        'title': 'New employee invited',
        'sub': 'Skyline Academy',
        'time': '6 hours ago',
        'icon': Icons.person_add_alt_1_rounded,
        'color': const Color(0xFFD97706),
      },
      {
        'title': 'New lead imported',
        'sub': 'Apex Global',
        'time': '8 hours ago',
        'icon': Icons.cloud_download_rounded,
        'color': const Color(0xFF6366F1),
      },
    ];

    return _buildGlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      opacity: 0.68,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF047857).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF047857).withValues(alpha: 0.25), width: 0.8),
                ),
                child: const Icon(Icons.flash_on_rounded, size: 18, color: Color(0xFF047857)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Platform Activity',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFFE2E8F0), height: 12),
            itemBuilder: (context, index) {
              final act = activities[index];
              final clr = act['color'] as Color;

              return Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: clr.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: clr.withValues(alpha: 0.30), width: 0.8),
                    ),
                    child: Icon(act['icon'] as IconData, size: 12, color: clr),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${act['title']} - ',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          TextSpan(
                            text: act['sub'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    act['time'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF94A3B8)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Card 3: Quick Actions (with glowing 3D headset illustration from screenshot)
  Widget _buildQuickActionsCard() {
    return _buildGlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      opacity: 0.68,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Exact Glowing Headset Art cropped from screenshot on bottom-right
          Positioned(
            right: -10,
            bottom: -10,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.90,
                child: Image.asset(
                  'assets/images/headset_illustration.png',
                  width: 95,
                  height: 75,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.35), width: 0.8),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFFB45309)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Quick Actions',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Button Grid: Responsive rows of actions
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildActionBtn(
                    icon: Icons.business_rounded,
                    iconColor: const Color(0xFF047857),
                    label: 'Manage Companies',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.companies),
                  ),
                  _buildActionBtn(
                    icon: Icons.workspace_premium_rounded,
                    iconColor: const Color(0xFF0284C7),
                    label: 'Subscription Plans',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.plans),
                  ),
                  _buildActionBtn(
                    icon: Icons.monetization_on_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    label: 'Platform Billing',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.billing),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 6. SYSTEM FOOTER
  // ==========================================
  Widget _buildSystemFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'System Online',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const Text('•', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 9)),
          Text(
            'Telecaller CRM v1.0.0',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// EXACT MINI SPARKLINE PAINTERS
// ==========================================
class _MiniSparklinePainter extends CustomPainter {
  final Color color;
  final bool isDown;

  _MiniSparklinePainter({required this.color, this.isDown = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (!isDown) {
      path.moveTo(0, size.height * 0.85);
      path.quadraticBezierTo(size.width * 0.25, size.height * 0.9, size.width * 0.45, size.height * 0.4);
      path.quadraticBezierTo(size.width * 0.7, size.height * 0.85, size.width, size.height * 0.15);
    } else {
      path.moveTo(0, size.height * 0.15);
      path.quadraticBezierTo(size.width * 0.3, size.height * 0.1, size.width * 0.5, size.height * 0.65);
      path.quadraticBezierTo(size.width * 0.75, size.height * 0.2, size.width, size.height * 0.85);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniAreaSparklinePainter extends CustomPainter {
  final Color color;

  _MiniAreaSparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.8, size.width * 0.6, size.height * 0.3)
      ..quadraticBezierTo(size.width * 0.85, size.height * 0.7, size.width, size.height * 0.2);

    canvas.drawPath(path, strokePaint);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatCardData {
  final String title;
  final String value;
  final String trend;
  final String trendSub;
  final bool isPositive;
  final IconData icon;
  final Color accentColor;
  final Color rightSparklineColor;

  _StatCardData({
    required this.title,
    required this.value,
    required this.trend,
    required this.trendSub,
    required this.isPositive,
    required this.icon,
    required this.accentColor,
    required this.rightSparklineColor,
  });
}
