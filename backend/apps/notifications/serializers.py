from rest_framework import serializers
from apps.notifications.models import Notification, PushDeviceToken

class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['id', 'title', 'message', 'notification_type', 'entity_type', 'entity_id', 'is_read', 'read_at', 'created_at']
        read_only_fields = ['id', 'title', 'message', 'notification_type', 'entity_type', 'entity_id', 'created_at']

class PushDeviceTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = PushDeviceToken
        fields = ['device_token', 'device_type']
