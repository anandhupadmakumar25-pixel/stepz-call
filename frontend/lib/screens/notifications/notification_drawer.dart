import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/animated_status_badge.dart';
import '../../providers/notification_provider.dart';

class NotificationDrawer extends StatefulWidget {
  final void Function(NotificationItem item)? onNavigateNotification;

  const NotificationDrawer({super.key, this.onNavigateNotification});

  @override
  State<NotificationDrawer> createState() => _NotificationDrawerState();
}

class _NotificationDrawerState extends State<NotificationDrawer> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();
    final items = _unreadOnly
        ? notifProvider.unreadNotifications
        : notifProvider.notifications;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.98),
          border: const Border(
            left: BorderSide(
              color: Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(-4, 0),
            ),
          ],
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: SafeArea(
              child: Column(
                children: [
                  // Drawer Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 14, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.notifications_rounded, size: 18, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Notifications',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            if (notifProvider.unreadCount > 0) ...[
                              const SizedBox(width: 8),
                              AnimatedStatusBadge(
                                label: '${notifProvider.unreadCount}',
                                statusColor: AppColors.neonCoral,
                              ),
                            ],
                          ],
                        ),
                        if (notifProvider.unreadCount > 0)
                          InkWell(
                            onTap: notifProvider.markAllRead,
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Text(
                                'Mark all read',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // All / Unread Filter Tabs
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: _FilterTab(
                            label: 'All (${notifProvider.notifications.length})',
                            selected: !_unreadOnly,
                            onTap: () => setState(() => _unreadOnly = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _FilterTab(
                            label: 'Unread (${notifProvider.unreadCount})',
                            selected: _unreadOnly,
                            onTap: () => setState(() => _unreadOnly = true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFFE2E8F0), height: 1),

                  // Notifications List
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.notifications_off_outlined, size: 36, color: Color(0xFF2563EB)),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _unreadOnly ? 'No Unread Notifications' : 'All Caught Up',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _unreadOnly
                                      ? 'All notifications have been read.'
                                      : 'No new telecaller alerts or reminders.',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: notifProvider.fetchNotifications,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              itemCount: items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                final isOverdue = item.notificationType == 'CALLBACK_OVERDUE';
                                final isCallback = item.notificationType.contains('CALLBACK');
                                final Color accent = isOverdue
                                    ? AppColors.danger
                                    : (isCallback ? const Color(0xFF2563EB) : const Color(0xFF8B5CF6));

                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () async {
                                      if (!item.isRead) {
                                        await notifProvider.markAsRead(item.id);
                                      }
                                      if (context.mounted && Navigator.canPop(context)) {
                                        Navigator.pop(context);
                                      }
                                      widget.onNavigateNotification?.call(item);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: item.isRead
                                            ? const Color(0xFFF8FAFC)
                                            : accent.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: item.isRead
                                              ? const Color(0xFFE2E8F0)
                                              : accent.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: accent.withValues(alpha: 0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              isOverdue
                                                  ? Icons.warning_amber_rounded
                                                  : (isCallback ? Icons.alarm_rounded : Icons.info_outline_rounded),
                                              size: 16,
                                              color: accent,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        item.title,
                                                        style: GoogleFonts.inter(
                                                          fontSize: 13,
                                                          fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                                                          color: const Color(0xFF0F172A),
                                                        ),
                                                      ),
                                                    ),
                                                    if (!item.isRead)
                                                      Container(
                                                        width: 7,
                                                        height: 7,
                                                        margin: const EdgeInsets.only(left: 6),
                                                        decoration: BoxDecoration(
                                                          color: accent,
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  item.message,
                                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), height: 1.3),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Tap to open',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: accent,
                                                      ),
                                                    ),
                                                    InkWell(
                                                      onTap: () {
                                                        if (item.isRead) {
                                                          notifProvider.markAsUnread(item.id);
                                                        } else {
                                                          notifProvider.markAsRead(item.id);
                                                        }
                                                      },
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                        child: Text(
                                                          item.isRead ? 'Mark unread' : 'Mark read',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w600,
                                                            color: const Color(0xFF475569),
                                                          ),
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
                                    ),
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
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF047857) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
