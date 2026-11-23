import json
import logging
import os
import requests

from apps.notifications.models import PushDeviceToken

logger = logging.getLogger(__name__)

_firebase_app = None


def _get_firebase_app():
    global _firebase_app
    if _firebase_app is not None:
        return _firebase_app

    creds_json = os.environ.get('FIREBASE_CREDENTIALS_JSON', '').strip()
    creds_path = os.environ.get('GOOGLE_APPLICATION_CREDENTIALS', '').strip()
    if not creds_json and not creds_path:
        return None

    try:
        import firebase_admin
        from firebase_admin import credentials

        if firebase_admin._apps:
            _firebase_app = firebase_admin.get_app()
            return _firebase_app

        if creds_json:
            cred = credentials.Certificate(json.loads(creds_json))
        else:
            cred = credentials.Certificate(creds_path)

        _firebase_app = firebase_admin.initialize_app(cred)
        return _firebase_app
    except Exception as exc:
        logger.warning("Firebase Admin initialization skipped: %s", exc)
        return None


def send_push_for_notification(notification):
    """
    Dispatches a Firebase Cloud Messaging push notification to all active
    device tokens belonging to `notification.user`.
    Supports Firebase Admin SDK (HTTP v1 via FIREBASE_CREDENTIALS_JSON or
    GOOGLE_APPLICATION_CREDENTIALS) and legacy FCM_SERVER_KEY fallback.
    Fails gracefully when Firebase credentials are not configured.
    """
    tokens = list(
        PushDeviceToken.objects.filter(user=notification.user, is_active=True)
        .values_list('token', flat=True)
    )
    if not tokens:
        return 0

    data_payload = {
        'notification_id': str(notification.id),
        'notification_type': str(notification.notification_type or 'SYSTEM'),
        'entity_type': str(notification.entity_type or ''),
        'entity_id': str(notification.entity_id or ''),
        'title': str(notification.title or ''),
        'body': str(notification.message or ''),
    }

    app = _get_firebase_app()
    if app is not None:
        try:
            from firebase_admin import messaging

            msg = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title=notification.title,
                    body=notification.message,
                ),
                data=data_payload,
                tokens=tokens,
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        channel_id='stepz_call_notifications',
                        click_action='FLUTTER_NOTIFICATION_CLICK',
                    ),
                ),
            )
            batch_response = messaging.send_each_for_multicast(msg, app=app)
            for idx, resp in enumerate(batch_response.responses):
                if not resp.success and resp.exception:
                    err_str = str(resp.exception).lower()
                    if 'unregistered' in err_str or 'not-found' in err_str or 'invalid-argument' in err_str:
                        PushDeviceToken.objects.filter(token=tokens[idx]).update(is_active=False)
            return batch_response.success_count
        except Exception as exc:
            logger.warning("FCM v1 push failed: %s", exc)

    legacy_key = os.environ.get('FCM_SERVER_KEY', '').strip()
    if legacy_key:
        sent = 0
        headers = {
            'Authorization': f'key={legacy_key}',
            'Content-Type': 'application/json',
        }
        for tok in tokens:
            try:
                resp = requests.post(
                    'https://fcm.googleapis.com/fcm/send',
                    headers=headers,
                    json={
                        'to': tok,
                        'notification': {
                            'title': notification.title,
                            'body': notification.message,
                        },
                        'data': data_payload,
                        'priority': 'high',
                    },
                    timeout=5,
                )
                if resp.status_code == 200:
                    body = resp.json()
                    if body.get('success'):
                        sent += 1
                    elif body.get('results') and body['results'][0].get('error') in ('NotRegistered', 'InvalidRegistration'):
                        PushDeviceToken.objects.filter(token=tok).update(is_active=False)
            except Exception as exc:
                logger.warning("Legacy FCM push failed: %s", exc)
        return sent

    return 0
