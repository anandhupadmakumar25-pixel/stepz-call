from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from apps.companies.models import Company
from apps.accounts.models import (
    Team, EmployeeProfile, Invitation, Department,
    AttendanceRecord, FieldVisit, CustomRole,
    SectionDelegation, PermissionAuditLog,
)
from apps.accounts.region_utils import resolve_request_country

User = get_user_model()


def _serialize_active_delegations(user):
    return [
        {
            'id': str(d.id),
            'title': d.title or 'Acting In-Charge',
            'delegator_id': str(d.delegator_id),
            'delegator_name': d.delegator.full_name if d.delegator else 'Admin',
            'sections': d.sections or [],
            'permissions': d.permissions or [],
            'start_date': d.start_date.isoformat(),
            'end_date': d.end_date.isoformat(),
        }
        for d in user.get_active_delegations()
    ]

class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    def validate(self, attrs):
        username_field = self.username_field
        login_input = str(attrs.get(username_field) or attrs.get('email') or attrs.get('username') or '').strip()

        if login_input:
            from django.db.models import Q
            matched_user = User.objects.filter(
                Q(email__iexact=login_input) | Q(username__iexact=login_input)
            ).first()
            if matched_user:
                attrs[username_field] = matched_user.email
            else:
                attrs[username_field] = login_input.lower()

        data = super().validate(attrs)
        user = self.user

        if not user.is_active:
            raise serializers.ValidationError({"detail": "User account is disabled."})

        # Multi-Tenant Plan Expiration & Suspension Interception
        if not user.is_super_admin and user.company:
            # Check and auto-suspend if overdue
            user.company.check_and_update_status()

            if user.company.is_plan_expired:
                expiry_str = user.company.plan_expires_at.strftime('%d %b %Y') if user.company.plan_expires_at else 'Unknown date'
                assigned_sa = user.company.assigned_super_admin or user.company.created_by
                raise serializers.ValidationError({
                    "detail": f"Your company subscription plan expired on {expiry_str}. Please submit a renewal request to restore access.",
                    "code": "PLAN_EXPIRED",
                    "plan_expires_at": user.company.plan_expires_at.isoformat() if user.company.plan_expires_at else None,
                    "company_name": user.company.name,
                    "company_id": str(user.company.id),
                    "user_email": user.email,
                    "super_admin_name": assigned_sa.full_name if assigned_sa else "Platform Administrator",
                })

            if user.company.status == 'SUSPENDED':
                assigned_sa = user.company.assigned_super_admin or user.company.created_by
                raise serializers.ValidationError({
                    "detail": "Company account is suspended. Please contact your company administrator or support.",
                    "code": "COMPANY_SUSPENDED",
                    "company_name": user.company.name,
                    "company_id": str(user.company.id),
                    "user_email": user.email,
                    "super_admin_name": assigned_sa.full_name if assigned_sa else "Platform Administrator",
                })

        company = user.company
        allowed_menus = company.get_allowed_menus() if company else []
        can_branches = company.can_manage_branches() if company else False
        plan_name = company.plan.name if (company and company.plan) else 'Default'
        plan_expires_at_iso = company.plan_expires_at.isoformat() if (company and company.plan_expires_at) else None
        days_left = company.days_until_expiry if company else None
        country_iso, country_code, currency, currency_symbol = resolve_request_country(
            self.context.get('request'),
            company=company,
        )

        data['user'] = {
            'id': str(user.id),
            'email': user.email,
            'username': user.username or '',
            'first_name': user.first_name,
            'last_name': user.last_name,
            'full_name': user.full_name,
            'role': user.role,
            'phone': user.phone,
            'company_id': str(company.id) if company else None,
            'company_name': company.name if company else None,
            'company_logo': company.logo if company else None,
            'company_phone': company.contact_phone if company else None,
            'company_email': company.contact_email if company else None,
            'company_address': company.address if company else None,
            'company_gstin': company.gstin if company else None,
            'company_website': company.website if company else None,
            'company_status': company.status if company else 'ACTIVE',
            'company_country_code': country_code,
            'company_country_iso': country_iso,
            'company_currency': currency,
            'company_currency_symbol': currency_symbol,
            'plan_billing_cycle': company.plan_billing_cycle if company else 'MONTHLY',
            'plan_expires_at': plan_expires_at_iso,
            'is_plan_expired': company.is_plan_expired if company else False,
            'days_until_expiry': days_left,
            'branch_id': str(user.branch.id) if user.branch else None,
            'branch_name': user.branch.name if user.branch else None,
            'is_staff': user.is_staff,
            'is_master_admin': user.is_master_admin,
            'company_allowed_menus': allowed_menus,
            'can_manage_branches': can_branches,
            'company_plan_name': plan_name,
            'custom_role_ids': [str(r.id) for r in user.custom_roles.all()],
            'custom_role_names': [r.name for r in user.custom_roles.all()],
            'resolved_permissions': user.resolved_permissions,
            'active_delegations': _serialize_active_delegations(user),
        }
        return data

class UserProfileSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source='company.name', read_only=True, default='', allow_null=True)
    company_logo = serializers.CharField(source='company.logo', read_only=True, default='', allow_null=True)
    company_phone = serializers.CharField(source='company.contact_phone', read_only=True, default='', allow_null=True)
    company_email = serializers.CharField(source='company.contact_email', read_only=True, default='', allow_null=True)
    company_address = serializers.CharField(source='company.address', read_only=True, default='', allow_null=True)
    company_gstin = serializers.CharField(source='company.gstin', read_only=True, default='', allow_null=True)
    company_website = serializers.CharField(source='company.website', read_only=True, default='', allow_null=True)
    company_country_code = serializers.SerializerMethodField()
    company_country_iso = serializers.SerializerMethodField()
    company_currency = serializers.SerializerMethodField()
    company_currency_symbol = serializers.SerializerMethodField()
    branch_name = serializers.CharField(source='branch.name', read_only=True)
    full_name = serializers.CharField(read_only=True)
    company_allowed_menus = serializers.SerializerMethodField()
    can_manage_branches = serializers.SerializerMethodField()
    company_plan_name = serializers.SerializerMethodField()
    company_plan_expires_at = serializers.SerializerMethodField()
    company_days_until_expiry = serializers.SerializerMethodField()
    company_is_plan_expired = serializers.SerializerMethodField()
    is_master_admin = serializers.BooleanField(read_only=True)
    resolved_permissions = serializers.ReadOnlyField()
    active_delegations = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id', 'email', 'username', 'first_name', 'last_name', 'full_name',
            'phone', 'role', 'is_master_admin', 'company', 'company_name',
            'company_logo', 'company_phone', 'company_email', 'company_address', 'company_gstin', 'company_website',
            'company_country_code', 'company_country_iso', 'company_currency', 'company_currency_symbol',
            'branch', 'branch_name',
            'company_allowed_menus', 'can_manage_branches', 'company_plan_name',
            'company_plan_expires_at', 'company_days_until_expiry', 'company_is_plan_expired',
            'resolved_permissions', 'active_delegations',
            'is_active', 'created_at'
        ]
        read_only_fields = ['id', 'email', 'role', 'company', 'company_name', 'created_at']

    def _resolved_region(self, obj):
        cache_attr = '_cached_resolved_region'
        if not hasattr(obj, cache_attr):
            setattr(
                obj,
                cache_attr,
                resolve_request_country(self.context.get('request'), company=obj.company),
            )
        return getattr(obj, cache_attr)

    def get_company_country_iso(self, obj):
        return self._resolved_region(obj)[0]

    def get_company_country_code(self, obj):
        return self._resolved_region(obj)[1]

    def get_company_currency(self, obj):
        return self._resolved_region(obj)[2]

    def get_company_currency_symbol(self, obj):
        return self._resolved_region(obj)[3]

    def get_active_delegations(self, obj):
        return _serialize_active_delegations(obj)

    def get_company_allowed_menus(self, obj):
        return obj.company.get_allowed_menus() if obj.company else []

    def get_can_manage_branches(self, obj):
        return obj.company.can_manage_branches() if obj.company else False

    def get_company_plan_name(self, obj):
        return obj.company.plan.name if (obj.company and obj.company.plan) else 'Default'

    def get_company_plan_expires_at(self, obj):
        return obj.company.plan_expires_at.isoformat() if (obj.company and obj.company.plan_expires_at) else None

    def get_company_days_until_expiry(self, obj):
        return obj.company.days_until_expiry if obj.company else None

    def get_company_is_plan_expired(self, obj):
        return obj.company.is_plan_expired if obj.company else False

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
            'shift_start_time', 'shift_end_time', 'grace_period_minutes', 'joining_date', 'status'
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
    daily_call_target = serializers.IntegerField(source='employee_profile.daily_call_target', read_only=True, default=50)

    class Meta:
        model = User
        fields = [
            'id', 'email', 'username', 'first_name', 'last_name', 'full_name', 'phone',
            'role', 'branch', 'branch_name', 'branch_code',
            'department_id', 'department_name', 'department_attendance_mode',
            'custom_role_ids', 'custom_role_names', 'resolved_permissions',
            'daily_call_target',
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
    joining_date = serializers.DateField(required=False, allow_null=True)
    shift_start_time = serializers.TimeField(required=False, allow_null=True)
    shift_end_time = serializers.TimeField(required=False, allow_null=True)
    grace_period_minutes = serializers.IntegerField(required=False, default=15, min_value=0)
    basic_salary = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, default=0)
    hra = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, default=0)
    allowances = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, default=0)
    pf_deduction = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, default=0)
    esi_deduction = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, default=0)
    tax_deduction = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, default=0)
    salary_currency = serializers.CharField(max_length=10, required=False, allow_blank=True)
    bank_name = serializers.CharField(max_length=120, required=False, allow_blank=True)
    account_number = serializers.CharField(max_length=64, required=False, allow_blank=True)
    ifsc_iban = serializers.CharField(max_length=64, required=False, allow_blank=True)

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


