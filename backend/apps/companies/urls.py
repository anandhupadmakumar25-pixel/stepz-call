from django.urls import path
from apps.companies.views import (
    CompanyListCreateView,
    CompanyDetailView,
    MyCompanyView,
    CompanyPermissionsView,
    CompanyResetPasswordView,
    PlanListCreateView,
    PlanDetailView,
    PlatformBillingOverviewView,
    CompanyPayrollPolicyView,
    CompanyCustomRuleListCreateView,
    CompanyCustomRuleDetailView,
    CompanyRulePresetLoadView,
)

urlpatterns = [
    path('plans/', PlanListCreateView.as_view(), name='plan_list_create'),
    path('plans/<int:pk>/', PlanDetailView.as_view(), name='plan_detail'),
    path('billing/overview/', PlatformBillingOverviewView.as_view(), name='platform_billing_overview'),
    path('payroll-policy/', CompanyPayrollPolicyView.as_view(), name='company_payroll_policy'),
    path('rules/', CompanyCustomRuleListCreateView.as_view(), name='company_rules_list_create'),
    path('rules/preset/', CompanyRulePresetLoadView.as_view(), name='company_rules_preset'),
    path('rules/<uuid:pk>/', CompanyCustomRuleDetailView.as_view(), name='company_rules_detail'),
    path('', CompanyListCreateView.as_view(), name='company_list_create'),
    path('my-company/', MyCompanyView.as_view(), name='my_company'),
    path('<uuid:pk>/', CompanyDetailView.as_view(), name='company_detail'),
    path('<uuid:pk>/permissions/', CompanyPermissionsView.as_view(), name='company_permissions'),
    path('<uuid:pk>/reset-password/', CompanyResetPasswordView.as_view(), name='company_reset_password'),
]
