import uuid
import secrets
import string
from datetime import timedelta
from django.utils import timezone
from rest_framework import generics, status, views
from rest_framework.response import Response
from django.db import transaction
from django.contrib.auth import get_user_model
from django.db.models import Sum, Count, Q
from apps.companies.models import (
    Company,
    Plan,
    ALL_MENU_KEYS,
    CompanyPayrollPolicy,
    CompanyCustomRule,
    CompanyRenewalRequest,
    CompanySubscriptionHistory,
)
from apps.companies.serializers import (
    CompanySerializer,
    CompanyCreateSerializer,
    PlanSerializer,
    CompanyPayrollPolicySerializer,
    CompanyCustomRuleSerializer,
    CompanyRenewPlanSerializer,
    CompanyRenewalRequestSerializer,
    CompanyRenewalRequestCreateSerializer,
    CompanyRenewalRequestApproveSerializer,
    CompanySubscriptionHistorySerializer,
)
from apps.core.permissions import IsSuperAdmin, IsCompanyAdmin, IsEmployee, IsMasterAdmin

User = get_user_model()

def get_plan_by_id_or_code(val):
    if not val:
        return None
    val_str = str(val).strip()
    if not val_str:
        return None
    plan = Plan.objects.filter(code=val_str).first()
    if plan:
        return plan
    try:
        uuid_obj = uuid.UUID(val_str)
        return Plan.objects.filter(id=uuid_obj).first()
    except (ValueError, AttributeError):
        return None

def generate_temporary_password(length=10):
    chars = string.ascii_letters + string.digits + '!@#$'
    # Ensure at least 1 uppercase, 1 lowercase, 1 digit, 1 symbol
    pwd = [
        secrets.choice(string.ascii_uppercase),
        secrets.choice(string.ascii_lowercase),
        secrets.choice(string.digits),
        secrets.choice('!@#$')
    ]
    for _ in range(length - 4):
        pwd.append(secrets.choice(chars))
    secrets.SystemRandom().shuffle(pwd)
    return ''.join(pwd)

class CompanyListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'POST':
            return [IsSuperAdmin()]
        return [IsCompanyAdmin()]

    def get(self, request):
        if request.user.is_master_admin:
            super_admin_filter = request.query_params.get('super_admin_id')
            qs = Company.objects.all().select_related('plan', 'created_by', 'assigned_super_admin')
            if super_admin_filter:
                qs = qs.filter(Q(created_by_id=super_admin_filter) | Q(assigned_super_admin_id=super_admin_filter))
            return Response(CompanySerializer(qs.order_by('-created_at'), many=True).data)
        elif request.user.role == 'SUPER_ADMIN':
            qs = Company.objects.filter(
                Q(created_by=request.user) | Q(assigned_super_admin=request.user)
            ).select_related('plan', 'created_by', 'assigned_super_admin').order_by('-created_at')
            return Response(CompanySerializer(qs, many=True).data)
        elif request.user.company:
            return Response([CompanySerializer(request.user.company).data])
        return Response([])

    def post(self, request):
        serializer = CompanyCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        admin_email = data['admin_email'].strip()
        admin_password = data.get('admin_password', '').strip()
        if not admin_password:
            admin_password = generate_temporary_password(10)

        admin_first_name = data.get('admin_first_name', '').strip() or 'Admin'
        admin_last_name = data.get('admin_last_name', '').strip()
        contact_email = data.get('contact_email', '').strip() or admin_email
        contact_phone = data.get('contact_phone', '').strip()
        subdomain = data.get('subdomain', '').strip() or None
        plan_id = data.get('plan_id', '').strip()
        allowed_menus = data.get('allowed_menus', [])

        if User.objects.filter(email=admin_email).exists():
            return Response({"error": f"A user with email '{admin_email}' already exists. Please use a different admin email address."}, status=status.HTTP_400_BAD_REQUEST)

        plan = get_plan_by_id_or_code(plan_id)
        if not plan:
            plan = Plan.objects.filter(code='starter').first() or Plan.objects.first()

        plan_billing_cycle = data.get('plan_billing_cycle', 'MONTHLY')
        plan_duration_days = data.get('plan_duration_days', 30)
        if plan_billing_cycle == 'YEARLY':
            plan_duration_days = 365
        elif plan_billing_cycle == 'QUARTERLY':
            plan_duration_days = 90
        elif plan_billing_cycle == 'MONTHLY' and not plan_duration_days:
            plan_duration_days = 30

        now = timezone.now()
        plan_starts_at = now
        plan_expires_at = now + timedelta(days=plan_duration_days)

        # If allowed_menus was not explicitly passed, inherit from plan or default
        if not allowed_menus:
            if plan and plan.allowed_menus:
                allowed_menus = plan.allowed_menus
            else:
                allowed_menus = ALL_MENU_KEYS

        with transaction.atomic():
            company = Company.objects.create(
                name=data['name'].strip(),
                subdomain=subdomain,
                contact_email=contact_email,
                contact_phone=contact_phone,
                default_country_code=data.get('default_country_code', '+91'),
                logo=data.get('logo', '').strip(),
                address=data.get('address', '').strip(),
                gstin=data.get('gstin', '').strip(),
                website=data.get('website', '').strip(),
                plan=plan,
                plan_billing_cycle=plan_billing_cycle,
                plan_starts_at=plan_starts_at,
                plan_expires_at=plan_expires_at,
                allowed_menus=allowed_menus,
                created_by=request.user,
                assigned_super_admin=request.user,
                status='ACTIVE'
            )
            admin_user = User.objects.create_user(
                email=admin_email,
                password=admin_password,
                first_name=admin_first_name,
                last_name=admin_last_name,
                role='COMPANY_ADMIN',
                company=company,
                is_active=True
            )

            # Auto-seed initial Branch and default Categories for the new tenant
            from apps.leads.models import Branch, LeadCategory
            main_branch = Branch.objects.create(
                company=company,
                name='Main Branch',
                code='MAIN',
                address='Headquarters'
            )
            admin_user.branch = main_branch
            admin_user.save(update_fields=['branch'])

            LeadCategory.objects.create(company=company, name='Customer', color_code='#6366F1')
            LeadCategory.objects.create(company=company, name='Client', color_code='#10B981')
            LeadCategory.objects.create(company=company, name='Academy', color_code='#F59E0B')

        return Response({
            "company": CompanySerializer(company).data,
            "admin_email": admin_email,
            "temp_password": admin_password,
            "message": "Company tenant provisioned successfully with generated admin credentials."
        }, status=status.HTTP_201_CREATED)

