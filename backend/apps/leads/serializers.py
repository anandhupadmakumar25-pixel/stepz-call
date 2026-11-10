from rest_framework import serializers
from apps.leads.models import (
    Lead,
    Branch,
    LeadCategory,
    CallingTask,
    ImportBatch,
    ImportRowError,
    PermanentPhoneNumberRegistry,
    LeadAssignmentHistory
)

class BranchSerializer(serializers.ModelSerializer):
    lead_count = serializers.SerializerMethodField()
    employee_count = serializers.SerializerMethodField()

    class Meta:
        model = Branch
        fields = [
            'id', 'name', 'code', 'address', 'latitude', 'longitude',
            'radius_meters', 'geofence_enabled', 'is_active',
            'lead_count', 'employee_count', 'created_at'
        ]
        read_only_fields = ['id', 'created_at', 'lead_count', 'employee_count']

    def get_lead_count(self, obj):
        return obj.leads.count()

    def get_employee_count(self, obj):
        return obj.employees.count()

class LeadCategorySerializer(serializers.ModelSerializer):
    lead_count = serializers.SerializerMethodField()

    class Meta:
        model = LeadCategory
        fields = ['id', 'name', 'color_code', 'description', 'is_active', 'lead_count', 'created_at']
        read_only_fields = ['id', 'created_at', 'lead_count']

    def get_lead_count(self, obj):
        return obj.leads.count()

class CallingTaskSerializer(serializers.ModelSerializer):
    branch_name = serializers.CharField(source='branch.name', read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True)
    category_color = serializers.CharField(source='category.color_code', read_only=True)
    assigned_to_name = serializers.CharField(source='assigned_to.full_name', read_only=True)
    created_by_name = serializers.CharField(source='created_by.full_name', read_only=True)
    total_leads_count = serializers.SerializerMethodField()
    completed_leads_count = serializers.SerializerMethodField()
    in_progress_leads_count = serializers.SerializerMethodField()
    progress_percent = serializers.SerializerMethodField()

    class Meta:
        model = CallingTask
        fields = [
            'id', 'title', 'description', 'branch', 'branch_name',
            'category', 'category_name', 'category_color',
            'assigned_to', 'assigned_to_name', 'created_by', 'created_by_name',
            'priority', 'status', 'due_date', 'target_count',
            'total_leads_count', 'completed_leads_count', 'in_progress_leads_count',
            'progress_percent', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_total_leads_count(self, obj):
        return obj.leads.count()

    def get_completed_leads_count(self, obj):
        return obj.leads.filter(status__in=['COMPLETED', 'QUALIFIED', 'NOT_INTERESTED']).count()

    def get_in_progress_leads_count(self, obj):
        return obj.leads.filter(status__in=['IN_PROGRESS', 'CALLBACK_REQUESTED', 'BUSY', 'NO_ANSWER']).count()

    def get_progress_percent(self, obj):
        total = obj.leads.count()
        if total == 0:
            return 0
        done = obj.leads.filter(status__in=['COMPLETED', 'QUALIFIED', 'NOT_INTERESTED']).count()
        return round((done / total) * 100, 1)

class LeadSerializer(serializers.ModelSerializer):
    first_name = serializers.CharField(required=False, allow_blank=True, default='')
    raw_phone = serializers.CharField(required=True)
    assigned_to_name = serializers.CharField(source='assigned_to.full_name', read_only=True)
    branch_name = serializers.CharField(source='branch.name', read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True)
    category_color = serializers.CharField(source='category.color_code', read_only=True)
    task_title = serializers.CharField(source='task.title', read_only=True)
    full_name = serializers.CharField(read_only=True)
    notes = serializers.SerializerMethodField()

    class Meta:
        model = Lead
        fields = [
            'id', 'first_name', 'last_name', 'full_name', 'raw_phone', 'normalized_phone',
            'email', 'city', 'state', 'source', 'status', 'branch', 'branch_name',
            'category', 'category_name', 'category_color', 'task', 'task_title',
            'assigned_to', 'assigned_to_name', 'notes',
            'assigned_at', 'is_assigned_ever', 'custom_fields', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'normalized_phone', 'assigned_at', 'is_assigned_ever', 'created_at', 'updated_at']

    def get_notes(self, obj):
        return (obj.custom_fields or {}).get('notes', '')

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
