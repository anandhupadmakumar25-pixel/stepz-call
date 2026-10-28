from django.db import models
from django.conf import settings
from apps.core.models import TenantModel, TimeStampedModel

class Notification(TenantModel):
    TYPE_CHOICES = [
        ('CALLBACK_REMINDER', 'Callback Reminder'),
        ('CALLBACK_OVERDUE', 'Callback Overdue'),
        ('LEAD_ASSIGNED', 'Lead Assigned'),
        ('IMPORT_COMPLETED', 'Import Completed'),
        ('SYSTEM', 'System Alert'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications',
        db_index=True
    )
    title = models.CharField(max_length=255)
    message = models.TextField()
    notification_type = models.CharField(max_length=32, choices=TYPE_CHOICES, default='CALLBACK_REMINDER', db_index=True)
    entity_type = models.CharField(max_length=64, blank=True)
    entity_id = models.CharField(max_length=64, blank=True)
    is_read = models.BooleanField(default=False, db_index=True)
    read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.title} for {self.user.email} ({'Read' if self.is_read else 'Unread'})"

class PushDeviceToken(TimeStampedModel):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='push_tokens'
    )
    token = models.CharField(max_length=255, unique=True)
    device_type = models.CharField(max_length=32, default='android')
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"Token for {self.user.email} ({self.device_type})"
