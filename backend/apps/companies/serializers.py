from rest_framework import serializers
from apps.companies.models import Company, Plan, CompanyPayrollPolicy, CompanyCustomRule

class PlanSerializer(serializers.ModelSerializer):
    company_count = serializers.SerializerMethodField()
    currency_symbol = serializers.ReadOnlyField()

    class Meta:
        model = Plan
        fields = [
            'id', 'name', 'code', 'currency', 'currency_symbol', 'price_monthly', 'price_yearly',
            'max_users', 'max_leads', 'allowed_menus', 'description',
            'is_active', 'company_count', 'created_at'
        ]
        read_only_fields = ['id', 'currency_symbol', 'created_at']

    def get_company_count(self, obj):
        return obj.companies.count()

class CompanySerializer(serializers.ModelSerializer):
    user_count = serializers.SerializerMethodField()
    lead_count = serializers.SerializerMethodField()
    branch_count = serializers.SerializerMethodField()
    task_count = serializers.SerializerMethodField()
    admin_name = serializers.SerializerMethodField()
    admin_email = serializers.SerializerMethodField()
    plan_name = serializers.CharField(source='plan.name', read_only=True, default='Starter Lite')
    plan_code = serializers.CharField(source='plan.code', read_only=True, default='starter')
    plan_currency = serializers.CharField(source='plan.currency', read_only=True, default='INR')
    plan_currency_symbol = serializers.CharField(source='plan.currency_symbol', read_only=True, default='₹')
    plan_price_monthly = serializers.DecimalField(source='plan.price_monthly', max_digits=10, decimal_places=2, read_only=True, default=0.00)
    plan_price_yearly = serializers.DecimalField(source='plan.price_yearly', max_digits=10, decimal_places=2, read_only=True, default=0.00)
    plan_max_users = serializers.IntegerField(source='plan.max_users', read_only=True, default=5)
    plan_max_leads = serializers.IntegerField(source='plan.max_leads', read_only=True, default=5000)
    resolved_allowed_menus = serializers.SerializerMethodField()
    can_manage_branches = serializers.SerializerMethodField()

    class Meta:
        model = Company
        fields = [
            'id', 'name', 'subdomain', 'contact_email', 'contact_phone',
            'status', 'default_country_code', 'default_country_iso',
            'plan', 'plan_name', 'plan_code', 'plan_currency', 'plan_currency_symbol',
            'plan_price_monthly', 'plan_price_yearly',
            'plan_max_users', 'plan_max_leads', 'allowed_menus',
            'resolved_allowed_menus', 'can_manage_branches',
            'settings', 'user_count', 'lead_count', 'branch_count', 'task_count',
            'admin_name', 'admin_email', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_user_count(self, obj):
        return obj.users.count()

    def get_lead_count(self, obj):
        from apps.leads.models import Lead
        return Lead.objects.filter(company=obj).count()

    def get_branch_count(self, obj):
        from apps.leads.models import Branch
        return Branch.objects.filter(company=obj).count()

    def get_task_count(self, obj):
        from apps.leads.models import CallingTask
        return CallingTask.objects.filter(company=obj).count()

    def get_admin_name(self, obj):
        admin = obj.users.filter(role='COMPANY_ADMIN').first()
        return admin.full_name if admin else ''

    def get_admin_email(self, obj):
        admin = obj.users.filter(role='COMPANY_ADMIN').first()
        return admin.email if admin else obj.contact_email

    def get_resolved_allowed_menus(self, obj):
        return obj.get_allowed_menus()

    def get_can_manage_branches(self, obj):
        return obj.can_manage_branches()

class CompanyCreateSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=255)
    admin_email = serializers.EmailField()
    admin_password = serializers.CharField(min_length=6, required=False, allow_blank=True, default='')
    admin_first_name = serializers.CharField(max_length=150, required=False, allow_blank=True, default='')
    admin_last_name = serializers.CharField(max_length=150, required=False, allow_blank=True, default='')
    subdomain = serializers.CharField(max_length=100, required=False, allow_blank=True, default='')
    contact_email = serializers.EmailField(required=False, allow_blank=True, default='')
    contact_phone = serializers.CharField(max_length=32, required=False, allow_blank=True, default='')
    default_country_code = serializers.CharField(max_length=4, required=False, default='+91')
    plan_id = serializers.CharField(required=False, allow_blank=True, default='')
    allowed_menus = serializers.ListField(child=serializers.CharField(), required=False, default=list)


class CompanyPayrollPolicySerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source='company.name', read_only=True)

    class Meta:
        model = CompanyPayrollPolicy
        fields = [
            'id', 'company_name',
            'shift_start_time', 'shift_end_time', 'grace_period_minutes',
            'full_day_hours', 'half_day_hours',
            'allow_out_of_fence_punch', 'strict_geofence_block',
            'salary_cycle_start_day', 'pay_calculation_basis',
            'overtime_enabled', 'overtime_min_minutes', 'overtime_hourly_multiplier',
            'custom_profile_fields', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'company_name', 'created_at', 'updated_at']


class CompanyCustomRuleSerializer(serializers.ModelSerializer):
    category_display = serializers.CharField(source='get_category_display', read_only=True)
    action_type_display = serializers.CharField(source='get_action_type_display', read_only=True)

    class Meta:
        model = CompanyCustomRule
        fields = [
            'id', 'name', 'category', 'category_display', 'description',
            'trigger_metric', 'operator', 'threshold_value', 'free_allowance_count',
            'action_type', 'action_type_display', 'action_value',
            'applicable_department_ids', 'is_active', 'order',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'category_display', 'action_type_display', 'created_at', 'updated_at']
