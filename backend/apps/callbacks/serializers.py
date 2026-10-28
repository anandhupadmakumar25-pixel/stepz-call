from rest_framework import serializers
from apps.callbacks.models import Callback, CallbackHistory

class CallbackHistorySerializer(serializers.ModelSerializer):
    changed_by_name = serializers.CharField(source='changed_by.full_name', read_only=True)

    class Meta:
        model = CallbackHistory
        fields = ['id', 'changed_by', 'changed_by_name', 'from_status', 'to_status', 'rescheduled_to', 'reason', 'created_at']

class CallbackSerializer(serializers.ModelSerializer):
    lead_name = serializers.CharField(source='lead.full_name', read_only=True)
    lead_phone = serializers.CharField(source='lead.normalized_phone', read_only=True)
    assigned_employee_name = serializers.CharField(source='assigned_employee.full_name', read_only=True)
    history = CallbackHistorySerializer(many=True, read_only=True)

    class Meta:
        model = Callback
        fields = [
            'id', 'lead', 'lead_name', 'lead_phone', 'assigned_employee', 'assigned_employee_name',
            'originating_call_attempt', 'scheduled_at', 'status', 'initial_notes',
            'completion_notes', 'completed_at', 'rescheduled_count', 'last_rescheduled_at',
            'reminder_sent', 'history', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'rescheduled_count', 'last_rescheduled_at', 'reminder_sent', 'created_at', 'updated_at']

from datetime import timedelta
from django.utils import timezone

class CallbackCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Callback
        fields = ['lead', 'scheduled_at', 'initial_notes']

    def validate_scheduled_at(self, value):
        if value < timezone.now() - timedelta(minutes=2):
            raise serializers.ValidationError("Callback date and time cannot be in the past.")
        return value

class CallbackRescheduleSerializer(serializers.Serializer):
    new_scheduled_at = serializers.DateTimeField(required=True)
    reason = serializers.CharField(required=True, min_length=3)

    def validate_new_scheduled_at(self, value):
        if value < timezone.now() - timedelta(minutes=2):
            raise serializers.ValidationError("Rescheduled callback date and time cannot be in the past.")
        return value

class CallbackCompleteSerializer(serializers.Serializer):
    completion_notes = serializers.CharField(required=True, min_length=3)
