from decimal import Decimal
from rest_framework import serializers
from apps.billing.models import Quotation, Invoice, ReceiptVoucher, Product
from apps.billing.utils.number_to_words import amount_to_words_en, amount_to_words_ar

class ProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = Product
        fields = [
            'id', 'name', 'description', 'unit_price', 'tax_percent',
            'unit', 'is_active', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']


class QuotationSerializer(serializers.ModelSerializer):
    quotation_number = serializers.CharField(required=False, allow_blank=True, default='')
    created_by_name = serializers.CharField(source='created_by.full_name', read_only=True, default='')
    lead_name = serializers.CharField(source='lead.full_name', read_only=True, default='')

    class Meta:
        model = Quotation
        fields = [
            'id', 'quotation_number', 'lead', 'lead_name',
            'customer_name', 'customer_phone', 'customer_email', 'customer_address',
            'client_code', 'sales_rep_name', 'incoterms', 'location', 'contact_person', 'cr_number',
            'currency', 'created_by', 'created_by_name', 'date', 'valid_until',
            'items', 'custom_columns', 'subtotal', 'tax_amount', 'discount_amount', 'grand_total',
            'total_cost', 'gross_margin', 'hide_cost_in_pdf',
            'notes', 'terms_and_conditions', 'status', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_by', 'created_by_name', 'date', 'created_at', 'updated_at']


class InvoiceSerializer(serializers.ModelSerializer):
    invoice_number = serializers.CharField(required=False, allow_blank=True, default='')
    created_by_name = serializers.CharField(source='created_by.full_name', read_only=True, default='')
    quotation_number = serializers.CharField(source='quotation.quotation_number', read_only=True, default='')
    balance_due = serializers.FloatField(read_only=True)

    class Meta:
        model = Invoice
        fields = [
            'id', 'invoice_number', 'quotation', 'quotation_number', 'lead',
            'customer_name', 'customer_phone', 'customer_email', 'customer_address',
            'client_code', 'sales_rep_name', 'incoterms', 'location', 'contact_person', 'cr_number',
            'currency', 'created_by', 'created_by_name', 'date', 'due_date',
            'items', 'custom_columns', 'subtotal', 'tax_amount', 'discount_amount', 'grand_total',
            'total_cost', 'gross_margin', 'hide_cost_in_pdf',
            'amount_in_words_en', 'amount_in_words_ar',
            'amount_paid', 'balance_due', 'payment_status', 'payment_mode',
            'payment_reference', 'payment_notes', 'notes', 'terms_and_conditions',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_by', 'created_by_name', 'date', 'balance_due', 'created_at', 'updated_at']


class ReceiptVoucherSerializer(serializers.ModelSerializer):
    voucher_number = serializers.CharField(required=False, allow_blank=True, default='')
    created_by_name = serializers.CharField(source='created_by.full_name', read_only=True, default='')
    invoice_number = serializers.CharField(source='invoice.invoice_number', read_only=True, default='')
    quotation_number = serializers.CharField(source='quotation.quotation_number', read_only=True, default='')

    class Meta:
        model = ReceiptVoucher
        fields = [
            'id', 'voucher_number', 'invoice', 'invoice_number', 'quotation', 'quotation_number',
            'customer_name', 'customer_phone', 'customer_email', 'date',
            'amount', 'currency', 'total_invoice_amount', 'previously_paid', 'balance_due',
            'amount_in_words_en', 'amount_in_words_ar',
            'payment_method', 'cheque_number', 'bank_name', 'cheque_date', 'payment_reference',
            'being', 'receiver_name', 'accountant_name',
            'created_by', 'created_by_name',
            'has_watermark_stamp', 'include_pod_slip',
            'pod_driver_name', 'pod_receiver_name', 'pod_receiver_phone', 'pod_delivery_date', 'pod_commodity',
            'notes', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_by', 'created_by_name', 'date', 'created_at', 'updated_at']


class RecordPaymentSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=12, decimal_places=2, min_value=Decimal('0.01'))
    payment_mode = serializers.CharField(max_length=50)  # Cash, Cheque, Bank Transfer, Card
    payment_reference = serializers.CharField(max_length=100, required=False, allow_blank=True, default='')
    notes = serializers.CharField(required=False, allow_blank=True, default='')

    # Optional receipt voucher fields
    generate_receipt = serializers.BooleanField(required=False, default=True)
    cheque_number = serializers.CharField(max_length=64, required=False, allow_blank=True, default='')
    bank_name = serializers.CharField(max_length=128, required=False, allow_blank=True, default='')
    cheque_date = serializers.DateField(required=False, allow_null=True, default=None)
    receiver_name = serializers.CharField(max_length=128, required=False, allow_blank=True, default='')
    accountant_name = serializers.CharField(max_length=128, required=False, allow_blank=True, default='')
    has_watermark_stamp = serializers.BooleanField(required=False, default=True)
    include_pod_slip = serializers.BooleanField(required=False, default=False)
    pod_driver_name = serializers.CharField(max_length=128, required=False, allow_blank=True, default='')
    pod_receiver_name = serializers.CharField(max_length=128, required=False, allow_blank=True, default='')
    pod_receiver_phone = serializers.CharField(max_length=32, required=False, allow_blank=True, default='')
    pod_commodity = serializers.CharField(max_length=255, required=False, allow_blank=True, default='')
