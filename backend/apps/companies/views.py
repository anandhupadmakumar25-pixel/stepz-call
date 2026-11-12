import uuid
import secrets
import string
from rest_framework import generics, status, views
from rest_framework.response import Response
from django.db import transaction
from django.contrib.auth import get_user_model
from django.db.models import Sum, Count
from apps.companies.models import Company, Plan, ALL_MENU_KEYS, CompanyPayrollPolicy, CompanyCustomRule
from apps.companies.serializers import CompanySerializer, CompanyCreateSerializer, PlanSerializer, CompanyPayrollPolicySerializer, CompanyCustomRuleSerializer
from apps.core.permissions import IsSuperAdmin, IsCompanyAdmin, IsEmployee

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
        if request.user.is_super_admin:
            companies = Company.objects.all().select_related('plan').order_by('-created_at')
            return Response(CompanySerializer(companies, many=True).data)
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
                allowed_menus=allowed_menus,
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
        if request.user.is_super_admin:
            company = Company.objects.filter(id=pk).select_related('plan').first()
        elif request.user.company_id == pk:
            company = request.user.company
        else:
            company = None

        if not company:
            return Response({"error": "Company not found"}, status=status.HTTP_404_NOT_FOUND)
        return Response(CompanySerializer(company).data)

    def patch(self, request, pk):
        if not request.user.is_super_admin and request.user.company_id != pk:
            return Response({"error": "Unauthorized"}, status=status.HTTP_403_FORBIDDEN)

        company = Company.objects.filter(id=pk).first()
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