class CompanyDetailView(views.APIView):
    def get_permissions(self):
        return [IsCompanyAdmin()]

    def get(self, request, pk):
        if request.user.is_master_admin:
            company = Company.objects.filter(id=pk).select_related('plan', 'created_by', 'assigned_super_admin').first()
        elif request.user.role == 'SUPER_ADMIN':
            company = Company.objects.filter(
                Q(created_by=request.user) | Q(assigned_super_admin=request.user),
                id=pk
            ).select_related('plan', 'created_by', 'assigned_super_admin').first()
        elif request.user.company_id == pk:
            company = request.user.company
        else:
            company = None

        if not company:
            return Response({"error": "Company not found"}, status=status.HTTP_404_NOT_FOUND)
        return Response(CompanySerializer(company).data)

    def patch(self, request, pk):
        if request.user.is_master_admin:
            company = Company.objects.filter(id=pk).first()
        elif request.user.role == 'SUPER_ADMIN':
            company = Company.objects.filter(
                Q(created_by=request.user) | Q(assigned_super_admin=request.user),
                id=pk
            ).first()
        elif request.user.company_id == pk:
            company = request.user.company
        else:
            return Response({"error": "Unauthorized"}, status=status.HTTP_403_FORBIDDEN)

        if not company:
            return Response({"error": "Company not found"}, status=status.HTTP_404_NOT_FOUND)

        # Non-super admin cannot change company status or plan or permissions
        if not request.user.is_super_admin:
            for restricted in ['status', 'plan', 'allowed_menus']:
                if restricted in request.data:
                    return Response({"error": f"Only super admin can change company {restricted}."}, status=status.HTTP_403_FORBIDDEN)

        serializer = CompanySerializer(company, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)

class MyCompanyView(views.APIView):
    permission_classes = [IsCompanyAdmin]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "No company assigned"}, status=status.HTTP_404_NOT_FOUND)
        return Response(CompanySerializer(company).data)

    def patch(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "No company assigned"}, status=status.HTTP_404_NOT_FOUND)

        if not request.user.is_super_admin:
            for restricted in ['status', 'plan', 'allowed_menus']:
                if restricted in request.data:
                    return Response({"error": f"Only super admin can change company {restricted}."}, status=status.HTTP_403_FORBIDDEN)

        serializer = CompanySerializer(company, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)

class CompanyPermissionsView(views.APIView):
    permission_classes = [IsSuperAdmin]

    def patch(self, request, pk):
        company = Company.objects.filter(id=pk).first()
        if not company:
            return Response({"error": "Company not found"}, status=status.HTTP_404_NOT_FOUND)

        allowed_menus = request.data.get('allowed_menus')
        plan_id = request.data.get('plan_id')

        if allowed_menus is not None:
            if not isinstance(allowed_menus, list):
                return Response({"error": "allowed_menus must be a list of menu keys."}, status=status.HTTP_400_BAD_REQUEST)
            company.allowed_menus = allowed_menus

        if plan_id:
            plan = get_plan_by_id_or_code(plan_id)
            if plan:
                company.plan = plan

        company.save()
        return Response({
            "message": "Company permissions updated successfully.",
            "company": CompanySerializer(company).data
        })

