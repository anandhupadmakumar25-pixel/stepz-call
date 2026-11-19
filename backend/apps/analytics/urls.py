from django.urls import path
from apps.analytics.views import (
    AdminDashboardMetricsView,
    TelecallerDashboardMetricsView,
    SalesBillingReportView,
    CallsTelecallerReportView,
    LeadsPipelineReportView,
    HrAttendanceReportView,
)

urlpatterns = [
    path('admin-dashboard/', AdminDashboardMetricsView.as_view(), name='admin_dashboard_metrics'),
    path('telecaller-dashboard/', TelecallerDashboardMetricsView.as_view(), name='telecaller_dashboard_metrics'),
    path('reports/sales/', SalesBillingReportView.as_view(), name='report_sales_billing'),
    path('reports/calls/', CallsTelecallerReportView.as_view(), name='report_calls_telecaller'),
    path('reports/leads/', LeadsPipelineReportView.as_view(), name='report_leads_pipeline'),
    path('reports/attendance/', HrAttendanceReportView.as_view(), name='report_hr_attendance'),
]
