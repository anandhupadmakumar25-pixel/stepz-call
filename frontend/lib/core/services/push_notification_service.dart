import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../network/api_client.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  bool _initialized = false;
  bool _listenersAttached = false;
  String? _lastRegisteredToken;

  static const String _apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyARM09F0FUHQSUi1PMezEerveHK3RHShMQ',
  );
  static const String _appId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '1:800980554425:web:08be0780abe4377171c168',
  );
  static const String _senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '800980554425',
  );
  static const String _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'stepz-call',
  );
  static const String _vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

  /// Maps backend `notification_type` / `entity_type` to a MainLayout `routeKey`.
  static String resolveRouteKey(String notificationType, String entityType) {
    final type = notificationType.toUpperCase();
    final entity = entityType.toLowerCase();

    if (entity == 'callback' || type.contains('CALLBACK')) return 'callbacks';
    if (entity == 'lead' || type == 'LEAD_ASSIGNED' || type == 'IMPORT_COMPLETED') return 'leads';
    if (entity == 'task' || entity == 'calling_task') return 'tasks';
    if (entity == 'attendance' || entity == 'field_visit') return 'attendance';
    if (entity == 'leave' || entity == 'payroll' || entity == 'regularization') return 'hr_payroll';
    if (entity == 'quotation') return 'quotations';
    if (entity == 'invoice' || entity == 'receipt' || entity == 'billing') return 'billing';
    if (entity == 'company' || entity == 'renewal_request' || entity == 'feature_request') return 'companies';
    if (entity == 'call_recording') return 'recordings';
    if (entity == 'call_attempt') return 'call_history';
    return 'dashboard';
  }

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (Firebase.apps.isEmpty) {
        if (_apiKey.isNotEmpty && _appId.isNotEmpty && _senderId.isNotEmpty && _projectId.isNotEmpty) {
          await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: _apiKey,
              appId: _appId,
              messagingSenderId: _senderId,
              projectId: _projectId,
            ),
          );
        } else if (!kIsWeb) {
          await Firebase.initializeApp();
        } else {
          // Web without explicit FirebaseOptions configured: skip cleanly.
          return;
        }
      }
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      }
      _initialized = true;
    } catch (e) {
      debugPrint('Firebase initialization skipped (not configured): $e');
    }
  }

  Future<void> registerDeviceToken() async {
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return;

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = kIsWeb && _vapidKey.isNotEmpty
          ? await messaging.getToken(vapidKey: _vapidKey)
          : await messaging.getToken();

      if (token != null && token.isNotEmpty && token != _lastRegisteredToken) {
        await _sendTokenToBackend(token);
      }

      messaging.onTokenRefresh.listen((newToken) {
        if (newToken.isNotEmpty) {
          _sendTokenToBackend(newToken);
        }
      });
    } catch (e) {
      debugPrint('FCM token registration skipped: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      final deviceType = kIsWeb
          ? 'web'
          : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
      await ApiClient.post('/notifications/register-token/', {
        'token': token,
        'device_type': deviceType,
      });
      _lastRegisteredToken = token;
    } catch (e) {
      debugPrint('Failed to register push token with backend: $e');
    }
  }

  void attachListeners({
    required void Function(RemoteMessage message) onForegroundMessage,
    required void Function(Map<String, dynamic> data) onNotificationOpened,
  }) {
    if (!_initialized || _listenersAttached) return;
    _listenersAttached = true;

    try {
      FirebaseMessaging.onMessage.listen(onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        onNotificationOpened(message.data);
      });
      FirebaseMessaging.instance.getInitialMessage().then((initialMessage) {
        if (initialMessage != null) {
          onNotificationOpened(initialMessage.data);
        }
      });
    } catch (e) {
      debugPrint('Failed to attach FCM listeners: $e');
    }
  }
}
