from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from apps.companies.models import Company
from apps.accounts.models import Team, EmployeeProfile, Invitation, Department, AttendanceRecord, FieldVisit, CustomRole

User = get_user_model()

class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    def validate(self, attrs):
        username_field = self.username_field
        if username_field in attrs and isinstance(attrs[username_field], str):
            attrs[username_field] = attrs[username_field].strip().lower()
        if 'email' in attrs and isinstance(attrs['email'], str):
            attrs['email'] = attrs['email'].strip().lower()
        data = super().validate(attrs)
        user = self.user

        if not user.is_active:
            raise serializers.ValidationError({"detail": "User account is disabled."})

        if user.company and user.company.status == 'SUSPENDED':
            raise serializers.ValidationError({"detail": "Company account is suspended. Please contact administrator."})

        company = user.company
        allowed_menus = company.get_allowed_menus() if company else []
        can_branches = company.can_manage_branches() if company else False
        plan_name = company.plan.name if (company and company.plan) else 'Default'

        data['user'] = {
            'id': str(user.id),
            'email': user.email,
            'first_name': user.first_name,
            'last_name': user.last_name,
            'full_name': user.full_name,
            'role': user.role,
            'phone': user.phone,
            'company_id': str(company.id) if company else None,
            'company_name': company.name if company else None,
            'branch_id': str(user.branch.id) if user.branch else None,
            'branch_name': user.branch.name if user.branch else None,
            'is_staff': user.is_staff,
            'company_allowed_menus': allowed_menus,
            'can_manage_branches': can_branches,
            'company_plan_name': plan_name,
            'custom_role_ids': [str(r.id) for r in user.custom_roles.all()],
            'custom_role_names': [r.name for r in user.custom_roles.all()],
            'resolved_permissions': user.resolved_permissions,
        }
        return data

class UserProfileSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source='company.name', read_only=True)
    branch_name = serializers.CharField(source='branch.name', read_only=True)
    full_name = serializers.CharField(read_only=True)
    company_allowed_menus = serializers.SerializerMethodField()
    can_manage_branches = serializers.SerializerMethodField()
    company_plan_name = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id', 'email', 'first_name', 'last_name', 'full_name',
            'phone', 'role', 'company', 'company_name', 'branch', 'branch_name',
            'company_allowed_menus', 'can_manage_branches', 'company_plan_name',
            'is_active', 'created_at'
        ]
        read_only_fields = ['id', 'email', 'role', 'company', 'company_name', 'created_at']

    def get_company_allowed_menus(self, obj):
        return obj.company.get_allowed_menus() if obj.company else []

    def get_can_manage_branches(self, obj):
        return obj.company.can_manage_branches() if obj.company else False

    def get_company_plan_name(self, obj):
        return obj.company.plan.name if (obj.company and obj.company.plan) else 'Default'

class TeamSerializer(serializers.ModelSerializer):
    manager_name = serializers.CharField(source='manager.full_name', read_only=True)
    member_count = serializers.SerializerMethodField()

    class Meta:
        model = Team
        fields = ['id', 'name', 'description', 'manager', 'manager_name', 'is_active', 'member_count', 'created_at']
        read_only_fields = ['id', 'created_at']

    def get_member_count(self, obj):
        return obj.members.count()

