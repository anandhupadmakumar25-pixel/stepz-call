import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/lead_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../core/widgets/stepz_punch_widget.dart';
import '../../models/lead_model.dart';
import '../tasks/calling_tasks_screen.dart';
import '../callbacks/callback_screen.dart';
import '../leads/lead_directory_screen.dart';
import '../calls/call_outcome_dialog.dart';
import '../quotations/quotation_form_dialog.dart';

class TelecallerDashboardScreen extends StatefulWidget {
  const TelecallerDashboardScreen({super.key});

  @override
  State<TelecallerDashboardScreen> createState() => _TelecallerDashboardScreenState();
}

class _TelecallerDashboardScreenState extends State<TelecallerDashboardScreen> {
  String _queueSearchQuery = '';
  String _selectedStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    context.read<DashboardProvider>().fetchTelecallerDashboard();
    context.read<LeadProvider>().fetchTasks();
    context.read<LeadProvider>().fetchLeads();
    context.read<AttendanceProvider>().fetchTodayStatus();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Color _getOutcomeColor(String outcome) {
    final upper = outcome.toUpperCase();
    if (upper.contains('INTERESTED') || upper.contains('QUALIFIED')) {
      return const Color(0xFF047857); // Emerald
    } else if (upper.contains('CALLBACK')) {
      return const Color(0xFFD97706); // Amber
    } else if (upper.contains('BUSY') || upper.contains('NO_ANSWER')) {
      return const Color(0xFF0284C7); // Sky
    } else if (upper.contains('WRONG') || upper.contains('NOT_INTERESTED') || upper.contains('DO_NOT_CALL')) {
      return const Color(0xFFDC2626); // Red
    }
    return const Color(0xFF2563EB); // Sapphire
  }

