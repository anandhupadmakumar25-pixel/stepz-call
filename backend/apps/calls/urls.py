from django.urls import path
from apps.calls.views import (
    CallAttemptListCreateView,
    CallAttemptDetailView,
    CallRecordingListCreateView,
    CallRecordingDetailView
)

urlpatterns = [
    path('', CallAttemptListCreateView.as_view(), name='call_attempt_list_create'),
    path('<uuid:pk>/', CallAttemptDetailView.as_view(), name='call_attempt_detail'),
    path('recordings/', CallRecordingListCreateView.as_view(), name='call_recording_list_create'),
    path('recordings/<uuid:pk>/', CallRecordingDetailView.as_view(), name='call_recording_detail'),
]
