from django.urls import path
from apps.analytics.views import AdminDashboardMetricsView, TelecallerDashboardMetricsView

urlpatterns = [
    path('admin-dashboard/', AdminDashboardMetricsView.as_view(), name='admin_dashboard_metrics'),
    path('telecaller-dashboard/', TelecallerDashboardMetricsView.as_view(), name='telecaller_dashboard_metrics'),
]