class DepartmentSerializer(serializers.ModelSerializer):
    manager_name = serializers.CharField(source='manager.full_name', read_only=True)
    member_count = serializers.SerializerMethodField()
    allowed_branch_details = serializers.SerializerMethodField()

    class Meta:
        model = Department
        fields = [
            'id', 'name', 'code', 'description', 'attendance_mode',
            'allowed_branches', 'allowed_branch_details', 'manager', 'manager_name',
            'is_active', 'member_count', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']

    def get_member_count(self, obj):
        return obj.members.count()

    def get_allowed_branch_details(self, obj):
        return [
            {
                'id': str(b.id),
                'name': b.name,
                'code': b.code,
                'latitude': float(b.latitude) if b.latitude else None,
                'longitude': float(b.longitude) if b.longitude else None,
                'radius_meters': b.radius_meters,
                'geofence_enabled': b.geofence_enabled,
            }
            for b in obj.allowed_branches.all()
        ]

class CustomRoleSerializer(serializers.ModelSerializer):
    user_count = serializers.SerializerMethodField()

    class Meta:
        model = CustomRole
        fields = [
            'id', 'name', 'code', 'description', 'permissions',
            'is_system_default', 'is_active', 'user_count', 'created_at'
        ]
        read_only_fields = ['id', 'created_at', 'is_system_default']

    def get_user_count(self, obj):
        return obj.assigned_users.count()

class EmployeeProfileSerializer(serializers.ModelSerializer):
    team_name = serializers.CharField(source='team.name', read_only=True)
    manager_name = serializers.CharField(source='manager.full_name', read_only=True)
    department_name = serializers.CharField(source='department.name', read_only=True)
    department_attendance_mode = serializers.CharField(source='department.attendance_mode', read_only=True)
    allowed_branch_ids = serializers.SerializerMethodField()

    class Meta:
        model = EmployeeProfile
        fields = [
            'department', 'department_name', 'department_attendance_mode',
            'allowed_branches', 'allowed_branch_ids',
            'team', 'team_name', 'manager', 'manager_name',
            'employee_code', 'daily_call_target', 'is_geofence_required',
            'shift_start_time', 'shift_end_time', 'grace_period_minutes', 'status'
        ]

    def get_allowed_branch_ids(self, obj):
        overrides = list(obj.allowed_branches.values_list('id', flat=True))
        if overrides:
            return [str(i) for i in overrides]
        if obj.department:
            return [str(i) for i in obj.department.allowed_branches.values_list('id', flat=True)]
        if obj.user.branch_id:
            return [str(obj.user.branch_id)]
        return []

class EmployeeListSerializer(serializers.ModelSerializer):
    employee_profile = EmployeeProfileSerializer(read_only=True)
    branch_name = serializers.CharField(source='branch.name', read_only=True)
    branch_code = serializers.CharField(source='branch.code', read_only=True)
    department_id = serializers.CharField(source='employee_profile.department_id', read_only=True)
    department_name = serializers.CharField(source='employee_profile.department.name', read_only=True)
    department_attendance_mode = serializers.CharField(source='employee_profile.department.attendance_mode', read_only=True)
    assigned_leads_count = serializers.SerializerMethodField()
    calls_today_count = serializers.SerializerMethodField()
    today_attendance = serializers.SerializerMethodField()
    custom_role_ids = serializers.SerializerMethodField()
    custom_role_names = serializers.SerializerMethodField()
    resolved_permissions = serializers.ReadOnlyField()

    class Meta:
        model = User
        fields = [
            'id', 'email', 'first_name', 'last_name', 'full_name', 'phone',
            'role', 'branch', 'branch_name', 'branch_code',
            'department_id', 'department_name', 'department_attendance_mode',
            'custom_role_ids', 'custom_role_names', 'resolved_permissions',
            'is_active', 'employee_profile',
            'assigned_leads_count', 'calls_today_count', 'today_attendance', 'created_at'
        ]

    def get_custom_role_ids(self, obj):
        return [str(r.id) for r in obj.custom_roles.all()]

    def get_custom_role_names(self, obj):
        return [r.name for r in obj.custom_roles.all()]

    def get_assigned_leads_count(self, obj):
        return obj.assigned_leads.filter(status__in=['ASSIGNED', 'IN_PROGRESS', 'CALLBACK_REQUESTED']).count()

    def get_calls_today_count(self, obj):
        from django.utils import timezone
        today = timezone.now().date()
        return obj.call_attempts.filter(created_at__date=today).count()

    def get_today_attendance(self, obj):
        from django.utils import timezone
        today = timezone.now().date()
        att = obj.attendance_records.filter(date=today).first()
        if not att:
            return None
        return {
            'id': str(att.id),
            'status': att.status,
            'tracking_mode': att.tracking_mode,
            'check_in_time': att.check_in_time.isoformat() if att.check_in_time else None,
            'check_in_address': att.check_in_address,
            'check_in_distance_meters': att.check_in_distance_meters,
            'check_in_in_geofence': att.check_in_in_geofence,
            'check_out_time': att.check_out_time.isoformat() if att.check_out_time else None,
            'check_out_address': att.check_out_address,
            'working_hours': float(att.working_hours),
            'field_visits_count': att.field_visits.count(),
        }

class EmployeeCreateSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, required=True, validators=[validate_password])
    first_name = serializers.CharField(max_length=150)
    last_name = serializers.CharField(max_length=150, required=False, allow_blank=True)
    phone = serializers.CharField(max_length=32, required=False, allow_blank=True)
    role = serializers.ChoiceField(choices=[('MANAGER', 'Manager'), ('EMPLOYEE', 'Employee / Telecaller')])
    department_id = serializers.UUIDField(required=False, allow_null=True)
    custom_role_ids = serializers.ListField(child=serializers.UUIDField(), required=False, default=list)
    branch_id = serializers.UUIDField(required=False, allow_null=True)
    allowed_branch_ids = serializers.ListField(child=serializers.UUIDField(), required=False, default=list)
    team_id = serializers.UUIDField(required=False, allow_null=True)
    manager_id = serializers.UUIDField(required=False, allow_null=True)
    employee_code = serializers.CharField(max_length=64, required=False, allow_blank=True)
    daily_call_target = serializers.IntegerField(default=50, min_value=1)
    is_geofence_required = serializers.BooleanField(required=False, default=True)

    def validate_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("A user with this email address already exists.")
        return value

class FieldVisitSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.full_name', read_only=True)

    class Meta:
        model = FieldVisit
        fields = [
            'id', 'attendance', 'user', 'user_name',
            'place_name', 'latitude', 'longitude', 'address',
            'visited_at', 'remarks', 'created_at'
        ]
        read_only_fields = ['id', 'user', 'attendance', 'created_at']

class AttendanceRecordSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.full_name', read_only=True)
    user_email = serializers.CharField(source='user.email', read_only=True)
    user_phone = serializers.CharField(source='user.phone', read_only=True)
    department_name = serializers.CharField(source='department.name', read_only=True)
    matched_branch_name = serializers.CharField(source='matched_branch.name', read_only=True)
    field_visits = FieldVisitSerializer(many=True, read_only=True)

    class Meta:
        model = AttendanceRecord
        fields = [
            'id', 'user', 'user_name', 'user_email', 'user_phone',
            'department', 'department_name', 'matched_branch', 'matched_branch_name',
            'date', 'tracking_mode',
            'check_in_time', 'check_in_lat', 'check_in_lng', 'check_in_address',
            'check_in_distance_meters', 'check_in_in_geofence',
            'check_out_time', 'check_out_lat', 'check_out_lng', 'check_out_address',
            'check_out_distance_meters', 'check_out_in_geofence',
            'working_hours', 'status', 'notes', 'field_visits', 'created_at'
        ]
        read_only_fields = ['id', 'user', 'created_at']

class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(required=True)
    new_password = serializers.CharField(required=True, validators=[validate_password])
