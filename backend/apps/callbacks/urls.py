from django.urls import path
from apps.callbacks.views import (
    CallbackListView,
    CallbackDetailView,
    CallbackRescheduleView,
    CallbackCompleteView,
    CheckRemindersTriggerView
)

urlpatterns = [
    path('', CallbackListView.as_view(), name='callback_list_create'),
    path('<uuid:pk>/', CallbackDetailView.as_view(), name='callback_detail'),
    path('<uuid:pk>/reschedule/', CallbackRescheduleView.as_view(), name='callback_reschedule'),
    path('<uuid:pk>/complete/', CallbackCompleteView.as_view(), name='callback_complete'),
    path('check-reminders/', CheckRemindersTriggerView.as_view(), name='callback_check_reminders'),
]
