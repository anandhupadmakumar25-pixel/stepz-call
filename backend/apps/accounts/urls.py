from django.urls import path
from apps.accounts.views import (
    CustomTokenObtainPairView,
    LogoutView,
    UserProfileView,
    EmployeeListCreateView,
    EmployeeDetailView,
    DepartmentListCreateView,
    DepartmentDetailView,
    CustomRoleListCreateView,
    CustomRoleDetailView,
    AttendanceCheckInView,
    AttendanceCheckOutView,
    FieldVisitListCreateView,
    AttendanceTodayView,
    AttendanceAdminRecordsView,
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
    path('departments/', DepartmentListCreateView.as_view(), name='department_list_create'),
    path('departments/<uuid:pk>/', DepartmentDetailView.as_view(), name='department_detail'),
    path('roles/', CustomRoleListCreateView.as_view(), name='custom_role_list_create'),
    path('roles/<uuid:pk>/', CustomRoleDetailView.as_view(), name='custom_role_detail'),
    path('attendance/check-in/', AttendanceCheckInView.as_view(), name='attendance_check_in'),
    path('attendance/check-out/', AttendanceCheckOutView.as_view(), name='attendance_check_out'),
    path('attendance/field-visits/', FieldVisitListCreateView.as_view(), name='attendance_field_visits'),
    path('attendance/today/', AttendanceTodayView.as_view(), name='attendance_today'),
    path('attendance/records/', AttendanceAdminRecordsView.as_view(), name='attendance_admin_records'),
    path('teams/', TeamListCreateView.as_view(), name='team_list_create'),
    path('teams/<uuid:pk>/', TeamDetailView.as_view(), name='team_detail'),
]
