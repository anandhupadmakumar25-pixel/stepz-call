import 'package:flutter/material.dart';
import '../core/network/api_client.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String notificationType;
  final bool isRead;
  final String createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      notificationType: json['notification_type'] ?? 'SYSTEM',
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class NotificationProvider extends ChangeNotifier {
  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  Future<void> fetchNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiClient.get('/notifications/');
      _unreadCount = res['unread_count'] ?? 0;
      if (res['notifications'] != null) {
        _notifications = (res['notifications'] as List)
            .map((n) => NotificationItem.fromJson(n))
            .toList();
      }
    } catch (_) {}
    finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    try {
      await ApiClient.post('/notifications/mark-read/', {});
      _unreadCount = 0;
      _notifications = _notifications
          .map((n) => NotificationItem(
                id: n.id,
                title: n.title,
                message: n.message,
                notificationType: n.notificationType,
                isRead: true,
                createdAt: n.createdAt,
              ))
          .toList();
      notifyListeners();
    } catch (_) {}
  }
}
