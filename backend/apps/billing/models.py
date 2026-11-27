import uuid
from decimal import Decimal
from django.db import models
from django.conf import settings
from apps.core.models import TenantModel
from apps.billing.utils.number_to_words import amount_to_words_en, amount_to_words_ar


class DocumentTemplate(TenantModel):
    """
    Customizable, drag-and-drop document template per tenant company
    for Quotations, Bills/Invoices, and Receipt Vouchers.
    """
    DOC_TYPE_CHOICES = [
        ('QUOTATION', 'Quotation'),
        ('INVOICE', 'Bill / Invoice'),
        ('RECEIPT', 'Receipt Voucher'),
    ]

    name = models.CharField(max_length=120)
    doc_type = models.CharField(max_length=20, choices=DOC_TYPE_CHOICES, db_index=True)
    branch = models.ForeignKey(
        'leads.Branch',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='document_templates',
    )
    is_default = models.BooleanField(default=False, db_index=True)
    is_active = models.BooleanField(default=True, db_index=True)
    layout_json = models.JSONField(default=dict, blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='created_document_templates',
    )

    class Meta:
        ordering = ['-is_default', 'name']
        unique_together = ('company', 'doc_type', 'name')

    def __str__(self):
        return f"{self.name} ({self.doc_type})"


class Quotation(TenantModel):
    STATUS_CHOICES = [
        ('DRAFT', 'Draft'),
        ('PENDING_APPROVAL', 'Pending Approval'),
        ('APPROVED', 'Approved'),
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
    branch = models.ForeignKey(
        'leads.Branch',
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

    # Professional Quotation metadata
    client_code = models.CharField(max_length=64, blank=True)
    sales_rep_name = models.CharField(max_length=128, blank=True)
    incoterms = models.CharField(max_length=128, blank=True)
    location = models.CharField(max_length=128, blank=True)
    contact_person = models.CharField(max_length=128, blank=True)
    cr_number = models.CharField(max_length=64, blank=True)
    currency = models.CharField(max_length=10, default='INR')

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='created_quotations'
    )
    date = models.DateField(auto_now_add=True)
    valid_until = models.DateField(null=True, blank=True)

    items = models.JSONField(default=list, blank=True)
    custom_columns = models.JSONField(default=list, blank=True)
    subtotal = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    tax_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    discount_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    grand_total = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)

    # Internal Cost & Margin tracking
    total_cost = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    gross_margin = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    hide_cost_in_pdf = models.BooleanField(default=True)

    notes = models.TextField(blank=True)
    terms_and_conditions = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='DRAFT', db_index=True)
    approved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='approved_quotations',
    )
    approved_at = models.DateTimeField(null=True, blank=True)
    rejection_reason = models.TextField(blank=True)
    template = models.ForeignKey(
        DocumentTemplate,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='quotations',
    )
    template_snapshot = models.JSONField(default=dict, blank=True)

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
    branch = models.ForeignKey(
        'leads.Branch',
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

    # Professional Invoice metadata
    client_code = models.CharField(max_length=64, blank=True)
    sales_rep_name = models.CharField(max_length=128, blank=True)
    incoterms = models.CharField(max_length=128, blank=True)
    location = models.CharField(max_length=128, blank=True)
    contact_person = models.CharField(max_length=128, blank=True)
    cr_number = models.CharField(max_length=64, blank=True)
    currency = models.CharField(max_length=10, default='INR')

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='created_invoices'
    )
    date = models.DateField(auto_now_add=True)
    due_date = models.DateField(null=True, blank=True)

    items = models.JSONField(default=list, blank=True)
    custom_columns = models.JSONField(default=list, blank=True)
    subtotal = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    tax_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    discount_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    grand_total = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)

    # Internal Cost & Margin tracking
    total_cost = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    gross_margin = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    hide_cost_in_pdf = models.BooleanField(default=True)

    # Bilingual amount in words
    amount_in_words_en = models.TextField(blank=True)
    amount_in_words_ar = models.TextField(blank=True)

    amount_paid = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    payment_status = models.CharField(max_length=20, choices=PAYMENT_STATUS_CHOICES, default='PENDING', db_index=True)
    payment_mode = models.CharField(max_length=50, blank=True)  # UPI, Cash, Bank Transfer, Card, Cheque
    payment_reference = models.CharField(max_length=100, blank=True)
    payment_notes = models.TextField(blank=True)
    notes = models.TextField(blank=True)
    terms_and_conditions = models.TextField(blank=True)
    template = models.ForeignKey(
        DocumentTemplate,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='invoices',
    )
    template_snapshot = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ['-created_at']

    @property
    def balance_due(self):
        return max(0.0, float(self.grand_total) - float(self.amount_paid))

    def save(self, *args, **kwargs):
        if not self.amount_in_words_en and self.grand_total:
            self.amount_in_words_en = amount_to_words_en(self.grand_total, self.currency)
        if not self.amount_in_words_ar and self.grand_total:
            self.amount_in_words_ar = amount_to_words_ar(self.grand_total, self.currency)
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.invoice_number} - {self.customer_name} ({self.payment_status})"


