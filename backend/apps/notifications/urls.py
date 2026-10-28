from django.urls import path
from apps.notifications.views import NotificationListView, NotificationMarkReadView, PushTokenRegisterView

urlpatterns = [
    path('', NotificationListView.as_view(), name='notification_list'),
    path('mark-read/', NotificationMarkReadView.as_view(), name='notification_mark_all_read'),
    path('<uuid:pk>/mark-read/', NotificationMarkReadView.as_view(), name='notification_mark_read'),
    path('register-token/', PushTokenRegisterView.as_view(), name='push_token_register'),
]
