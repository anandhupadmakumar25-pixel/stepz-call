from django.urls import path
from apps.accounts.views import (
    CustomTokenObtainPairView,
    LogoutView,
    UserProfileView,
    EmployeeListCreateView,
    EmployeeDetailView,
    TeamListCreateView,
    TeamDetailView,
    ChangePasswordView
)
from rest_framework_simplejwt.views import TokenRefreshView

urlpatterns = [
    path('login/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('logout/', LogoutView.as_view(), name='logout'),
    path('profile/', UserProfileView.as_view(), name='user_profile'),
    path('change-password/', ChangePasswordView.as_view(), name='change_password'),
    path('employees/', EmployeeListCreateView.as_view(), name='employee_list_create'),
    path('employees/<uuid:pk>/', EmployeeDetailView.as_view(), name='employee_detail'),
    path('teams/', TeamListCreateView.as_view(), name='team_list_create'),
    path('teams/<uuid:pk>/', TeamDetailView.as_view(), name='team_detail'),
]
