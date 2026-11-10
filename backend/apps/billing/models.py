import uuid
from django.db import models
from django.conf import settings
from apps.core.models import TenantModel

class Quotation(TenantModel):
    STATUS_CHOICES = [
        ('DRAFT', 'Draft'),
        ('SENT', 'Sent to Customer'),
        ('ACCEPTED', 'Accepted / Approved'),
        ('REJECTED', 'Rejected'),
        ('CONVERTED', 'Converted to Invoice'),
        ('EXPIRED', 'Expired'),
    ]

    lead = models.ForeignKey(
        'leads.Lead',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='quotations'
    )
    quotation_number = models.CharField(max_length=64, db_index=True)
    customer_name = models.CharField(max_length=150)
    customer_phone = models.CharField(max_length=32)
    customer_email = models.EmailField(blank=True)
    customer_address = models.TextField(blank=True)

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='created_quotations'
    )
    date = models.DateField(auto_now_add=True)
    valid_until = models.DateField(null=True, blank=True)

    items = models.JSONField(default=list, blank=True)
    subtotal = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    tax_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    discount_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    grand_total = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)

    notes = models.TextField(blank=True)
    terms_and_conditions = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='DRAFT', db_index=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.quotation_number} - {self.customer_name} ({self.company.name})"


class Invoice(TenantModel):
    PAYMENT_STATUS_CHOICES = [
        ('PENDING', 'Pending Payment'),
        ('PARTIAL', 'Partially Paid'),
        ('PAID', 'Fully Paid'),
        ('CANCELLED', 'Cancelled'),
    ]

    quotation = models.ForeignKey(
        Quotation,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='invoices'
    )
    lead = models.ForeignKey(
        'leads.Lead',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='invoices'
    )
    invoice_number = models.CharField(max_length=64, db_index=True)
    customer_name = models.CharField(max_length=150)
    customer_phone = models.CharField(max_length=32)
    customer_email = models.EmailField(blank=True)
    customer_address = models.TextField(blank=True)

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='created_invoices'
    )
    date = models.DateField(auto_now_add=True)
    due_date = models.DateField(null=True, blank=True)

    items = models.JSONField(default=list, blank=True)
    subtotal = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    tax_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    discount_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    grand_total = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)

    amount_paid = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    payment_status = models.CharField(max_length=20, choices=PAYMENT_STATUS_CHOICES, default='PENDING', db_index=True)
    payment_mode = models.CharField(max_length=50, blank=True)  # UPI, Cash, Bank Transfer, Card
    payment_reference = models.CharField(max_length=100, blank=True)
    payment_notes = models.TextField(blank=True)
    notes = models.TextField(blank=True)
    terms_and_conditions = models.TextField(blank=True)

    class Meta:
        ordering = ['-created_at']

    @property
    def balance_due(self):
        return max(0.0, float(self.grand_total) - float(self.amount_paid))

    def __str__(self):
        return f"{self.invoice_number} - {self.customer_name} ({self.payment_status})"



class Product(TenantModel):
    name = models.CharField(max_length=255, db_index=True)
    description = models.TextField(blank=True)
    unit_price = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    tax_percent = models.DecimalField(max_digits=5, decimal_places=2, default=18.00)
    unit = models.CharField(max_length=50, blank=True, default='unit')
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['name']
        unique_together = ('company', 'name')

    def __str__(self):
        return f"{self.name} ({self.unit_price})"
