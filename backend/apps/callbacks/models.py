from django.db import models
from django.conf import settings
from apps.core.models import TenantModel, TimeStampedModel

class Callback(TenantModel):
    STATUS_CHOICES = [
        ('SCHEDULED', 'Scheduled'),
        ('DUE', 'Due'),
        ('COMPLETED', 'Completed'),
        ('OVERDUE', 'Overdue'),
        ('RESCHEDULED', 'Rescheduled'),
        ('CANCELLED', 'Cancelled'),
    ]

    lead = models.ForeignKey(
        'leads.Lead',
        on_delete=models.CASCADE,
        related_name='callbacks',
        db_index=True
    )
    assigned_employee = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='callbacks',
        db_index=True
    )
    originating_call_attempt = models.ForeignKey(
        'calls.CallAttempt',
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='resulted_callbacks'
    )
    scheduled_at = models.DateTimeField(db_index=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='SCHEDULED', db_index=True)
    initial_notes = models.TextField(blank=True)
    completion_notes = models.TextField(blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    rescheduled_count = models.PositiveIntegerField(default=0)
    last_rescheduled_at = models.DateTimeField(null=True, blank=True)
    reminder_sent = models.BooleanField(default=False)

    class Meta:
        ordering = ['scheduled_at']

    def __str__(self):
        return f"Callback for {self.lead} at {self.scheduled_at} ({self.status})"

class CallbackHistory(TimeStampedModel):
    callback = models.ForeignKey(
        Callback,
        on_delete=models.CASCADE,
        related_name='history'
    )
    changed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL
    )
    from_status = models.CharField(max_length=20)
    to_status = models.CharField(max_length=20)
    rescheduled_to = models.DateTimeField(null=True, blank=True)
    reason = models.TextField(blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"History for Callback {self.callback_id}: {self.from_status} -> {self.to_status}"