class ReceiptVoucher(TenantModel):
    PAYMENT_METHOD_CHOICES = [
        ('CASH', 'Cash'),
        ('CHEQUE', 'Cheque'),
        ('BANK_TRANSFER', 'Bank Transfer'),
        ('CARD', 'Card'),
        ('ONLINE', 'Online Payment'),
    ]

    voucher_number = models.CharField(max_length=64, db_index=True)
    invoice = models.ForeignKey(
        Invoice,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='receipt_vouchers'
    )
    quotation = models.ForeignKey(
        Quotation,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='receipt_vouchers'
    )
    branch = models.ForeignKey(
        'leads.Branch',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='receipt_vouchers'
    )
    customer_name = models.CharField(max_length=150)
    customer_phone = models.CharField(max_length=32, blank=True)
    customer_email = models.EmailField(blank=True)
    date = models.DateField(auto_now_add=True)

    amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    currency = models.CharField(max_length=10, default='INR')

    # Financial balance breakdown (Total, Received, Previous, Balance Due)
    total_invoice_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    previously_paid = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    balance_due = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)

    # Bilingual amount in words
    amount_in_words_en = models.TextField(blank=True)
    amount_in_words_ar = models.TextField(blank=True)

    # Payment details
    payment_method = models.CharField(max_length=32, choices=PAYMENT_METHOD_CHOICES, default='CASH')
    cheque_number = models.CharField(max_length=64, blank=True)
    bank_name = models.CharField(max_length=128, blank=True)
    cheque_date = models.DateField(null=True, blank=True)
    payment_reference = models.CharField(max_length=100, blank=True)

    # Purpose / 'Being'
    being = models.TextField(blank=True)

    # Signatures & Auth
    receiver_name = models.CharField(max_length=128, blank=True)
    accountant_name = models.CharField(max_length=128, blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='created_receipt_vouchers'
    )

    # Official Rubber Stamp Watermark
    has_watermark_stamp = models.BooleanField(default=True)

    # Proof of Delivery (POD) slip
    include_pod_slip = models.BooleanField(default=False)
    pod_driver_name = models.CharField(max_length=128, blank=True)
    pod_receiver_name = models.CharField(max_length=128, blank=True)
    pod_receiver_phone = models.CharField(max_length=32, blank=True)
    pod_delivery_date = models.DateField(null=True, blank=True)
    pod_commodity = models.CharField(max_length=255, blank=True)

    notes = models.TextField(blank=True)
    template = models.ForeignKey(
        DocumentTemplate,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='receipt_vouchers',
    )
    template_snapshot = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ['-created_at']

    def save(self, *args, **kwargs):
        if self.invoice:
            if not self.total_invoice_amount and self.invoice.grand_total:
                self.total_invoice_amount = self.invoice.grand_total
            if not self.balance_due and self.invoice.grand_total:
                self.balance_due = max(0.00, float(self.invoice.grand_total) - float(self.invoice.amount_paid))
        if not self.amount_in_words_en and self.amount:
            self.amount_in_words_en = amount_to_words_en(self.amount, self.currency)
        if not self.amount_in_words_ar and self.amount:
            self.amount_in_words_ar = amount_to_words_ar(self.amount, self.currency)
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.voucher_number} - {self.customer_name} ({self.amount} {self.currency})"


class Product(TenantModel):
    item_code = models.CharField(max_length=64, blank=True, default='')
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
