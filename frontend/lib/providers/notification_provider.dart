import 'package:flutter/material.dart';
import '../core/network/api_client.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String notificationType;
  final String entityType;
  final String entityId;
  final bool isRead;
  final String createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    this.entityType = '',
    this.entityId = '',
    required this.isRead,
    required this.createdAt,
  });

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      title: title,
      message: message,
      notificationType: notificationType,
      entityType: entityType,
      entityId: entityId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      notificationType: json['notification_type'] ?? 'SYSTEM',
      entityType: json['entity_type']?.toString() ?? '',
      entityId: json['entity_id']?.toString() ?? '',
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
  List<NotificationItem> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();
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

  Future<void> markAsRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      if (_unreadCount > 0) _unreadCount--;
      notifyListeners();
    }
    try {
      await ApiClient.post('/notifications/$id/mark-read/', {});
    } catch (_) {}
  }

  Future<void> markAsUnread(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && _notifications[idx].isRead) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: false);
      _unreadCount++;
      notifyListeners();
    }
    try {
      await ApiClient.post('/notifications/$id/mark-unread/', {});
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await ApiClient.post('/notifications/mark-read/', {});
      _unreadCount = 0;
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      notifyListeners();
    } catch (_) {}
  }
}
