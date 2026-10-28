from rest_framework import serializers
from apps.leads.models import Lead, ImportBatch, ImportRowError, PermanentPhoneNumberRegistry, LeadAssignmentHistory

class LeadSerializer(serializers.ModelSerializer):
    assigned_to_name = serializers.CharField(source='assigned_to.full_name', read_only=True)
    full_name = serializers.CharField(read_only=True)

    class Meta:
        model = Lead
        fields = [
            'id', 'first_name', 'last_name', 'full_name', 'raw_phone', 'normalized_phone',
            'email', 'city', 'state', 'source', 'status', 'assigned_to', 'assigned_to_name',
            'assigned_at', 'is_assigned_ever', 'custom_fields', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'normalized_phone', 'assigned_at', 'is_assigned_ever', 'created_at', 'updated_at']

class LeadDetailSerializer(LeadSerializer):
    call_attempts_count = serializers.SerializerMethodField()
    callbacks_count = serializers.SerializerMethodField()

    class Meta(LeadSerializer.Meta):
        fields = LeadSerializer.Meta.fields + ['call_attempts_count', 'callbacks_count']

    def get_call_attempts_count(self, obj):
        return obj.call_attempts.count()

    def get_callbacks_count(self, obj):
        return obj.callbacks.count()

class ImportRowErrorSerializer(serializers.ModelSerializer):
    class Meta:
        model = ImportRowError
        fields = ['id', 'row_number', 'raw_name', 'raw_phone', 'error_type', 'details']

class ImportBatchSerializer(serializers.ModelSerializer):
    uploaded_by_name = serializers.CharField(source='uploaded_by.full_name', read_only=True)
    row_errors = ImportRowErrorSerializer(many=True, read_only=True)

    class Meta:
        model = ImportBatch
        fields = [
            'id', 'file_name', 'total_rows', 'valid_new_count', 'duplicate_in_file_count',
            'previously_registered_count', 'permanently_blocked_count', 'invalid_rows_count',
            'status', 'uploaded_by', 'uploaded_by_name', 'staging_data', 'row_errors', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']

class PermanentPhoneNumberRegistrySerializer(serializers.ModelSerializer):
    first_assigned_to_name = serializers.CharField(source='first_assigned_to.full_name', read_only=True)

    class Meta:
        model = PermanentPhoneNumberRegistry
        fields = [
            'id', 'normalized_phone', 'first_assigned_at', 'first_assigned_to',
            'first_assigned_to_name', 'original_lead_id', 'notes'
        ]

class BulkAssignSerializer(serializers.Serializer):
    lead_ids = serializers.ListField(child=serializers.UUIDField(), required=True)
    method = serializers.ChoiceField(choices=['EQUAL', 'PERCENTAGE', 'CUSTOM'], default='EQUAL')
    allocations = serializers.ListField(
        child=serializers.DictField(),
        required=True,
        help_text="List of {employee_id: uuid, percentage: float, count: int}"
    )