class CompanyRenewPlanView(views.APIView):
    permission_classes = [IsSuperAdmin]

    def post(self, request, pk):
        if request.user.is_master_admin:
            company = Company.objects.filter(id=pk).first()
        elif request.user.role == 'SUPER_ADMIN':
            company = Company.objects.filter(
                Q(created_by=request.user) | Q(assigned_super_admin=request.user),
                id=pk
            ).first()
        else:
            return Response({"error": "Unauthorized"}, status=status.HTTP_403_FORBIDDEN)

        if not company:
            return Response({"error": "Company not found"}, status=status.HTTP_404_NOT_FOUND)

        serializer = CompanyRenewPlanSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        billing_cycle = data.get('billing_cycle', 'MONTHLY')
        extension_days = data.get('extension_days', 30)
        new_expires_at = data.get('new_expires_at')
        plan_id = data.get('plan_id', '').strip()
        reactivate = data.get('reactivate', True)

        now = timezone.now()
        previous_expiry = company.plan_expires_at

        if new_expires_at:
            company.plan_expires_at = new_expires_at
            base_calc = previous_expiry if (previous_expiry and previous_expiry > now) else now
            calc_days = max(1, (new_expires_at - base_calc).days)
        else:
            if company.plan_expires_at and company.plan_expires_at > now:
                base_time = company.plan_expires_at
            else:
                base_time = now
            company.plan_expires_at = base_time + timedelta(days=extension_days)
            calc_days = extension_days

        company.plan_billing_cycle = billing_cycle

        if plan_id:
            new_plan = get_plan_by_id_or_code(plan_id)
            if new_plan:
                company.plan = new_plan

        if reactivate or company.status == 'SUSPENDED':
            company.status = 'ACTIVE'

        company.save()

        # Log into history
        CompanySubscriptionHistory.objects.create(
            company=company,
            plan_name=company.plan.name if company.plan else 'Standard',
            billing_cycle=billing_cycle,
            extension_days=calc_days,
            previous_expiry=previous_expiry,
            new_expiry=company.plan_expires_at,
            amount_paid=0.00,
            currency=company.plan.currency if company.plan else 'INR',
            approved_by=request.user,
            notes='Direct renewal by Admin'
        )

        return Response({
            "message": f"Plan renewed successfully until {company.plan_expires_at.strftime('%d %b %Y')}.",
            "company": CompanySerializer(company).data
        }, status=status.HTTP_200_OK)

class CompanyResetPasswordView(views.APIView):
    permission_classes = [IsSuperAdmin]

    def post(self, request, pk):
        company = Company.objects.filter(id=pk).first()
        if not company:
            return Response({"error": "Company not found"}, status=status.HTTP_404_NOT_FOUND)

        admin_user = User.objects.filter(company=company, role='COMPANY_ADMIN').first()
        if not admin_user:
            return Response({"error": "Company admin user not found."}, status=status.HTTP_404_NOT_FOUND)

        new_password = generate_temporary_password(10)
        admin_user.set_password(new_password)
        admin_user.save()

        return Response({
            "message": "New temporary password generated successfully.",
            "admin_email": admin_user.email,
            "temp_password": new_password,
            "company_name": company.name,
        })

class PlanListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'POST':
            return [IsSuperAdmin()]
        return [IsCompanyAdmin()]

    def get(self, request):
        plans = Plan.objects.all().order_by('price_monthly')
        return Response(PlanSerializer(plans, many=True).data)

    def post(self, request):
        serializer = PlanSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        plan = serializer.save()
        return Response(PlanSerializer(plan).data, status=status.HTTP_201_CREATED)

class PlanDetailView(views.APIView):
    permission_classes = [IsSuperAdmin]

    def patch(self, request, pk):
        plan = Plan.objects.filter(id=pk).first()
        if not plan:
            return Response({"error": "Plan not found"}, status=status.HTTP_404_NOT_FOUND)
        serializer = PlanSerializer(plan, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)

    def delete(self, request, pk):
        plan = Plan.objects.filter(id=pk).first()
        if not plan:
            return Response({"error": "Plan not found"}, status=status.HTTP_404_NOT_FOUND)
        plan.is_active = False
        plan.save(update_fields=['is_active'])
        return Response({"message": "Plan deactivated successfully."})

class PlatformBillingOverviewView(views.APIView):
    permission_classes = [IsSuperAdmin]

    def get(self, request):
        active_companies = Company.objects.filter(status='ACTIVE')
        total_companies = Company.objects.count()

        # Calculate MRR from active plans
        mrr = 0.0
        for comp in active_companies.select_related('plan'):
            if comp.plan:
                mrr += float(comp.plan.price_monthly)

        arr = mrr * 12.0

        plan_breakdown = []
        for plan in Plan.objects.all():
            comp_count = plan.companies.filter(status='ACTIVE').count()
            plan_breakdown.append({
                'plan_name': plan.name,
                'plan_code': plan.code,
                'monthly_price': float(plan.price_monthly),
                'active_subscribers': comp_count,
                'monthly_revenue': comp_count * float(plan.price_monthly),
            })

        return Response({
            'total_companies': total_companies,
            'active_subscribers': active_companies.count(),
            'monthly_recurring_revenue': mrr,
            'annual_recurring_revenue': arr,
            'currency': 'USD',
            'plan_breakdown': plan_breakdown,
        })


# ── Dynamic Payroll Policy & Rules Views ──────────────────────────────────────

