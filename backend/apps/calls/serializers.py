from rest_framework import serializers
from apps.calls.models import CallAttempt

class CallAttemptSerializer(serializers.ModelSerializer):
    employee_name = serializers.CharField(source='employee.full_name', read_only=True)
    lead_name = serializers.CharField(source='lead.full_name', read_only=True)
    lead_phone = serializers.CharField(source='lead.normalized_phone', read_only=True)

    class Meta:
        model = CallAttempt
        fields = [
            'id', 'lead', 'lead_name', 'lead_phone', 'employee', 'employee_name',
            'outcome', 'notes', 'duration_seconds', 'dialer_launched_at', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']

class LogCallOutcomeSerializer(serializers.Serializer):
    lead_id = serializers.UUIDField(required=True)
    outcome = serializers.ChoiceField(choices=CallAttempt.OUTCOME_CHOICES, required=True)
    notes = serializers.CharField(required=True, min_length=3, error_messages={'required': 'Call outcome notes are mandatory.'})
    duration_seconds = serializers.IntegerField(default=0, min_value=0)
    dialer_launched_at = serializers.DateTimeField(required=False, allow_null=True)
    
    # Optional direct callback creation
    schedule_callback = serializers.BooleanField(default=False)
    callback_time = serializers.DateTimeField(required=False, allow_null=True)
    callback_notes = serializers.CharField(required=False, allow_blank=True)
