from decimal import Decimal
from rest_framework import serializers
from apps.billing.models import Quotation, Invoice, Product

class ProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = Product
        fields = [
            'id', 'name', 'description', 'unit_price', 'tax_percent',
            'unit', 'is_active', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']


class QuotationSerializer(serializers.ModelSerializer):
    created_by_name = serializers.CharField(source='created_by.get_full_name', read_only=True, default='')
    lead_name = serializers.CharField(source='lead.full_name', read_only=True, default='')

    class Meta:
        model = Quotation
        fields = [
            'id', 'quotation_number', 'lead', 'lead_name',
            'customer_name', 'customer_phone', 'customer_email', 'customer_address',
            'created_by', 'created_by_name', 'date', 'valid_until',
            'items', 'subtotal', 'tax_amount', 'discount_amount', 'grand_total',
            'notes', 'terms_and_conditions', 'status', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_by', 'created_by_name', 'date', 'created_at', 'updated_at']


class InvoiceSerializer(serializers.ModelSerializer):
    created_by_name = serializers.CharField(source='created_by.get_full_name', read_only=True, default='')
    quotation_number = serializers.CharField(source='quotation.quotation_number', read_only=True, default='')
    balance_due = serializers.FloatField(read_only=True)

    class Meta:
        model = Invoice
        fields = [
            'id', 'invoice_number', 'quotation', 'quotation_number', 'lead',
            'customer_name', 'customer_phone', 'customer_email', 'customer_address',
            'created_by', 'created_by_name', 'date', 'due_date',
            'items', 'subtotal', 'tax_amount', 'discount_amount', 'grand_total',
            'amount_paid', 'balance_due', 'payment_status', 'payment_mode',
            'payment_reference', 'payment_notes', 'notes', 'terms_and_conditions',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_by', 'created_by_name', 'date', 'balance_due', 'created_at', 'updated_at']


class RecordPaymentSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=12, decimal_places=2, min_value=Decimal('0.01'))
    payment_mode = serializers.CharField(max_length=50) # UPI, Cash, Bank Transfer, Card
    payment_reference = serializers.CharField(max_length=100, required=False, allow_blank=True, default='')
    notes = serializers.CharField(required=False, allow_blank=True, default='')
