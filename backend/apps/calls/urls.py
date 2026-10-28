from django.urls import path
from apps.calls.views import CallAttemptListCreateView, CallAttemptDetailView

urlpatterns = [
    path('', CallAttemptListCreateView.as_view(), name='call_attempt_list_create'),
    path('<uuid:pk>/', CallAttemptDetailView.as_view(), name='call_attempt_detail'),
]
