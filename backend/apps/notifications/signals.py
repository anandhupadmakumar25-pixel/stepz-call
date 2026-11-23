import logging
from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.notifications.models import Notification
from apps.notifications.services import send_push_for_notification

logger = logging.getLogger(__name__)


@receiver(post_save, sender=Notification)
def dispatch_push_on_notification_create(sender, instance, created, **kwargs):
    if not created:
        return
    try:
        send_push_for_notification(instance)
    except Exception as exc:
        logger.warning("Push dispatch error for notification %s: %s", instance.id, exc)
