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

class CallRecording(TenantModel):
    SOURCE_CHOICES = [
        ('SYSTEM_CALL_RECORDER', 'System 2-Way Call Recorder (Headset + Client)'),
        ('AUTO_CALL_CAPTURE', 'Automatic Call Capture'),
        ('MIC_RECORDING', 'Microphone / Browser Audio'),
        ('VOIP_GATEWAY', 'VoIP Gateway Stream'),
        ('AUTHORIZED_UPLOAD', 'Authorized Audio Upload'),
    ]

    call_attempt = models.ForeignKey(
        CallAttempt,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='recordings'
    )
    lead = models.ForeignKey(
        'leads.Lead',
        on_delete=models.CASCADE,
        related_name='recordings',
        db_index=True
    )
    employee = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='call_recordings',
        db_index=True
    )
    audio_file = models.FileField(upload_to='call_recordings/%Y/%m/%d/', blank=True, null=True)
    duration_seconds = models.PositiveIntegerField(default=0)
    file_size_bytes = models.PositiveIntegerField(default=0)
    source = models.CharField(max_length=32, choices=SOURCE_CHOICES, default='MIC_RECORDING')
    notes = models.TextField(blank=True)
    waveform_data = models.JSONField(default=list, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Recording for {self.lead} ({self.duration_seconds}s) by {self.employee.email}"
