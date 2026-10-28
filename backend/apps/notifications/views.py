from rest_framework import views, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from apps.notifications.models import Notification, PushDeviceToken
from apps.notifications.serializers import NotificationSerializer

class NotificationListView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        notifications = Notification.objects.filter(user=request.user).order_by('-created_at')[:50]
        unread_count = Notification.objects.filter(user=request.user, is_read=False).count()
        return Response({
            'unread_count': unread_count,
            'notifications': NotificationSerializer(notifications, many=True).data
        })

class NotificationMarkReadView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk=None):
        if pk:
            notif = Notification.objects.filter(id=pk, user=request.user).first()
            if not notif:
                return Response({"error": "Notification not found"}, status=status.HTTP_404_NOT_FOUND)
            notif.is_read = True
            notif.read_at = timezone.now()
            notif.save(update_fields=['is_read', 'read_at'])
        else:
            # Mark all as read
            Notification.objects.filter(user=request.user, is_read=False).update(
                is_read=True,
                read_at=timezone.now()
            )
        return Response({"success": True})

class PushTokenRegisterView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        token = request.data.get('token')
        device_type = request.data.get('device_type', 'android')
        if not token:
            return Response({"error": "Device token is required"}, status=status.HTTP_400_BAD_REQUEST)

        PushDeviceToken.objects.update_or_create(
            user=request.user,
            token=token,
            defaults={'device_type': device_type, 'is_active': True}
        )
        return Response({"success": True, "message": "Push token registered successfully."})
