import uuid
from django.db import models
from django.conf import settings
from apps.core.models import TenantModel, TimeStampedModel

class PermanentPhoneNumberRegistry(TimeStampedModel):
    """
    Mandatory invariant of the product:
    A normalized phone number may be assigned only once within the lifetime of a company's records.
    Scoped per company. Survives active lead deletion or archiving.
    """
    company = models.ForeignKey(
        'companies.Company',
        on_delete=models.CASCADE,
        related_name='permanent_phone_registry',
        db_index=True
    )
    normalized_phone = models.CharField(max_length=32, db_index=True)
    first_assigned_at = models.DateTimeField(auto_now_add=True)
    first_assigned_to = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='+'
    )
    original_lead_id = models.CharField(max_length=64, blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['company', 'normalized_phone'],
                name='unique_company_normalized_phone'
            )
        ]
        verbose_name = 'Permanent Phone Number Registry Entry'
        verbose_name_plural = 'Permanent Phone Number Registry'
        ordering = ['-first_assigned_at']

    def __str__(self):
        return f"{self.normalized_phone} (Company: {self.company.name})"

class ImportBatch(TenantModel):
    STATUS_CHOICES = [
        ('PENDING', 'Pending Preview'),
        ('CONFIRMED', 'Confirmed & Imported'),
        ('FAILED', 'Failed'),
        ('CANCELLED', 'Cancelled'),
    ]

    uploaded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        on_delete=models.SET_NULL,
        related_name='import_batches'
    )
    file_name = models.CharField(max_length=255)
    total_rows = models.PositiveIntegerField(default=0)
    valid_new_count = models.PositiveIntegerField(default=0)
    duplicate_in_file_count = models.PositiveIntegerField(default=0)
    previously_registered_count = models.PositiveIntegerField(default=0)
    permanently_blocked_count = models.PositiveIntegerField(default=0)
    invalid_rows_count = models.PositiveIntegerField(default=0)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING', db_index=True)
    staging_data = models.JSONField(default=list, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Import {self.file_name} ({self.status}) - {self.total_rows} rows"

class ImportRowError(TimeStampedModel):
    ERROR_TYPES = [
        ('DUPLICATE_IN_FILE', 'Duplicate In Uploaded File'),
        ('PERMANENTLY_BLOCKED', 'Permanently Blocked / Previously Assigned in Company'),
        ('EXISTING_IN_DB', 'Already Exists as Active/Unassigned Lead'),
        ('INVALID_NUMBER', 'Invalid Phone Number Format'),
        ('MISSING_REQUIRED', 'Missing Required Field'),
    ]

    import_batch = models.ForeignKey(
        ImportBatch,
        on_delete=models.CASCADE,
        related_name='row_errors'
    )
    row_number = models.PositiveIntegerField()
    raw_name = models.CharField(max_length=255, blank=True)
    raw_phone = models.CharField(max_length=64, blank=True)
    error_type = models.CharField(max_length=32, choices=ERROR_TYPES)
    details = models.TextField()

    class Meta:
        ordering = ['row_number']

    def __str__(self):
        return f"Row {self.row_number}: {self.error_type} - {self.details}"

class Lead(TenantModel):
    STATUS_CHOICES = [
        ('UNASSIGNED', 'Unassigned'),
        ('ASSIGNED', 'Assigned'),
        ('IN_PROGRESS', 'In Progress'),
        ('CALLBACK_REQUESTED', 'Callback Requested'),
        ('QUALIFIED', 'Qualified'),
        ('NOT_INTERESTED', 'Not Interested'),
        ('BUSY', 'Busy'),
        ('NO_ANSWER', 'No Answer'),
        ('COMPLETED', 'Completed'),
        ('BLOCKED', 'Permanently Blocked'),
        ('ARCHIVED', 'Archived'),
    ]

    first_name = models.CharField(max_length=128)
    last_name = models.CharField(max_length=128, blank=True)
    raw_phone = models.CharField(max_length=32)
    normalized_phone = models.CharField(max_length=32, db_index=True)
    email = models.EmailField(blank=True)
    city = models.CharField(max_length=100, blank=True)
    state = models.CharField(max_length=100, blank=True)
    source = models.CharField(max_length=100, blank=True, default='MANUAL')
    import_batch = models.ForeignKey(
        ImportBatch,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='leads'
    )
    status = models.CharField(max_length=30, choices=STATUS_CHOICES, default='UNASSIGNED', db_index=True)
    assigned_to = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='assigned_leads'
    )
    assigned_at = models.DateTimeField(null=True, blank=True)
    is_assigned_ever = models.BooleanField(default=False, db_index=True)
    custom_fields = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.full_name} ({self.normalized_phone}) - {self.status}"

    @property
    def full_name(self):
        return f"{self.first_name} {self.last_name}".strip() or "Unnamed Lead"

class LeadAssignmentHistory(TenantModel):
    METHOD_CHOICES = [
        ('EQUAL', 'Equal Distribution'),
        ('PERCENTAGE', 'Percentage Split'),
        ('CUSTOM', 'Custom Count Allocation'),
        ('MANUAL', 'Manual Single Assignment'),
    ]

    lead = models.ForeignKey(
        Lead,
        on_delete=models.CASCADE,
        related_name='assignment_history'
    )
    assigned_to = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='received_assignments'
    )
    assigned_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        on_delete=models.SET_NULL,
        related_name='made_assignments'
    )
    assignment_method = models.CharField(max_length=20, choices=METHOD_CHOICES, default='MANUAL')
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Lead {self.lead_id} assigned to {self.assigned_to.email} by {self.assignment_method}"
