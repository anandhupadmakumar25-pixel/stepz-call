import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/animated_status_badge.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../routes/app_routes.dart';
import '../../providers/call_provider.dart';

class CallHistoryScreen extends StatefulWidget {
  final String? initialEmployeeId;
  final String? employeeName;

  const CallHistoryScreen({super.key, this.initialEmployeeId, this.employeeName});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  String? _selectedEmployeeId;

  @override
  void initState() {
    super.initState();
    _selectedEmployeeId = widget.initialEmployeeId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CallProvider>().fetchCalls(employeeId: _selectedEmployeeId);
    });
  }

  Color _getOutcomeColor(String outcome) {
    switch (outcome.toUpperCase()) {
      case 'INTERESTED':
      case 'CONNECTED':
        return const Color(0xFF10B981);
      case 'CALLBACK_REQUESTED':
      case 'FOLLOW_UP':
        return const Color(0xFFF59E0B);
      case 'NOT_INTERESTED':
      case 'WRONG_NUMBER':
        return AppColors.neonCoral;
      case 'BUSY':
      case 'NO_ANSWER':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final callProvider = context.watch<CallProvider>();
    final isMobile = ResponsiveLayout.isMobile(context);

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
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const AppBackButton(fallbackRoute: AppRoutes.dashboard),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Telecalling Audit Trail',
                                      style: GoogleFonts.inter(
                                        fontSize: isMobile ? 18 : 22,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  AnimatedStatusBadge(
                                    label: '${callProvider.calls.length} Calls',
                                    statusColor: AppColors.neonCyan,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Chronological log of every dial attempt, duration, notes, and outcome',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.employeeName != null && _selectedEmployeeId != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF93C5FD)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.person_rounded, size: 14, color: Color(0xFF1D4ED8)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Filtered by Staff: ${widget.employeeName}',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                                      ),
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: () {
                                          setState(() => _selectedEmployeeId = null);
                                          context.read<CallProvider>().fetchCalls();
                                        },
                                        child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF1D4ED8)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.neonCyan),
                      onPressed: () => context.read<CallProvider>().fetchCalls(),
                      tooltip: 'Refresh Call History',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              Expanded(
                child: GlassCard(
                  blur: 20,
                  opacity: 0.12,
                  borderRadius: BorderRadius.circular(20),
                  borderColor: AppColors.glassBorder,
                  padding: const EdgeInsets.all(16),
                  child: callProvider.isLoading && callProvider.calls.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : callProvider.calls.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.neonCyan.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.history_rounded, size: 44, color: AppColors.neonCyan),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'No Call Attempts Logged',
                                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Calls initiated through the calling workspace will record their audit timeline here.',
                                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: callProvider.calls.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final call = callProvider.calls[index];
                                final outcomeColor = _getOutcomeColor(call.outcome);

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: outcomeColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: outcomeColor.withValues(alpha: 0.3)),
                                        ),
                                        child: Icon(Icons.phone_in_talk_rounded, size: 20, color: outcomeColor),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 8,
                                              runSpacing: 4,
                                              children: [
                                                Text(
                                                  call.leadName,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                    color: const Color(0xFF0F172A),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.neonCyan.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
                                                  ),
                                                  child: Text(
                                                    call.leadPhone,
                                                    style: GoogleFonts.robotoMono(
                                                      fontSize: 12,
                                                      color: AppColors.neonCyan,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                AnimatedStatusBadge(label: call.outcome, statusColor: outcomeColor),
                                              ],
                                            ),
                                            if (call.notes.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                call.notes,
                                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                                              ),
                                            ],
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 4,
                                              children: [
                                                Text(
                                                  'Caller: ${call.employeeName}',
                                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                                ),
                                                Text(
                                                  '• ${call.createdAt.length >= 16 ? call.createdAt.substring(0, 16).replaceAll('T', ' ') : call.createdAt}',
                                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.neonViolet.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '${call.durationSeconds}s',
                                                    style: GoogleFonts.robotoMono(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.neonViolet,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
