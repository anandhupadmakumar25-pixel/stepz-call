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

    def validate_callback_time(self, value):
        from datetime import timedelta
        from django.utils import timezone
        if value and value < timezone.now() - timedelta(minutes=2):
            raise serializers.ValidationError("Callback time cannot be in the past.")
        return value

class CallRecordingSerializer(serializers.ModelSerializer):
    lead_name = serializers.CharField(source='lead.full_name', read_only=True)
    lead_phone = serializers.SerializerMethodField()
    lead_city = serializers.CharField(source='lead.city', read_only=True, default='')
    employee_name = serializers.SerializerMethodField()
    employee_email = serializers.CharField(source='employee.email', read_only=True, default='')
    call_outcome = serializers.CharField(source='call_attempt.outcome', read_only=True, default='')
    audio_url = serializers.SerializerMethodField()

    class Meta:
        from apps.calls.models import CallRecording
        model = CallRecording
        fields = [
            'id', 'lead', 'lead_name', 'lead_phone', 'lead_city', 'call_attempt', 'call_outcome',
            'employee', 'employee_name', 'employee_email', 'audio_file', 'audio_url',
            'duration_seconds', 'file_size_bytes', 'source', 'notes',
            'waveform_data', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']

    def get_lead_phone(self, obj):
        if obj.lead:
            return obj.lead.normalized_phone or obj.lead.raw_phone or ''
        return ''

    def get_employee_name(self, obj):
        if obj.employee:
            return obj.employee.full_name or obj.employee.email
        return 'Staff'

    def get_audio_url(self, obj):
        if obj.audio_file:
            request = self.context.get('request')
            if request is not None:
                return request.build_absolute_uri(obj.audio_file.url)
            return obj.audio_file.url
        return None
