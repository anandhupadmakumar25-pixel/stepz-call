import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/notification_provider.dart';

class NotificationDrawer extends StatelessWidget {
  const NotificationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Notifications',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      if (notifProvider.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentViolet,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${notifProvider.unreadCount}',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                  TextButton(
                    onPressed: notifProvider.markAllRead,
                    child: Text('Mark all read', style: GoogleFonts.inter(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: notifProvider.notifications.isEmpty
                  ? Center(
                      child: Text(
                        'No notifications',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: notifProvider.notifications.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = notifProvider.notifications[index];
                        return ListTile(
                          tileColor: item.isRead ? Colors.transparent : AppColors.accentVioletLight.withValues(alpha: 0.4),
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: item.notificationType == 'CALLBACK_OVERDUE'
                                ? AppColors.dangerLight
                                : AppColors.accentVioletLight,
                            child: Icon(
                              item.notificationType == 'CALLBACK_OVERDUE'
                                  ? Icons.warning_amber_rounded
                                  : Icons.alarm,
                              size: 16,
                              color: item.notificationType == 'CALLBACK_OVERDUE'
                                  ? AppColors.danger
                                  : AppColors.accentViolet,
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            item.message,
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