class CompanyPayrollPolicyView(views.APIView):
    permission_classes = [IsEmployee]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "No company associated with user."}, status=status.HTTP_400_BAD_REQUEST)
        policy, _ = CompanyPayrollPolicy.objects.get_or_create(company=company)
        return Response(CompanyPayrollPolicySerializer(policy).data)

    def patch(self, request):
        user = request.user
        if not user.is_company_admin and not user.is_super_admin:
            return Response({"error": "Company Admin permissions required."}, status=status.HTTP_403_FORBIDDEN)
        company = user.company
        if not company:
            return Response({"error": "No company associated with user."}, status=status.HTTP_400_BAD_REQUEST)
        policy, _ = CompanyPayrollPolicy.objects.get_or_create(company=company)
        serializer = CompanyPayrollPolicySerializer(policy, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def put(self, request):
        return self.patch(request)


class CompanyCustomRuleListCreateView(views.APIView):
    permission_classes = [IsEmployee]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response([])
        rules = CompanyCustomRule.objects.filter(company=company).order_by('order', 'created_at')
        return Response(CompanyCustomRuleSerializer(rules, many=True).data)

    def post(self, request):
        user = request.user
        if not user.is_company_admin and not user.is_super_admin:
            return Response({"error": "Company Admin permissions required."}, status=status.HTTP_403_FORBIDDEN)
        company = user.company
        if not company:
            return Response({"error": "No company associated with user."}, status=status.HTTP_400_BAD_REQUEST)

        serializer = CompanyCustomRuleSerializer(data=request.data)
        if serializer.is_valid():
            rule = serializer.save(company=company)
            return Response(CompanyCustomRuleSerializer(rule).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class CompanyCustomRuleDetailView(views.APIView):
    permission_classes = [IsCompanyAdmin]

    def get(self, request, pk):
        company = request.user.company
        rule = CompanyCustomRule.objects.filter(id=pk, company=company).first()
        if not rule:
            return Response({"error": "Rule not found."}, status=status.HTTP_404_NOT_FOUND)
        return Response(CompanyCustomRuleSerializer(rule).data)

    def patch(self, request, pk):
        company = request.user.company
        rule = CompanyCustomRule.objects.filter(id=pk, company=company).first()
        if not rule:
            return Response({"error": "Rule not found."}, status=status.HTTP_404_NOT_FOUND)
        serializer = CompanyCustomRuleSerializer(rule, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def put(self, request, pk):
        return self.patch(request, pk)

    def delete(self, request, pk):
        company = request.user.company
        rule = CompanyCustomRule.objects.filter(id=pk, company=company).first()
        if not rule:
            return Response({"error": "Rule not found."}, status=status.HTTP_404_NOT_FOUND)
        rule.delete()
        return Response({"message": "Rule deleted successfully."}, status=status.HTTP_200_OK)


class CompanyRulePresetLoadView(views.APIView):
    permission_classes = [IsCompanyAdmin]

    def post(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "No company associated."}, status=status.HTTP_400_BAD_REQUEST)

        preset_key = request.data.get('preset_key', 'STANDARD').upper()
        policy, _ = CompanyPayrollPolicy.objects.get_or_create(company=company)

        # Clear existing rules if requested
        replace_existing = request.data.get('replace_existing', False)
        if replace_existing:
            CompanyCustomRule.objects.filter(company=company).delete()

        created_rules = []
        if preset_key == 'STANDARD':
            # Corporate Standard: 3 free lates; every 3 subsequent lates = 0.5 Day LOP
            policy.shift_start_time = '09:30:00'
            policy.shift_end_time = '18:30:00'
            policy.grace_period_minutes = 15
            policy.full_day_hours = 8.0
            policy.half_day_hours = 4.5
            policy.save()

            r1, _ = CompanyCustomRule.objects.get_or_create(
                company=company,
                name='Late Coming LOP Penalty',
                defaults={
                    'category': 'LATE_ARRIVAL',
                    'description': '3 free lates allowed per month. Every 3 late arrivals thereafter deducts 0.5 day salary.',
                    'trigger_metric': 'LATE_COUNT',
                    'operator': 'EVERY_N',
                    'free_allowance_count': 3,
                    'threshold_value': 3.0,
                    'action_type': 'LOP_DAYS',
                    'action_value': 0.5,
                    'is_active': True,
                    'order': 1,
                }
            )
            created_rules.append(r1)

            r2, _ = CompanyCustomRule.objects.get_or_create(
                company=company,
                name='Minimum Hours Half-Day Rule',
                defaults={
                    'category': 'WORKING_HOURS',
                    'description': 'Working less than 4.5 hours automatically counts as Half-Day LOP.',
                    'trigger_metric': 'WORKING_HOURS_BELOW',
                    'operator': 'LESS_THAN',
                    'threshold_value': 4.5,
                    'action_type': 'LOP_DAYS',
                    'action_value': 0.5,
                    'is_active': True,
                    'order': 2,
                }
            )
            created_rules.append(r2)

        elif preset_key == 'STRICT':
            # Strict Attendance: 0 free lates; 10 min grace; every 2 lates = 1.0 Day LOP
            policy.shift_start_time = '09:00:00'
            policy.shift_end_time = '18:00:00'
            policy.grace_period_minutes = 10
            policy.strict_geofence_block = True
            policy.save()

            r1, _ = CompanyCustomRule.objects.get_or_create(
                company=company,
                name='Strict Punctuality Penalty',
                defaults={
                    'category': 'LATE_ARRIVAL',
                    'description': 'Zero free lates. Every 2 late arrivals deducts 1 full day salary.',
                    'trigger_metric': 'LATE_COUNT',
                    'operator': 'EVERY_N',
                    'free_allowance_count': 0,
                    'threshold_value': 2.0,
                    'action_type': 'LOP_DAYS',
                    'action_value': 1.0,
                    'is_active': True,
                    'order': 1,
                }
            )
            created_rules.append(r1)

        elif preset_key == 'FLEXIBLE':
            # Flexible: 5 free lates; warning notice before penalty
            policy.shift_start_time = '10:00:00'
            policy.shift_end_time = '19:00:00'
            policy.grace_period_minutes = 30
            policy.save()

            r1, _ = CompanyCustomRule.objects.get_or_create(
                company=company,
                name='Punctuality Warning Alert',
                defaults={
                    'category': 'LATE_ARRIVAL',
                    'description': '5 free lates per month. Beyond 5, automated supervisor warning notice is issued.',
                    'trigger_metric': 'LATE_COUNT',
                    'operator': 'GREATER_EQUAL',
                    'free_allowance_count': 5,
                    'threshold_value': 5.0,
                    'action_type': 'WARNING',
                    'action_value': 0.0,
                    'is_active': True,
                    'order': 1,
                }
            )
            created_rules.append(r1)

        all_rules = CompanyCustomRule.objects.filter(company=company).order_by('order', 'created_at')
        return Response({
            "message": f"Preset '{preset_key}' applied successfully.",
            "policy": CompanyPayrollPolicySerializer(policy).data,
            "rules": CompanyCustomRuleSerializer(all_rules, many=True).data
        })


class SuperAdminManagementView(views.APIView):
    permission_classes = [IsMasterAdmin]

    def get(self, request):
        super_admins = User.objects.filter(role__in=['SUPER_ADMIN', 'MASTER_ADMIN']).order_by('-created_at')
        data = []
        for sa in super_admins:
            onboarded_qs = sa.onboarded_companies.all()
            total_tenants = onboarded_qs.count()
            active_tenants = onboarded_qs.filter(status='ACTIVE').count()
            total_users = User.objects.filter(company__in=onboarded_qs).count()

            companies_data = [
                {
                    "id": str(c.id),
                    "name": c.name,
                    "subdomain": c.subdomain,
                    "logo": c.logo,
                    "status": c.status,
                    "contact_email": c.contact_email,
                    "contact_phone": c.contact_phone,
                    "plan_name": c.plan.name if c.plan else 'Starter Lite',
                    "user_count": c.users.count(),
                    "created_at": c.created_at,
                }
                for c in onboarded_qs.select_related('plan').order_by('-created_at')
            ]

            data.append({
                "id": str(sa.id),
                "email": sa.email,
                "first_name": sa.first_name,
                "last_name": sa.last_name,
                "full_name": sa.full_name,
                "phone": sa.phone,
                "role": sa.role,
                "is_active": sa.is_active,
                "is_master_admin": sa.is_master_admin,
                "total_tenants": total_tenants,
                "active_tenants": active_tenants,
                "total_users": total_users,
                "companies": companies_data,
                "created_at": sa.created_at,
            })
        return Response({
            "super_admins": data,
            "total_super_admins": len(data),
            "total_platform_tenants": Company.objects.count(),
        })

    def post(self, request):
        email = request.data.get('email', '').strip().lower()
        first_name = request.data.get('first_name', '').strip()
        last_name = request.data.get('last_name', '').strip()
        phone = request.data.get('phone', '').strip()
        password = request.data.get('password', '').strip()
        role = request.data.get('role', 'SUPER_ADMIN')

        if not email:
            return Response({"error": "Email is required."}, status=status.HTTP_400_BAD_REQUEST)
        if not first_name:
            return Response({"error": "First name is required."}, status=status.HTTP_400_BAD_REQUEST)
        if User.objects.filter(email=email).exists():
            return Response({"error": f"A user with email '{email}' already exists."}, status=status.HTTP_400_BAD_REQUEST)

        if not password:
            password = generate_temporary_password(10)

        user = User.objects.create_user(
            email=email,
            password=password,
            first_name=first_name,
            last_name=last_name,
            phone=phone,
            role=role if role in ['SUPER_ADMIN', 'MASTER_ADMIN'] else 'SUPER_ADMIN',
            is_active=True,
            is_staff=True
        )

        return Response({
            "id": str(user.id),
            "email": user.email,
            "full_name": user.full_name,
            "role": user.role,
            "temp_password": password,
            "message": "Super Admin created successfully."
        }, status=status.HTTP_201_CREATED)


class SuperAdminToggleStatusView(views.APIView):
    permission_classes = [IsMasterAdmin]

    def patch(self, request, pk):
        sa = User.objects.filter(id=pk, role__in=['SUPER_ADMIN', 'MASTER_ADMIN']).first()
        if not sa:
            return Response({"error": "Super Admin not found."}, status=status.HTTP_404_NOT_FOUND)
        if sa.id == request.user.id:
            return Response({"error": "You cannot deactivate your own account."}, status=status.HTTP_400_BAD_REQUEST)

        sa.is_active = not sa.is_active
        sa.save(update_fields=['is_active'])
        return Response({
            "id": str(sa.id),
            "is_active": sa.is_active,
            "message": f"Super Admin {'activated' if sa.is_active else 'deactivated'} successfully."
        })


class SuperAdminResetPasswordView(views.APIView):
    permission_classes = [IsMasterAdmin]

    def post(self, request, pk):
        sa = User.objects.filter(id=pk, role__in=['SUPER_ADMIN', 'MASTER_ADMIN']).first()
        if not sa:
            return Response({"error": "Super Admin not found."}, status=status.HTTP_404_NOT_FOUND)

        new_password = request.data.get('password', '').strip()
        if not new_password:
            new_password = generate_temporary_password(10)

        sa.set_password(new_password)
        sa.save(update_fields=['password'])

        return Response({
            "id": str(sa.id),
            "email": sa.email,
            "full_name": sa.full_name,
            "temp_password": new_password,
            "message": f"Password for {sa.full_name} ({sa.email}) reset successfully."
        })


class ReassignTenantsView(views.APIView):
    permission_classes = [IsMasterAdmin]

    def post(self, request):
        from_id = request.data.get('from_super_admin_id')
        to_id = request.data.get('to_super_admin_id')
        company_ids = request.data.get('company_ids', [])

        if not from_id or not to_id:
            return Response({"error": "Both from_super_admin_id and to_super_admin_id are required."}, status=status.HTTP_400_BAD_REQUEST)

        to_sa = User.objects.filter(id=to_id, role__in=['SUPER_ADMIN', 'MASTER_ADMIN']).first()
        if not to_sa:
            return Response({"error": "Target Super Admin not found."}, status=status.HTTP_404_NOT_FOUND)

        qs = Company.objects.filter(Q(created_by_id=from_id) | Q(assigned_super_admin_id=from_id))
        if company_ids and company_ids != 'all':
            qs = qs.filter(id__in=company_ids)

        count = qs.count()
        qs.update(created_by=to_sa, assigned_super_admin=to_sa)

        return Response({
            "reassigned_count": count,
            "message": f"Successfully reassigned {count} company tenants to {to_sa.full_name} ({to_sa.email})."
        })


class CompanySuperAdminRequestView(views.APIView):
    permission_classes = [IsSuperAdmin]

    def post(self, request, pk):
        company = Company.objects.filter(id=pk).first()
        if not company:
            return Response({"error": "Company not found."}, status=status.HTTP_404_NOT_FOUND)

        request_type = request.data.get('request_type', 'SUPPORT')
        notes = request.data.get('notes', '').strip()
        target_super_admin_id = request.data.get('target_super_admin_id')
        user = request.user

        # If master admin is performing reassignment directly
        if user.is_master_admin and request_type == 'REASSIGNMENT' and target_super_admin_id:
            target_sa = User.objects.filter(id=target_super_admin_id, role__in=['SUPER_ADMIN', 'MASTER_ADMIN']).first()
            if target_sa:
                company.assigned_super_admin = target_sa
                company.created_by = target_sa
                company.save(update_fields=['assigned_super_admin', 'created_by'])
                return Response({
                    "message": f"Tenant '{company.name}' successfully reassigned to {target_sa.full_name}.",
                    "company": CompanySerializer(company).data
                })

        # Notify master admins
        master_admins = User.objects.filter(role='MASTER_ADMIN')
        from apps.notifications.models import Notification
        for ma in master_admins:
            Notification.objects.create(
                user=ma,
                company=company,
                title=f"Tenant Request: {company.name} ({request_type})",
                message=f"Super Admin {user.full_name} submitted a {request_type} request for {company.name}: {notes or 'No additional notes'}",
                notification_type='SYSTEM',
                entity_type='company',
                entity_id=str(company.id)
            )

        return Response({
            "message": f"Your {request_type.lower().replace('_', ' ')} request for '{company.name}' has been submitted to Master Admin.",
            "company": CompanySerializer(company).data
        })


# ── Tenant Renewal Requests & Subscription History Views ──────────────────────

class CompanyRenewalRequestListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'POST':
            return [IsEmployee()]
        return [IsEmployee()]

    def get(self, request):
        user = request.user
        queryset = CompanyRenewalRequest.objects.select_related('company', 'plan', 'requested_by', 'assigned_super_admin', 'approved_by')

        if user.is_master_admin:
            pass  # Master Admin can see all requests
        elif user.role == 'SUPER_ADMIN':
            queryset = queryset.filter(
                Q(assigned_super_admin=user) |
                Q(company__assigned_super_admin=user) |
                Q(company__created_by=user)
            )
        elif user.role in ['COMPANY_ADMIN', 'MANAGER']:
            if not user.company:
                return Response({"requests": [], "metrics": {"pending_count": 0, "total_count": 0}})
            queryset = queryset.filter(company=user.company)
        else:
            return Response({"error": "Unauthorized"}, status=status.HTTP_403_FORBIDDEN)

        status_filter = request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter.upper())

        company_id = request.query_params.get('company_id')
        if company_id:
            queryset = queryset.filter(company_id=company_id)

        all_user_requests = queryset
        pending_count = all_user_requests.filter(status='PENDING').count()
        approved_count = all_user_requests.filter(status='APPROVED').count()
        rejected_count = all_user_requests.filter(status='REJECTED').count()
        total_count = all_user_requests.count()

        items = queryset.order_by('-created_at')[:100]

        return Response({
            "requests": CompanyRenewalRequestSerializer(items, many=True).data,
            "metrics": {
                "pending_count": pending_count,
                "approved_count": approved_count,
                "rejected_count": rejected_count,
                "total_count": total_count,
            }
        })

    def post(self, request):
        user = request.user
        serializer = CompanyRenewalRequestCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        # Determine target company
        if user.role in ['COMPANY_ADMIN', 'MANAGER', 'EMPLOYEE']:
            company = user.company
            if not company:
                return Response({"error": "No company associated with user account."}, status=status.HTTP_400_BAD_REQUEST)
        else:
            company_id = request.data.get('company_id')
            if not company_id:
                return Response({"error": "company_id is required."}, status=status.HTTP_400_BAD_REQUEST)
            company = Company.objects.filter(id=company_id).first()
            if not company:
                return Response({"error": "Company not found."}, status=status.HTTP_404_NOT_FOUND)

        plan_id = data.get('plan_id', '').strip()
        requested_plan = get_plan_by_id_or_code(plan_id) if plan_id else company.plan

        assigned_sa = company.assigned_super_admin or company.created_by

        renewal_request = CompanyRenewalRequest.objects.create(
            company=company,
            requested_by=user,
            assigned_super_admin=assigned_sa,
            plan=requested_plan,
            billing_cycle=data.get('billing_cycle', 'MONTHLY'),
            requested_days=data.get('requested_days', 30),
            requested_date=data.get('requested_date'),
            payment_reference=data.get('payment_reference', '').strip(),
            notes=data.get('notes', '').strip(),
            status='PENDING'
        )

        # Notify assigned Super Admin
        from apps.notifications.models import Notification
        cycle_label = dict(CompanyRenewalRequest.CYCLE_CHOICES).get(renewal_request.billing_cycle, renewal_request.billing_cycle)

        if assigned_sa:
            Notification.objects.create(
                user=assigned_sa,
                company=company,
                title=f"Plan Renewal Request: {company.name} ⏳",
                message=f"{user.full_name} from {company.name} requested a plan renewal ({cycle_label}). Please review and approve.",
                notification_type='SYSTEM',
                entity_type='renewal_request',
                entity_id=str(renewal_request.id)
            )
        else:
            # Fallback: notify Master Admins
            for ma in User.objects.filter(role='MASTER_ADMIN'):
                Notification.objects.create(
                    user=ma,
                    company=company,
                    title=f"Plan Renewal Request: {company.name} ⏳",
                    message=f"{user.full_name} from {company.name} requested a plan renewal ({cycle_label}).",
                    notification_type='SYSTEM',
                    entity_type='renewal_request',
                    entity_id=str(renewal_request.id)
                )

        return Response({
            "message": f"Renewal request for '{company.name}' submitted successfully. Your Super Admin has been notified.",
            "renewal_request": CompanyRenewalRequestSerializer(renewal_request).data
        }, status=status.HTTP_201_CREATED)


class CompanyRenewalRequestApproveView(views.APIView):
    permission_classes = [IsSuperAdmin]

    def post(self, request, pk):
        renewal_req = CompanyRenewalRequest.objects.select_related('company', 'plan').filter(id=pk).first()
        if not renewal_req:
            return Response({"error": "Renewal request not found."}, status=status.HTTP_404_NOT_FOUND)

        if renewal_req.status == 'APPROVED':
            return Response({"error": "This request has already been approved."}, status=status.HTTP_400_BAD_REQUEST)

        company = renewal_req.company
        user = request.user

        # Authorization check: Master Admin OR Super Admin managing this company
        if not user.is_master_admin and company.assigned_super_admin_id != user.id and company.created_by_id != user.id:
            return Response({"error": "You do not have permission to approve renewals for this company."}, status=status.HTTP_403_FORBIDDEN)

        serializer = CompanyRenewalRequestApproveSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        billing_cycle = data.get('billing_cycle') or renewal_req.billing_cycle
        plan_id = data.get('plan_id', '').strip()
        admin_notes = data.get('admin_notes', '').strip()
        amount_paid = data.get('amount_paid', 0.00)
        currency = data.get('currency', 'INR')

        now = timezone.now()
        previous_expiry = company.plan_expires_at

        # ZERO-CALCULATION RULE:
        # If the plan is already expired or has no expiry date, start from ZERO (now).
        # Otherwise, extend from the current active expiry date.
        if not company.plan_expires_at or company.plan_expires_at <= now:
            base_time = now
        else:
            base_time = company.plan_expires_at

        target_date = data.get('target_expiry_date') or renewal_req.requested_date

        if billing_cycle == 'CUSTOM_DATE' and target_date:
            new_expiry = target_date
            extension_days = max(1, (new_expiry - base_time).days)
        elif billing_cycle == 'YEARLY':
            extension_days = 365
            new_expiry = base_time + timedelta(days=365)
        elif billing_cycle == 'MONTHLY':
            extension_days = 30
            new_expiry = base_time + timedelta(days=30)
        elif billing_cycle == 'DAYS':
            extension_days = data.get('extension_days') or renewal_req.requested_days or 30
            new_expiry = base_time + timedelta(days=extension_days)
        else:
            extension_days = data.get('extension_days') or renewal_req.requested_days or 30
            new_expiry = base_time + timedelta(days=extension_days)

        if plan_id:
            new_plan = get_plan_by_id_or_code(plan_id)
            if new_plan:
                company.plan = new_plan

        company.plan_expires_at = new_expiry
        company.plan_billing_cycle = billing_cycle
        if company.status == 'SUSPENDED':
            company.status = 'ACTIVE'
        company.save()

        # Update request
        renewal_req.status = 'APPROVED'
        renewal_req.approved_by = user
        renewal_req.approved_at = now
        renewal_req.admin_notes = admin_notes
        renewal_req.save()

        # Create history entry
        CompanySubscriptionHistory.objects.create(
            company=company,
            plan_name=company.plan.name if company.plan else 'Standard',
            billing_cycle=billing_cycle,
            extension_days=extension_days,
            previous_expiry=previous_expiry,
            new_expiry=new_expiry,
            amount_paid=amount_paid,
            currency=currency,
            approved_by=user,
            renewal_request=renewal_req,
            notes=admin_notes or f"Renewal approved by {user.full_name}"
        )

        # Send notification to tenant admin
        from apps.notifications.models import Notification
        tenant_admins = User.objects.filter(company=company, role='COMPANY_ADMIN')
        for admin in tenant_admins:
            Notification.objects.create(
                user=admin,
                company=company,
                title=f"Plan Renewed Successfully! 🎉",
                message=f"Your renewal request for {company.name} has been approved by {user.full_name}. Plan extended until {new_expiry.strftime('%d %b %Y')}.",
                notification_type='SYSTEM',
                entity_type='renewal_request',
                entity_id=str(renewal_req.id)
            )

        return Response({
            "message": f"Renewal approved successfully! Plan active until {new_expiry.strftime('%d %b %Y')}.",
            "renewal_request": CompanyRenewalRequestSerializer(renewal_req).data,
            "company": CompanySerializer(company).data
        }, status=status.HTTP_200_OK)


class CompanyRenewalRequestRejectView(views.APIView):
    permission_classes = [IsSuperAdmin]

    def post(self, request, pk):
        renewal_req = CompanyRenewalRequest.objects.select_related('company').filter(id=pk).first()
        if not renewal_req:
            return Response({"error": "Renewal request not found."}, status=status.HTTP_404_NOT_FOUND)

        company = renewal_req.company
        user = request.user

        if not user.is_master_admin and company.assigned_super_admin_id != user.id and company.created_by_id != user.id:
            return Response({"error": "You do not have permission to review renewals for this company."}, status=status.HTTP_403_FORBIDDEN)

        admin_notes = request.data.get('admin_notes', '').strip()
        renewal_req.status = 'REJECTED'
        renewal_req.approved_by = user
        renewal_req.approved_at = timezone.now()
        renewal_req.admin_notes = admin_notes
        renewal_req.save()

        # Send notification to tenant admin
        from apps.notifications.models import Notification
        tenant_admins = User.objects.filter(company=company, role='COMPANY_ADMIN')
        for admin in tenant_admins:
            Notification.objects.create(
                user=admin,
                company=company,
                title=f"Plan Renewal Request Update",
                message=f"Your renewal request for {company.name} was not approved. Note: {admin_notes or 'Please contact your Super Admin.'}",
                notification_type='SYSTEM',
                entity_type='renewal_request',
                entity_id=str(renewal_req.id)
            )

        return Response({
            "message": "Renewal request marked as rejected.",
            "renewal_request": CompanyRenewalRequestSerializer(renewal_req).data
        })


class CompanySubscriptionHistoryListView(views.APIView):
    def get_permissions(self):
        return [IsEmployee()]

    def get(self, request):
        user = request.user
        queryset = CompanySubscriptionHistory.objects.select_related('company', 'approved_by', 'renewal_request')

        if user.is_master_admin:
            pass  # Master admin sees all
        elif user.role == 'SUPER_ADMIN':
            queryset = queryset.filter(
                Q(company__assigned_super_admin=user) | Q(company__created_by=user)
            )
        elif user.role in ['COMPANY_ADMIN', 'MANAGER']:
            if not user.company:
                return Response({"history": [], "metrics": {}})
            queryset = queryset.filter(company=user.company)
        else:
            return Response({"error": "Unauthorized"}, status=status.HTTP_403_FORBIDDEN)

        company_id = request.query_params.get('company_id')
        if company_id:
            queryset = queryset.filter(company_id=company_id)

        cycle_filter = request.query_params.get('billing_cycle')
        if cycle_filter:
            queryset = queryset.filter(billing_cycle=cycle_filter.upper())

        # Metrics breakdown
        total_count = queryset.count()
        yearly_count = queryset.filter(billing_cycle='YEARLY').count()
        monthly_count = queryset.filter(billing_cycle='MONTHLY').count()
        days_count = queryset.filter(billing_cycle='DAYS').count()
        custom_date_count = queryset.filter(billing_cycle='CUSTOM_DATE').count()
        total_revenue = queryset.aggregate(total=Sum('amount_paid'))['total'] or 0.00

        history_items = queryset.order_by('-created_at')[:200]

        return Response({
            "history": CompanySubscriptionHistorySerializer(history_items, many=True).data,
            "metrics": {
                "total_renewals": total_count,
                "yearly_count": yearly_count,
                "monthly_count": monthly_count,
                "days_count": days_count,
                "custom_date_count": custom_date_count,
                "total_revenue": float(total_revenue),
            }
        })

