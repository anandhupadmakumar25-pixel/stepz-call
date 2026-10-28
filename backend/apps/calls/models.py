from django.db import models
from django.conf import settings
from apps.core.models import TenantModel

class CallAttempt(TenantModel):
    OUTCOME_CHOICES = [
        ('ANSWERED', 'Answered'),
        ('BUSY', 'Busy'),
        ('NO_ANSWER', 'No Answer'),
        ('CALLBACK_REQUESTED', 'Callback Requested'),
        ('INTERESTED', 'Interested'),
        ('NOT_INTERESTED', 'Not Interested'),
        ('QUALIFIED', 'Qualified'),
        ('OTHER', 'Other'),
    ]

    lead = models.ForeignKey(
        'leads.Lead',
        on_delete=models.CASCADE,
        related_name='call_attempts',
        db_index=True
    )
    employee = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='call_attempts',
        db_index=True
    )
    outcome = models.CharField(max_length=32, choices=OUTCOME_CHOICES, db_index=True)
    notes = models.TextField()
    duration_seconds = models.PositiveIntegerField(default=0)
    dialer_launched_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Call on {self.lead} by {self.employee.email}: {self.outcome}"