class SectionDelegationSerializer(serializers.ModelSerializer):
    delegator_name = serializers.CharField(source='delegator.full_name', read_only=True)
    delegator_email = serializers.CharField(source='delegator.email', read_only=True)
    delegatee_name = serializers.CharField(source='delegatee.full_name', read_only=True)
    delegatee_email = serializers.CharField(source='delegatee.email', read_only=True)
    revoked_by_name = serializers.CharField(source='revoked_by.full_name', read_only=True, default='')
    is_currently_effective = serializers.BooleanField(read_only=True)

    class Meta:
        model = SectionDelegation
        fields = [
            'id', 'delegator', 'delegator_name', 'delegator_email',
            'delegatee', 'delegatee_name', 'delegatee_email',
            'title', 'sections', 'permissions',
            'start_date', 'end_date', 'reason',
            'is_active', 'is_currently_effective',
            'revoked_at', 'revoked_by', 'revoked_by_name',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'delegator', 'is_currently_effective',
            'revoked_at', 'revoked_by', 'created_at', 'updated_at',
        ]

    def validate(self, attrs):
        start = attrs.get('start_date')
        end = attrs.get('end_date')
        if start and end and end < start:
            raise serializers.ValidationError({'end_date': 'End date must be on or after start date.'})
        return attrs


class PermissionAuditLogSerializer(serializers.ModelSerializer):
    actor_name = serializers.CharField(source='actor.full_name', read_only=True, default='System')
    on_behalf_of_name = serializers.CharField(source='on_behalf_of.full_name', read_only=True, default='')

    class Meta:
        model = PermissionAuditLog
        fields = [
            'id', 'actor', 'actor_name', 'on_behalf_of', 'on_behalf_of_name',
            'action', 'target_model', 'target_id', 'details', 'ip_address', 'created_at',
        ]
        read_only_fields = fields
