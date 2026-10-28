from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from apps.companies.models import Company
from apps.accounts.models import Team, EmployeeProfile, Invitation

User = get_user_model()

class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    def validate(self, attrs):
        data = super().validate(attrs)
        user = self.user

        if not user.is_active:
            raise serializers.ValidationError({"detail": "User account is disabled."})

        if user.company and user.company.status == 'SUSPENDED':
            raise serializers.ValidationError({"detail": "Company account is suspended. Please contact administrator."})

        data['user'] = {
            'id': str(user.id),
            'email': user.email,
            'first_name': user.first_name,
            'last_name': user.last_name,
            'full_name': user.full_name,
            'role': user.role,
            'phone': user.phone,
            'company_id': str(user.company.id) if user.company else None,
            'company_name': user.company.name if user.company else None,
            'is_staff': user.is_staff,
        }
        return data

class UserProfileSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source='company.name', read_only=True)
    full_name = serializers.CharField(read_only=True)

    class Meta:
        model = User
        fields = [
            'id', 'email', 'first_name', 'last_name', 'full_name',
            'phone', 'role', 'company', 'company_name', 'is_active', 'created_at'
        ]
        read_only_fields = ['id', 'email', 'role', 'company', 'company_name', 'created_at']

class TeamSerializer(serializers.ModelSerializer):
    manager_name = serializers.CharField(source='manager.full_name', read_only=True)
    member_count = serializers.SerializerMethodField()

    class Meta:
        model = Team
        fields = ['id', 'name', 'description', 'manager', 'manager_name', 'is_active', 'member_count', 'created_at']
        read_only_fields = ['id', 'created_at']

    def get_member_count(self, obj):
        return obj.members.count()

class EmployeeProfileSerializer(serializers.ModelSerializer):
    team_name = serializers.CharField(source='team.name', read_only=True)
    manager_name = serializers.CharField(source='manager.full_name', read_only=True)

    class Meta:
        model = EmployeeProfile
        fields = ['team', 'team_name', 'manager', 'manager_name', 'employee_code', 'daily_call_target', 'status']

class EmployeeListSerializer(serializers.ModelSerializer):
    employee_profile = EmployeeProfileSerializer(read_only=True)
    assigned_leads_count = serializers.SerializerMethodField()
    calls_today_count = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id', 'email', 'first_name', 'last_name', 'full_name', 'phone',
            'role', 'is_active', 'employee_profile', 'assigned_leads_count',
            'calls_today_count', 'created_at'
        ]

    def get_assigned_leads_count(self, obj):
        return obj.assigned_leads.filter(status__in=['ASSIGNED', 'IN_PROGRESS', 'CALLBACK_REQUESTED']).count()

    def get_calls_today_count(self, obj):
        from django.utils import timezone
        today = timezone.now().date()
        return obj.call_attempts.filter(created_at__date=today).count()

class EmployeeCreateSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, required=True, validators=[validate_password])
    first_name = serializers.CharField(max_length=150)
    last_name = serializers.CharField(max_length=150, required=False, allow_blank=True)
    phone = serializers.CharField(max_length=32, required=False, allow_blank=True)
    role = serializers.ChoiceField(choices=[('MANAGER', 'Manager'), ('EMPLOYEE', 'Employee / Telecaller')])
    team_id = serializers.UUIDField(required=False, allow_null=True)
    manager_id = serializers.UUIDField(required=False, allow_null=True)
    employee_code = serializers.CharField(max_length=64, required=False, allow_blank=True)
    daily_call_target = serializers.IntegerField(default=50, min_value=1)

    def validate_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("A user with this email address already exists.")
        return value

class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(required=True)
    new_password = serializers.CharField(required=True, validators=[validate_password])
