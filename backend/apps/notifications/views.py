from rest_framework import views, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from apps.notifications.models import Notification, PushDeviceToken
from apps.notifications.serializers import NotificationSerializer

class NotificationListView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        base_qs = Notification.objects.filter(user=request.user)
        unread_count = base_qs.filter(is_read=False).count()
        unread_only = request.query_params.get('unread_only', '').lower() in ('1', 'true', 'yes') or request.query_params.get('filter') == 'unread'
        qs = base_qs.filter(is_read=False) if unread_only else base_qs
        notifications = qs.order_by('-created_at')[:50]
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


class NotificationMarkUnreadView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        notif = Notification.objects.filter(id=pk, user=request.user).first()
        if not notif:
            return Response({"error": "Notification not found"}, status=status.HTTP_404_NOT_FOUND)
        notif.is_read = False
        notif.read_at = None
        notif.save(update_fields=['is_read', 'read_at'])
        return Response({"success": True})


class PushTokenRegisterView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        token = (request.data.get('token') or '').strip()
        device_type = request.data.get('device_type', 'android')
        if not token:
            return Response({"error": "Device token is required"}, status=status.HTTP_400_BAD_REQUEST)

        PushDeviceToken.objects.update_or_create(
            token=token,
            defaults={'user': request.user, 'device_type': device_type, 'is_active': True}
        )
        return Response({"success": True, "message": "Push token registered successfully."})
