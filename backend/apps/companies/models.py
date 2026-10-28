from django.db import models
from apps.core.models import TimeStampedModel

class Company(TimeStampedModel):
    STATUS_CHOICES = [
        ('ACTIVE', 'Active'),
        ('SUSPENDED', 'Suspended'),
        ('TRIAL', 'Trial'),
    ]

    name = models.CharField(max_length=255)
    subdomain = models.CharField(max_length=100, unique=True, null=True, blank=True)
    contact_email = models.EmailField()
    contact_phone = models.CharField(max_length=32, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='ACTIVE', db_index=True)
    default_country_code = models.CharField(max_length=4, default='+91')
    default_country_iso = models.CharField(max_length=2, default='IN')
    settings = models.JSONField(default=dict, blank=True)

    class Meta:
        verbose_name_plural = 'Companies'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.name} ({self.status})"
