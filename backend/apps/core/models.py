import uuid
from django.db import models
from django.conf import settings

class UUIDModel(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    class Meta:
        abstract = True

class TimeStampedModel(UUIDModel):
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True
        ordering = ['-created_at']

class TenantModel(TimeStampedModel):
    company = models.ForeignKey(
        'companies.Company',
        on_delete=models.CASCADE,
        related_name='%(app_label)s_%(class)s_set',
        db_index=True
    )

    class Meta:
        abstract = True
        ordering = ['-created_at']

class AuditEvent(TimeStampedModel):
    company = models.ForeignKey(
        'companies.Company',
        null=True,
        blank=True,
        on_delete=models.CASCADE,
        related_name='audit_events'
    )
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='actor_audit_events'
    )
    action = models.CharField(max_length=128)
    target_model = models.CharField(max_length=128)
    target_id = models.CharField(max_length=128, blank=True)
    details = models.JSONField(default=dict, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.action} on {self.target_model}:{self.target_id} by {self.actor}"
