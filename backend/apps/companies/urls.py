from django.urls import path
from apps.companies.views import CompanyListCreateView, CompanyDetailView

urlpatterns = [
    path('', CompanyListCreateView.as_view(), name='company_list_create'),
    path('<uuid:pk>/', CompanyDetailView.as_view(), name='company_detail'),
]