  Future<void> _openWhatsApp({
    required String phone,
    required String name,
    required String companyName,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final text = Uri.encodeComponent(
      'Hello $name, I am reaching out from $companyName regarding your inquiry. Please let me know when would be a convenient time to speak.',
    );
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp. Please check if WhatsApp is installed on this device.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dash = context.watch<DashboardProvider>();
    final user = auth.currentUser;
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    final targetPct = dash.telecallerDailyTarget > 0
        ? (dash.telecallerCallsToday / dash.telecallerDailyTarget).clamp(0.0, 1.0)
        : 0.0;
    final remainingCalls = (dash.telecallerDailyTarget - dash.telecallerCallsToday).clamp(0, 9999);

    final userName = user?.fullName.isNotEmpty == true ? user!.fullName : 'Telecaller';
    final companyName = user?.companyName ?? 'Telecaller CRM';
    final branchName = user?.branchName;

    return RefreshIndicator(
      color: const Color(0xFF047857),
      backgroundColor: Colors.white,
      onRefresh: () async {
        _loadData();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          isMobile ? 12 : 24,
          isMobile ? 8 : 18,
          isMobile ? 12 : 24,
          isMobile ? 16 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // ZONE 1: SHIFT & TARGET HUD
            // ==========================================
            _buildExecutiveHeader(
              greeting: _getGreeting(),
              userName: userName,
              companyName: companyName,
              branchName: branchName,
              isMobile: isMobile,
              isDesktop: isDesktop,
            ),
            const SizedBox(height: 16),

            // Stepz Attendance Punch & Geofence
            if (user?.hasPermission('attendance.punch') ?? true) ...[
              const StepzPunchWidget(),
              const SizedBox(height: 16),
            ],

            // Daily Calling Pacing Hero Card
            _buildPacingHeroCard(
              dash: dash,
              targetPct: targetPct,
              remainingCalls: remainingCalls,
              isMobile: isMobile,
            ),
            const SizedBox(height: 16),

            // 4 Micro Metric Stat Badges
            _buildLuxuryStatCards(dash, isDesktop, isMobile),
            const SizedBox(height: 20),

            // ==========================================
            // ZONE 2: PRIMARY CALLING WORKSTATION (PROMINENT QUEUE)
            // ==========================================
            _buildMyAssignedLeadsQueue(context, isMobile, companyName),
            const SizedBox(height: 20),

            // ==========================================
            // ZONE 3: SPLIT DESK (CALLBACKS & CALL HISTORY)
            // ==========================================
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: _buildPriorityCallbacksCard(context, dash, isMobile)),
                  const SizedBox(width: 18),
                  Expanded(flex: 6, child: _buildRecentActivityLedger(dash, isMobile)),
                ],
              )
            else ...[
              _buildPriorityCallbacksCard(context, dash, isMobile),
              const SizedBox(height: 18),
              _buildRecentActivityLedger(dash, isMobile),
            ],
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 1. VIP EXECUTIVE HEADER WIDGET
  // ==========================================
  Widget _buildExecutiveHeader({
    required String greeting,
    required String userName,
    required String companyName,
    required String? branchName,
    required bool isMobile,
    required bool isDesktop,
  }) {
    return GlassCard(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      borderRadius: BorderRadius.circular(20),
      borderColor: const Color(0xFFE2E8F0),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderIdentity(greeting, userName, companyName, branchName),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: GradientPrimaryButton(
                    text: 'Start Calling Tasks',
                    icon: Icons.phone_forwarded_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF047857), Color(0xFF059669)],
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CallingTasksScreen()),
                      );
                    },
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildHeaderIdentity(greeting, userName, companyName, branchName),
                ),
                const SizedBox(width: 16),
                GradientPrimaryButton(
                  text: 'Start Calling Tasks',
                  icon: Icons.phone_forwarded_rounded,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  borderRadius: 12,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF047857), Color(0xFF059669)],
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CallingTasksScreen()),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderIdentity(String greeting, String userName, String companyName, String? branchName) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF047857), Color(0xFF10B981)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF047857).withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'T',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '$greeting, $userName',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(
                          'ON DUTY',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '$companyName${branchName != null ? ' • $branchName' : ''} • Ready for outbound dials',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 2. PACING HERO GAUGE CARD
  // ==========================================
  Widget _buildPacingHeroCard({
    required DashboardProvider dash,
    required double targetPct,
    required int remainingCalls,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title & Done Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: Color(0xFF047857), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today's Calling Target & Pacing",
                            style: GoogleFonts.inter(
                              fontSize: isMobile ? 13.5 : 14.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Live daily performance meter',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: targetPct >= 1.0 ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: targetPct >= 1.0 ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 13, color: targetPct >= 1.0 ? const Color(0xFF047857) : const Color(0xFF2563EB)),
                    const SizedBox(width: 4),
                    Text(
                      '${(targetPct * 100).toInt()}% Done',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: targetPct >= 1.0 ? const Color(0xFF047857) : const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Big Counters Row
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                '${dash.telecallerCallsToday}',
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 32 : 38,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -1,
                ),
              ),
              Text(
                '/ ${dash.telecallerDailyTarget} calls target',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: remainingCalls == 0 ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: remainingCalls == 0 ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Text(
                  remainingCalls == 0
                      ? '🎉 Target reached!'
                      : '$remainingCalls calls to target',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: remainingCalls == 0 ? const Color(0xFF047857) : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 8,
              color: const Color(0xFFE2E8F0),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: targetPct,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF047857), Color(0xFF10B981)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Micro Stats Strip
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _buildMicroMetric(
                icon: Icons.timer_outlined,
                label: 'Talk Time',
                value: '${dash.telecallerTalkTimeMinutes}m today',
                color: const Color(0xFF0284C7),
              ),
              _buildMicroMetric(
                icon: Icons.thumb_up_alt_outlined,
                label: 'Interested Leads',
                value: '${dash.telecallerInterestedCount} converted',
                color: const Color(0xFF047857),
              ),
              _buildMicroMetric(
                icon: Icons.speed_rounded,
                label: 'Pacing',
                value: remainingCalls == 0 ? 'Goal Exceeded' : 'Approx ${(dash.telecallerDailyTarget / 8).ceil()} calls/hr',
                color: const Color(0xFFD97706),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMicroMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
        ),
      ],
    );
  }

  // ==========================================
  // 3. RESPONSIVE ZERO-OVERFLOW STAT CARDS
  // ==========================================
  Widget _buildLuxuryStatCards(DashboardProvider dash, bool isDesktop, bool isMobile) {
    final cards = [
      _StatCardItem(
        title: 'Assigned Leads',
        value: '${dash.telecallerAssignedLeads}',
        subtitle: '${dash.telecallerCompletedLeads} completed',
        icon: Icons.assignment_ind_rounded,
        badge: 'Queue',
        badgeColor: const Color(0xFF0284C7),
        accentGradient: const [Color(0xFF0284C7), Color(0xFF38BDF8)],
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LeadDirectoryScreen()),
          );
        },
      ),
      _StatCardItem(
        title: 'Callbacks Due Today',
        value: '${dash.telecallerCallbacksDueToday}',
        subtitle: dash.telecallerCallbacksDueToday > 0 ? 'Urgent follow-ups' : 'Queue cleared',
        icon: Icons.alarm_rounded,
        badge: 'Today',
        badgeColor: const Color(0xFFD97706),
        accentGradient: const [Color(0xFFD97706), Color(0xFFF59E0B)],
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CallbackScreen()),
          );
        },
      ),
      _StatCardItem(
        title: 'Upcoming Callbacks',
        value: '${dash.telecallerCallbacksUpcoming}',
        subtitle: 'Future follow-ups',
        icon: Icons.event_note_rounded,
        badge: 'Scheduled',
        badgeColor: const Color(0xFF7C3AED),
        accentGradient: const [Color(0xFF7C3AED), Color(0xFFA78BFA)],
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CallbackScreen()),
          );
        },
      ),
      _StatCardItem(
        title: 'Overdue Callbacks',
        value: '${dash.telecallerCallbacksOverdue}',
        subtitle: dash.telecallerCallbacksOverdue > 0 ? 'Immediate action required' : 'No overdue calls',
        icon: Icons.warning_amber_rounded,
        badge: dash.telecallerCallbacksOverdue > 0 ? 'Action Req' : 'Zero',
        badgeColor: dash.telecallerCallbacksOverdue > 0 ? const Color(0xFFDC2626) : const Color(0xFF047857),
        accentGradient: dash.telecallerCallbacksOverdue > 0
            ? const [Color(0xFFDC2626), Color(0xFFF87171)]
            : const [Color(0xFF047857), Color(0xFF10B981)],
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CallbackScreen()),
          );
        },
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: _buildStatCardView(c)))).toList(),
      );
    } else {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatCardView(cards[0], isCompact: true)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatCardView(cards[1], isCompact: true)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildStatCardView(cards[2], isCompact: true)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatCardView(cards[3], isCompact: true)),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildStatCardView(_StatCardItem item, {bool isCompact = false}) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(isCompact ? 12 : 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: item.accentGradient),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item.icon, size: 15, color: Colors.white),
                ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: item.badgeColor.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      item.badge,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: item.badgeColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isCompact ? 8 : 10),
            Text(
              item.value,
              style: GoogleFonts.inter(
                fontSize: isCompact ? 19 : 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              item.title,
              style: GoogleFonts.inter(
                fontSize: isCompact ? 11.5 : 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              item.subtitle,
              style: GoogleFonts.inter(
                fontSize: isCompact ? 10 : 10.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. PRIMARY CALLING WORKSTATION QUEUE
  // ==========================================
  Widget _buildMyAssignedLeadsQueue(BuildContext context, bool isMobile, String companyName) {
    final leadProvider = context.watch<LeadProvider>();
    final allLeads = leadProvider.leads;

    final filteredLeads = allLeads.where((lead) {
      if (_selectedStatusFilter != 'ALL') {
        if (_selectedStatusFilter == 'NEW' && !lead.status.toUpperCase().contains('NEW')) return false;
        if (_selectedStatusFilter == 'INTERESTED' && !lead.status.toUpperCase().contains('INTERESTED')) return false;
        if (_selectedStatusFilter == 'CALLBACK' && !lead.status.toUpperCase().contains('CALLBACK')) return false;
      }
      if (_queueSearchQuery.isNotEmpty) {
        final q = _queueSearchQuery.toLowerCase();
        final name = lead.fullName.toLowerCase();
        final phone = lead.phoneNumber.toLowerCase();
        final city = lead.city.toLowerCase();
        return name.contains(q) || phone.contains(q) || city.contains(q);
      }
      return true;
    }).toList();

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF047857), Color(0xFF10B981)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.playlist_play_rounded, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'My Assigned Calling Queue',
                                  style: GoogleFonts.inter(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: Text(
                                  '${allLeads.length} Total',
                                  style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF047857)),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Instant 1-tap call, WhatsApp follow-up & quotation',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LeadDirectoryScreen()));
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF047857)),
                label: Text('All Leads', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF047857))),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search Box & Filter Chips
          TextField(
            onChanged: (val) => setState(() => _queueSearchQuery = val.trim()),
            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Search assigned leads by name, phone or city...',
              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 17, color: Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
          ),
          const SizedBox(height: 10),

          // Filter Chips Row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildQueueFilterChip('ALL', 'All Leads (${allLeads.length})'),
              _buildQueueFilterChip('NEW', 'New / Uncalled'),
              _buildQueueFilterChip('INTERESTED', 'Interested'),
              _buildQueueFilterChip('CALLBACK', 'Callbacks'),
            ],
          ),
          const SizedBox(height: 14),

          if (filteredLeads.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.search_off_rounded, color: Color(0xFF94A3B8), size: 28),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No matching assigned leads',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try adjusting your search query or status filter above.',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredLeads.take(6).length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final lead = filteredLeads[index];
                return _buildQueueLeadTile(context, lead, isMobile, companyName);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQueueFilterChip(String filterKey, String label) {
    final isSelected = _selectedStatusFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _selectedStatusFilter = filterKey),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF047857) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF047857) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildQueueLeadTile(BuildContext context, LeadModel lead, bool isMobile, String companyName) {
    final statusColor = _getOutcomeColor(lead.status);

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar, Name + Status
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFF047857).withValues(alpha: 0.12),
                  child: Text(
                    lead.fullName.isNotEmpty ? lead.fullName[0].toUpperCase() : 'L',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF047857)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              lead.fullName,
                              style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                            ),
                            child: Text(
                              lead.status.replaceAll('_', ' '),
                              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${lead.phoneNumber}${lead.city.isNotEmpty ? ' • ${lead.city}' : ''}',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            const SizedBox(height: 8),

            // Clean 4-Action Touch Strip on Mobile: Call, WhatsApp, Log Outcome, Quote
            Row(
              children: [
                // 1. Direct Dial
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final phone = lead.normalizedPhone.isNotEmpty ? lead.normalizedPhone : lead.phoneNumber;
                      final uri = Uri.parse('tel:$phone');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => CallOutcomeDialog(
                            leadId: lead.id,
                            leadName: lead.fullName,
                            phoneNumber: lead.normalizedPhone.isNotEmpty ? lead.normalizedPhone : lead.phoneNumber,
                          ),
                        ).then((_) => _loadData());
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF047857),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.call_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Call',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 2. WhatsApp
                Expanded(
                  child: InkWell(
                    onTap: () {
                      _openWhatsApp(
                        phone: lead.normalizedPhone.isNotEmpty ? lead.normalizedPhone : lead.phoneNumber,
                        name: lead.fullName,
                        companyName: companyName,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Color(0xFF075E54)),
                          const SizedBox(width: 4),
                          Text(
                            'WhatsApp',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF075E54)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 3. Log Outcome
                Expanded(
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => CallOutcomeDialog(
                          leadId: lead.id,
                          leadName: lead.fullName,
                          phoneNumber: lead.normalizedPhone.isNotEmpty ? lead.normalizedPhone : lead.phoneNumber,
                        ),
                      ).then((_) => _loadData());
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_task_rounded, size: 13, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text(
                            'Outcome',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 4. Quote
                Expanded(
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => QuotationFormDialog(lead: lead),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.request_quote_rounded, size: 13, color: Color(0xFFB45309)),
                          const SizedBox(width: 4),
                          Text(
                            'Quote',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFB45309)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF047857).withValues(alpha: 0.12),
            child: Text(
              lead.fullName.isNotEmpty ? lead.fullName[0].toUpperCase() : 'L',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF047857)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        lead.fullName,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        lead.status,
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${lead.phoneNumber}${lead.city.isNotEmpty ? ' • ${lead.city}' : ''}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 6,
            children: [
              // 1. Call Button
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                  foregroundColor: const Color(0xFF047857),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(34, 34),
                ),
                icon: const Icon(Icons.call_rounded, size: 16),
                tooltip: 'Direct Call',
                onPressed: () async {
                  final phone = lead.normalizedPhone.isNotEmpty ? lead.normalizedPhone : lead.phoneNumber;
                  final uri = Uri.parse('tel:$phone');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => CallOutcomeDialog(
                        leadId: lead.id,
                        leadName: lead.fullName,
                        phoneNumber: lead.normalizedPhone.isNotEmpty ? lead.normalizedPhone : lead.phoneNumber,
                      ),
                    ).then((_) => _loadData());
                  }
                },
              ),

              // 2. WhatsApp Button
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.14),
                  foregroundColor: const Color(0xFF075E54),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(34, 34),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                tooltip: 'WhatsApp Message',
                onPressed: () {
                  _openWhatsApp(
                    phone: lead.normalizedPhone.isNotEmpty ? lead.normalizedPhone : lead.phoneNumber,
                    name: lead.fullName,
                    companyName: companyName,
                  );
                },
              ),

              // 3. Log Outcome Button
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  foregroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(34, 34),
                ),
                icon: const Icon(Icons.add_task_rounded, size: 16),
                tooltip: 'Log Call Outcome',
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => CallOutcomeDialog(
                      leadId: lead.id,
                      leadName: lead.fullName,
                      phoneNumber: lead.normalizedPhone.isNotEmpty ? lead.normalizedPhone : lead.phoneNumber,
                    ),
                  ).then((_) => _loadData());
                },
              ),

              // 4. Send Quotation Button
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  foregroundColor: const Color(0xFFB45309),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(34, 34),
                ),
                icon: const Icon(Icons.request_quote_rounded, size: 16),
                tooltip: 'Create Quotation',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => QuotationFormDialog(lead: lead),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. PRIORITY CALLBACKS CARD
  // ==========================================
  Widget _buildPriorityCallbacksCard(BuildContext context, DashboardProvider dash, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: const Icon(Icons.phone_callback_rounded, color: Color(0xFFB45309), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Priority Callbacks Due',
                            style: GoogleFonts.inter(fontSize: isMobile ? 14 : 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Scheduled customer return calls',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CallbackScreen()));
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('View All', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF047857))),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (dash.telecallerDueCallbacks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                    const SizedBox(height: 8),
                    Text(
                      'All callbacks cleared!',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'No urgent callbacks scheduled for right now.',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dash.telecallerDueCallbacks.take(4).length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final cb = dash.telecallerDueCallbacks[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: const Icon(Icons.phone_callback_rounded, color: Color(0xFFB45309), size: 14),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cb.leadName,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5, color: const Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              cb.leadPhone,
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                            if (cb.initialNotes.isNotEmpty)
                              Text(
                                cb.initialNotes,
                                style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF475569), fontStyle: FontStyle.italic),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const CallbackScreen()));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF047857),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            'Open',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // 6. RECENT ACTIVITY LEDGER
  // ==========================================
  Widget _buildRecentActivityLedger(DashboardProvider dash, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Icon(Icons.history_rounded, size: 18, color: Color(0xFF047857)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent Telecalling Log',
                            style: GoogleFonts.inter(fontSize: isMobile ? 14 : 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Live audit of dials completed today',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  'TODAY',
                  style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF047857)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (dash.telecallerRecentCalls.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF94A3B8), size: 28),
                    const SizedBox(height: 8),
                    Text(
                      'No calls logged yet today',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Dial your assigned leads above to start logging calls!',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dash.telecallerRecentCalls.take(4).length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final call = dash.telecallerRecentCalls[index];
                final outcomeColor = _getOutcomeColor(call.outcome);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: outcomeColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: outcomeColor.withValues(alpha: 0.35)),
                        ),
                        child: Icon(Icons.call_made_rounded, color: outcomeColor, size: 14),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    call.leadName,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5, color: const Color(0xFF0F172A)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: outcomeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    call.outcome,
                                    style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: outcomeColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${call.leadPhone}${call.durationSeconds > 0 ? ' • ${call.durationSeconds}s duration' : ''}',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _StatCardItem {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final String badge;
  final Color badgeColor;
  final List<Color> accentGradient;
  final VoidCallback onTap;

  _StatCardItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.badge,
    required this.badgeColor,
    required this.accentGradient,
    required this.onTap,
  });
}
