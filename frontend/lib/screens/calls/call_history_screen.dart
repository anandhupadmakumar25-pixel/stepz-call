import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/empty_state.dart';
import '../../providers/call_provider.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CallProvider>().fetchCalls();
    });
  }

  @override
  Widget build(BuildContext context) {
    final callProvider = context.watch<CallProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Call History Log', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('Comprehensive log of every telecalling attempt and outcome notes', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => context.read<CallProvider>().fetchCalls(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: Card(
                child: callProvider.isLoading && callProvider.calls.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : callProvider.calls.isEmpty
                        ? const EmptyState(
                            icon: Icons.history,
                            title: 'No call attempts logged yet',
                            description: 'Calls initiated through the dialer will record their outcomes here.',
                          )
                        : ListView.separated(
                            itemCount: callProvider.calls.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final call = callProvider.calls[index];
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSecondary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.phone_outlined, size: 20),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      call.leadName,
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${call.leadPhone})',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'monospace'),
                                    ),
                                    const SizedBox(width: 12),
                                    StatusBadge(status: call.outcome),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      call.notes,
                                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Called by ${call.employeeName} • ${call.createdAt.substring(0, 16).replaceAll('T', ' ')} • Duration: ${call.durationSeconds}s',
                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
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
    );
  }
}
