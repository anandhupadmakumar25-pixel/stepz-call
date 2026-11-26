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
    FEATURE_CATALOG,
    FeatureRequest,
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
    FeatureRequestSerializer,
)
from apps.core.permissions import IsSuperAdmin, IsCompanyAdmin, IsEmployee, IsMasterAdmin
from rest_framework.permissions import AllowAny, IsAuthenticated

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
            companies = list(qs.order_by('-created_at'))
            for c in companies:
                c.check_and_update_status()
            return Response(CompanySerializer(companies, many=True).data)
        elif request.user.role == 'SUPER_ADMIN':
            qs = Company.objects.filter(
                Q(created_by=request.user) | Q(assigned_super_admin=request.user)
            ).select_related('plan', 'created_by', 'assigned_super_admin').order_by('-created_at')
            companies = list(qs)
            for c in companies:
                c.check_and_update_status()
            return Response(CompanySerializer(companies, many=True).data)
        elif request.user.company:
            request.user.company.check_and_update_status()
            return Response([CompanySerializer(request.user.company).data])
        return Response([])

    def post(self, request):
        serializer = CompanyCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        admin_email = data['admin_email'].strip()
        admin_username = data.get('admin_username', '').strip() or None
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

        if admin_username and User.objects.filter(username__iexact=admin_username).exists():
            return Response({"error": f"A user with username '{admin_username}' already exists. Please choose a different username."}, status=status.HTTP_400_BAD_REQUEST)

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
                username=admin_username,
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

            if plan:
                initial_amount = (
                    plan.price_yearly if plan_billing_cycle == 'YEARLY'
                    else plan.price_monthly
                )
                init_status = str(request.data.get('initial_payment_status') or 'DUE').upper()
                if init_status == 'DUE':
                    paid_val = 0.00
                    due_val = initial_amount
                    pay_mode = 'DUE'
                    pay_notes = 'Initial plan billing marked as Due on company creation'
                else:
                    paid_val = float(request.data.get('initial_amount_paid') or initial_amount)
                    due_val = max(0.0, float(initial_amount) - paid_val)
                    init_status = 'PARTIAL' if due_val > 0 and paid_val > 0 else 'PAID'
                    pay_mode = str(request.data.get('payment_mode') or 'BANK_TRANSFER').upper()
                    pay_notes = 'Initial plan billing on company creation'
                CompanySubscriptionHistory.objects.create(
                    company=company,
                    plan_name=plan.name,
                    billing_cycle=plan_billing_cycle if plan_billing_cycle in ['MONTHLY', 'YEARLY', 'DAYS', 'CUSTOM_DATE'] else 'MONTHLY',
                    extension_days=plan_duration_days,
                    previous_expiry=None,
                    new_expiry=plan_expires_at,
                    amount_paid=paid_val,
                    due_amount=due_val,
                    currency=plan.currency,
                    payment_status=init_status,
                    payment_mode=pay_mode,
                    transaction_ref=str(request.data.get('transaction_ref') or '').strip(),
                    approved_by=request.user,
                    notes=pay_notes,
                )

        return Response({
            "company": CompanySerializer(company).data,
            "admin_email": admin_email,
            "admin_username": admin_username or '',
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

    def delete(self, request, pk):
        if not request.user.is_super_admin:
            return Response(
                {"error": "Only Super Admin or Master Admin can delete a company."},
                status=status.HTTP_403_FORBIDDEN,
            )

        if request.user.is_master_admin:
            company = Company.objects.filter(id=pk).first()
        else:
            company = Company.objects.filter(
                Q(created_by=request.user) | Q(assigned_super_admin=request.user),
                id=pk,
            ).first()

        if not company:
            return Response({"error": "Company not found."}, status=status.HTTP_404_NOT_FOUND)

        company_name = company.name
        try:
            with transaction.atomic():
                company.delete()
            return Response(
                {"message": f"Company '{company_name}' deleted permanently."},
                status=status.HTTP_200_OK,
            )
        except Exception as e:
            return Response(
                {"error": f"Failed to delete company: {str(e)}"},
                status=status.HTTP_400_BAD_REQUEST,
            )

class MyCompanyView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [IsCompanyAdmin()]

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

        # Calculate expected renewal amount & payment status (defaults to DUE unless marked PAID/PARTIAL)
        expected_amount = 0.0
        if company.plan:
            if billing_cycle == 'YEARLY':
                expected_amount = float(company.plan.price_yearly or 0)
            elif billing_cycle == 'QUARTERLY':
                expected_amount = round(float(company.plan.price_monthly or 0) * 3, 2)
            elif billing_cycle == 'MONTHLY':
                expected_amount = float(company.plan.price_monthly or 0)
            else:
                expected_amount = round(float(company.plan.price_monthly or 0) * max(1.0, calc_days / 30.0), 2)

        pay_status = str(request.data.get('payment_status') or 'DUE').upper()
        if pay_status == 'DUE':
            paid_val = 0.00
            due_val = expected_amount
            pay_mode = 'DUE'
            pay_notes = 'Plan renewed (marked as Due)'
        else:
            try:
                paid_val = float(request.data.get('amount_paid') or expected_amount)
            except (TypeError, ValueError):
                paid_val = expected_amount
            due_val = max(0.0, expected_amount - paid_val)
            pay_status = 'PARTIAL' if due_val > 0 and paid_val > 0 else 'PAID'
            pay_mode = str(request.data.get('payment_mode') or 'BANK_TRANSFER').upper()
            pay_notes = 'Plan renewed & payment recorded'

        if paid_val > 0:
            to_settle = paid_val
            open_dues = CompanySubscriptionHistory.objects.filter(company=company, due_amount__gt=0).order_by('created_at')
            for old_h in open_dues:
                if to_settle <= 0:
                    break
                old_due = float(old_h.due_amount or 0)
                if to_settle >= old_due:
                    old_h.due_amount = 0
                    old_h.payment_status = 'PAID'
                    to_settle -= old_due
                else:
                    old_h.due_amount = old_due - to_settle
                    old_h.payment_status = 'PARTIAL'
                    to_settle = 0
                old_h.save(update_fields=['due_amount', 'payment_status', 'updated_at'])

        # Log into history
        CompanySubscriptionHistory.objects.create(
            company=company,
            plan_name=company.plan.name if company.plan else 'Standard',
            billing_cycle=billing_cycle if billing_cycle in ['MONTHLY', 'YEARLY', 'DAYS', 'CUSTOM_DATE'] else 'MONTHLY',
            extension_days=calc_days,
            previous_expiry=previous_expiry,
            new_expiry=company.plan_expires_at,
            amount_paid=paid_val,
            due_amount=due_val,
            currency=company.plan.currency if company.plan else 'INR',
            payment_status=pay_status,
            payment_mode=pay_mode,
            transaction_ref=str(request.data.get('transaction_ref') or '').strip(),
            approved_by=request.user,
            notes=pay_notes,
        )

        return Response({
            "message": f"Plan renewed successfully until {company.plan_expires_at.strftime('%d %b %Y')}.",
            "company": CompanySerializer(company).data
        }, status=status.HTTP_200_OK)


class CompanyCollectPaymentView(views.APIView):
    """
    Allows Master Admin (any tenant) or Super Admin (their own assigned/created tenants)
    to mark a company payment as Paid / Partial, settle open dues, generate a receipt,
    and optionally extend validity & reactivate a suspended tenant.
    """
    permission_classes = [IsSuperAdmin]

    def post(self, request, pk):
        company = Company.objects.select_related('plan', 'assigned_super_admin', 'created_by').filter(id=pk).first()
        if not company:
            return Response({"error": "Company not found"}, status=status.HTTP_404_NOT_FOUND)

        if not request.user.is_master_admin:
            if company.assigned_super_admin_id != request.user.id and company.created_by_id != request.user.id:
                return Response(
                    {"error": "You can only record payments for tenants assigned to or created by you."},
                    status=status.HTTP_403_FORBIDDEN,
                )

        try:
            amount_paid = float(request.data.get('amount_paid') or 0.0)
        except (TypeError, ValueError):
            return Response({"error": "Invalid amount_paid"}, status=status.HTTP_400_BAD_REQUEST)

        if amount_paid <= 0:
            return Response({"error": "amount_paid must be greater than 0"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            remaining_due = max(0.0, float(request.data.get('due_amount') or 0.0))
        except (TypeError, ValueError):
            remaining_due = 0.0

        billing_cycle = str(request.data.get('billing_cycle') or company.plan_billing_cycle or 'MONTHLY').upper()
        if billing_cycle not in ['MONTHLY', 'YEARLY', 'DAYS', 'CUSTOM_DATE']:
            billing_cycle = 'MONTHLY'

        try:
            extension_days = int(request.data.get('extension_days') or (365 if billing_cycle == 'YEARLY' else 30))
        except (TypeError, ValueError):
            extension_days = 30

        payment_mode = str(request.data.get('payment_mode') or 'BANK_TRANSFER').upper()
        transaction_ref = str(request.data.get('transaction_ref') or '').strip()
        notes = str(request.data.get('notes') or 'Subscription payment collected').strip()
        currency = str(request.data.get('currency') or (company.plan.currency if company.plan else 'INR')).strip().upper()

        now = timezone.now()
        previous_expiry = company.plan_expires_at
        if extension_days > 0:
            base_date = previous_expiry if (previous_expiry and previous_expiry > now) else now
            company.plan_expires_at = base_date + timedelta(days=extension_days)

        company.plan_billing_cycle = billing_cycle
        if company.status != 'ACTIVE':
            company.status = 'ACTIVE'
        company.save()

        # Clear/settle open DUE amounts on earlier history rows when payment is collected
        open_dues = CompanySubscriptionHistory.objects.filter(company=company, due_amount__gt=0).order_by('created_at')
        to_settle = amount_paid
        for old_h in open_dues:
            if to_settle <= 0:
                break
            old_due = float(old_h.due_amount or 0)
            if to_settle >= old_due:
                to_settle -= old_due
                old_h.due_amount = 0.00
                if old_h.payment_status == 'DUE':
                    old_h.payment_status = 'PAID'
                old_h.save(update_fields=['due_amount', 'payment_status', 'updated_at'])
            else:
                old_h.due_amount = round(old_due - to_settle, 2)
                old_h.payment_status = 'PARTIAL'
                to_settle = 0
                old_h.save(update_fields=['due_amount', 'payment_status', 'updated_at'])

        hist = CompanySubscriptionHistory.objects.create(
            company=company,
            plan_name=company.plan.name if company.plan else 'Standard',
            billing_cycle=billing_cycle,
            extension_days=max(0, extension_days),
            previous_expiry=previous_expiry,
            new_expiry=company.plan_expires_at or now,
            amount_paid=amount_paid,
            due_amount=remaining_due,
            currency=currency,
            payment_status='PARTIAL' if remaining_due > 0 else 'PAID',
            payment_mode=payment_mode,
            transaction_ref=transaction_ref,
            approved_by=request.user,
            notes=notes,
        )

        return Response({
            "message": f"Payment recorded ({hist.receipt_number}) for {company.name}.",
            "receipt": CompanySubscriptionHistorySerializer(hist).data,
            "company": CompanySerializer(company).data,
        }, status=status.HTTP_201_CREATED)

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
        return [IsAuthenticated()]

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
        from apps.accounts.region_utils import resolve_request_country
        from apps.billing.fx_utils import get_fx_rates, convert_amount, build_fx_metric

        user = request.user
        _, _, target_currency, target_symbol = resolve_request_country(request, company=None)
        rates = get_fx_rates()
        now_year = timezone.now().year

        base_companies = Company.objects.all().select_related('plan', 'assigned_super_admin', 'created_by')
        if not user.is_master_admin:
            base_companies = base_companies.filter(
                Q(assigned_super_admin=user) | Q(created_by=user)
            )

        companies_list = list(base_companies)
        for c in companies_list:
            c.check_and_update_status()
        total_companies = len(companies_list)
        active_companies = [c for c in companies_list if c.status == 'ACTIVE']
        suspended_count = total_companies - len(active_companies)

        # Actual collected revenue & open dues from subscription history
        histories = list(
            CompanySubscriptionHistory.objects.filter(company__in=base_companies)
            .select_related('company', 'approved_by', 'company__assigned_super_admin', 'company__created_by')
            .order_by('-created_at')
        )
        paid_by_company = {}
        due_by_company = {}
        collected_by_curr = {}
        due_by_curr = {}
        actual_collected_total = 0.0
        actual_collected_ytd = 0.0
        total_due = 0.0
        receipts_payload = []
        for h in histories:
            amt = float(h.amount_paid or 0.0)
            due_amt = float(h.due_amount or 0.0)
            curr = (h.currency or 'INR').strip().upper()
            conv = convert_amount(amt, curr, target_currency, rates)
            conv_due = convert_amount(due_amt, curr, target_currency, rates)

            if amt > 0:
                actual_collected_total += conv
                if h.created_at and h.created_at.year == now_year:
                    actual_collected_ytd += conv
                paid_by_company[h.company_id] = paid_by_company.get(h.company_id, 0.0) + conv
                collected_by_curr[curr] = collected_by_curr.get(curr, 0.0) + amt

            if due_amt > 0:
                total_due += conv_due
                due_by_company[h.company_id] = due_by_company.get(h.company_id, 0.0) + conv_due
                due_by_curr[curr] = due_by_curr.get(curr, 0.0) + due_amt

            if len(receipts_payload) < 40 and (amt > 0 or due_amt > 0):
                h_owner = h.company.assigned_super_admin or h.company.created_by
                h_owner_name = (
                    'Platform Master (Direct)'
                    if (h_owner is None or getattr(h_owner, 'is_master_admin', False))
                    else (h_owner.full_name or h_owner.email)
                )
                receipts_payload.append({
                    'id': str(h.id),
                    'receipt_number': h.receipt_number or f'SUB-{str(h.id)[:6].upper()}',
                    'company_id': str(h.company_id),
                    'company_name': h.company.name,
                    'company_email': h.company.contact_email,
                    'owner_name': h_owner_name,
                    'plan_name': h.plan_name,
                    'billing_cycle': h.billing_cycle,
                    'extension_days': h.extension_days,
                    'previous_expiry': h.previous_expiry.isoformat() if h.previous_expiry else None,
                    'new_expiry': h.new_expiry.isoformat() if h.new_expiry else None,
                    'amount_paid': round(amt, 2),
                    'due_amount': round(due_amt, 2),
                    'converted_paid': round(conv, 2),
                    'converted_due': round(conv_due, 2),
                    'currency': curr,
                    'payment_status': h.payment_status,
                    'payment_mode': h.payment_mode,
                    'transaction_ref': h.transaction_ref,
                    'approved_by_name': h.approved_by.full_name if h.approved_by else 'System',
                    'notes': h.notes,
                    'created_at': h.created_at.isoformat() if h.created_at else None,
                })

        # Active MRR & Projected Annual (ACTIVE non-suspended tenants only)
        mrr = 0.0
        mrr_by_curr = {}
        owner_map = {}
        tenant_breakdown = []

        for comp in companies_list:
            owner = comp.assigned_super_admin or comp.created_by
            if owner is None or getattr(owner, 'is_master_admin', False):
                owner_key = 'MASTER'
                owner_name = 'Platform Master (Direct)'
                owner_email = getattr(owner, 'email', '') if owner else ''
            else:
                owner_key = str(owner.id)
                owner_name = owner.full_name or owner.email
                owner_email = owner.email

            if owner_key not in owner_map:
                owner_map[owner_key] = {
                    'owner_id': owner_key,
                    'owner_name': owner_name,
                    'owner_email': owner_email,
                    'total_tenants': 0,
                    'active_tenants': 0,
                    'suspended_tenants': 0,
                    'active_mrr': 0.0,
                    'projected_annual': 0.0,
                    'actual_collected': 0.0,
                    'due_amount': 0.0,
                }

            owner_entry = owner_map[owner_key]
            owner_entry['total_tenants'] += 1
            comp_paid = round(paid_by_company.get(comp.id, 0.0), 2)
            comp_due = round(due_by_company.get(comp.id, 0.0), 2)
            owner_entry['actual_collected'] = round(owner_entry['actual_collected'] + comp_paid, 2)
            owner_entry['due_amount'] = round(owner_entry['due_amount'] + comp_due, 2)

            plan_curr = (comp.plan.currency if comp.plan else 'INR').strip().upper()
            monthly_raw = 0.0
            if comp.plan:
                if comp.plan_billing_cycle == 'YEARLY' and float(comp.plan.price_yearly or 0) > 0:
                    monthly_raw = float(comp.plan.price_yearly) / 12.0
                else:
                    monthly_raw = float(comp.plan.price_monthly or 0)
            monthly_conv = convert_amount(monthly_raw, plan_curr, target_currency, rates)

            if comp.status == 'ACTIVE':
                owner_entry['active_tenants'] += 1
                mrr += monthly_conv
                mrr_by_curr[plan_curr] = mrr_by_curr.get(plan_curr, 0.0) + monthly_raw
                owner_entry['active_mrr'] = round(owner_entry['active_mrr'] + monthly_conv, 2)
                owner_entry['projected_annual'] = round(owner_entry['active_mrr'] * 12.0, 2)
            else:
                owner_entry['suspended_tenants'] += 1

            tenant_breakdown.append({
                'id': str(comp.id),
                'name': comp.name,
                'admin_email': comp.contact_email,
                'status': comp.status,
                'plan_name': comp.plan.name if comp.plan else 'Starter',
                'billing_cycle': comp.plan_billing_cycle,
                'plan_currency': plan_curr,
                'monthly_rate_converted': round(monthly_conv if comp.status == 'ACTIVE' else 0.0, 2),
                'monthly_rate_raw': round(monthly_raw, 2),
                'actual_paid': comp_paid,
                'due_amount': comp_due,
                'owner_name': owner_name,
            })

        arr = round(mrr * 12.0, 2)
        mrr = round(mrr, 2)
        actual_collected_total = round(actual_collected_total, 2)
        actual_collected_ytd = round(actual_collected_ytd, 2)
        total_due = round(total_due, 2)

        _, mrr_fx, mrr_fx_text, _ = build_fx_metric(mrr_by_curr, target_currency, target_symbol, rates)
        _, col_fx, col_fx_text, _ = build_fx_metric(collected_by_curr, target_currency, target_symbol, rates)
        _, due_fx, due_fx_text, _ = build_fx_metric(due_by_curr, target_currency, target_symbol, rates)

        plan_breakdown = []
        for plan in Plan.objects.all():
            plan_active = [c for c in active_companies if c.plan_id == plan.id]
            plan_curr = (plan.currency or 'INR').strip().upper()
            plan_mrr_conv = sum(
                convert_amount(
                    float(plan.price_yearly) / 12.0
                    if (c.plan_billing_cycle == 'YEARLY' and float(plan.price_yearly or 0) > 0)
                    else float(plan.price_monthly or 0),
                    plan_curr,
                    target_currency,
                    rates,
                )
                for c in plan_active
            )
            plan_breakdown.append({
                'plan_name': plan.name,
                'plan_code': plan.code,
                'plan_currency': plan_curr,
                'monthly_price': float(plan.price_monthly),
                'active_subscribers': len(plan_active),
                'monthly_revenue': round(plan_mrr_conv, 2),
            })

        owner_breakdown = sorted(
            owner_map.values(),
            key=lambda x: (x['actual_collected'], x['active_mrr']),
            reverse=True,
        )

        return Response({
            'total_companies': total_companies,
            'active_subscribers': len(active_companies),
            'suspended_subscribers': suspended_count,
            'monthly_recurring_revenue': mrr,
            'annual_recurring_revenue': arr,
            'actual_collected_total': actual_collected_total,
            'actual_collected_ytd': actual_collected_ytd,
            'total_due': total_due,
            'currency': target_currency,
            'currency_symbol': target_symbol,
            'has_fx_conversion': mrr_fx or col_fx or due_fx,
            'fx_mrr_text': mrr_fx_text,
            'fx_collected_text': col_fx_text,
            'fx_due_text': due_fx_text,
            'plan_breakdown': plan_breakdown,
            'owner_breakdown': owner_breakdown,
            'tenant_breakdown': tenant_breakdown,
            'receipts': receipts_payload,
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

class CompanyPublicRenewalRequestView(views.APIView):
    """
    Public lockout-friendly endpoint: allows expired/suspended tenants who CANNOT log in
    to submit a plan renewal request directly to their assigned Super Admin.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email', '').strip().lower()
        company_id = request.data.get('company_id')
        billing_cycle = request.data.get('billing_cycle', 'MONTHLY')
        requested_days = int(request.data.get('requested_days', 30))
        requested_date = request.data.get('requested_date')
        payment_reference = request.data.get('payment_reference', '').strip()
        notes = request.data.get('notes', '').strip()

        if not email and not company_id:
            return Response({"error": "Administrator email or company_id is required."}, status=status.HTTP_400_BAD_REQUEST)

        user = None
        company = None

        if email:
            user = User.objects.filter(email=email).first()
            if user and user.company:
                company = user.company

        if not company and company_id:
            company = Company.objects.filter(id=company_id).first()
            if company and not user:
                user = User.objects.filter(company=company, role='COMPANY_ADMIN').first()

        if not company:
            return Response({"error": "No registered tenant organization was found for the provided details."}, status=status.HTTP_404_NOT_FOUND)

        assigned_sa = company.assigned_super_admin or company.created_by

        renewal_request = CompanyRenewalRequest.objects.create(
            company=company,
            requested_by=user,
            assigned_super_admin=assigned_sa,
            plan=company.plan,
            billing_cycle=billing_cycle,
            requested_days=requested_days,
            requested_date=requested_date,
            payment_reference=payment_reference,
            notes=notes,
            status='PENDING'
        )

        from apps.notifications.models import Notification
        cycle_label = dict(CompanyRenewalRequest.CYCLE_CHOICES).get(billing_cycle, billing_cycle)
        requester_name = user.full_name if user else company.name

        if assigned_sa:
            Notification.objects.create(
                user=assigned_sa,
                company=company,
                title=f"Plan Renewal Request: {company.name} ⏳",
                message=f"{requester_name} from {company.name} requested a plan renewal ({cycle_label}). Please review and approve.",
                notification_type='SYSTEM',
                entity_type='renewal_request',
                entity_id=str(renewal_request.id)
            )
        else:
            for ma in User.objects.filter(role='MASTER_ADMIN'):
                Notification.objects.create(
                    user=ma,
                    company=company,
                    title=f"Plan Renewal Request: {company.name} ⏳",
                    message=f"{requester_name} from {company.name} requested a plan renewal ({cycle_label}).",
                    notification_type='SYSTEM',
                    entity_type='renewal_request',
                    entity_id=str(renewal_request.id)
                )

        sa_name = assigned_sa.full_name if assigned_sa else "Platform Administrator"
        return Response({
            "message": f"Renewal request for '{company.name}' submitted successfully. Your Super Admin ({sa_name}) has been notified to review and reactivate your workspace.",
            "renewal_request": CompanyRenewalRequestSerializer(renewal_request).data
        }, status=status.HTTP_201_CREATED)


class CompanyRenewalRequestListCreateView(views.APIView):
    permission_classes = [IsAuthenticated]

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
        elif user.role in ['COMPANY_ADMIN', 'MANAGER', 'EMPLOYEE']:
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

        # Determine target company:
        company_id = request.data.get('company_id')
        if company_id:
            company = Company.objects.filter(id=company_id).first()
        elif user.company:
            company = user.company
        else:
            return Response({"error": "No company specified or associated with user account."}, status=status.HTTP_400_BAD_REQUEST)

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

        # Authorization check: Master Admin OR Super Admin managing this company (or if company is unassigned)
        if not user.is_master_admin and company.assigned_super_admin_id and company.assigned_super_admin_id != user.id and company.created_by_id != user.id:
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
        if not company.assigned_super_admin:
            company.assigned_super_admin = user
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

        if not user.is_master_admin and company.assigned_super_admin_id and company.assigned_super_admin_id != user.id and company.created_by_id != user.id:
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
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        queryset = CompanySubscriptionHistory.objects.select_related('company', 'approved_by', 'renewal_request')

        if user.is_master_admin:
            pass  # Master admin sees all
        elif user.role == 'SUPER_ADMIN':
            queryset = queryset.filter(
                Q(company__assigned_super_admin=user) | Q(company__created_by=user)
            )
        elif user.role in ['COMPANY_ADMIN', 'MANAGER', 'EMPLOYEE']:
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


class FeatureCatalogView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        company = request.user.company
        pending_keys = set()
        if company:
            pending_keys = set(
                FeatureRequest.objects.filter(
                    company=company,
                    status='PENDING'
                ).values_list('feature_key', flat=True)
            )

        items = []
        for entry in FEATURE_CATALOG:
            key = entry['key']
            is_enabled = company.has_menu_permission(key) if company else True
            items.append({
                **entry,
                'is_enabled': is_enabled,
                'has_pending_request': key in pending_keys,
            })
        return Response(items)


class FeatureRequestListCreateView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        qs = FeatureRequest.objects.select_related('company', 'requested_by', 'reviewed_by')
        if user.is_master_admin:
            pass
        elif user.role == 'SUPER_ADMIN':
            qs = qs.filter(request_type='COMPANY_FEATURE').filter(
                Q(company__assigned_super_admin=user) | Q(company__created_by=user)
            )
        elif user.role == 'COMPANY_ADMIN' and user.company:
            qs = qs.filter(company=user.company)
        elif user.company:
            qs = qs.filter(company=user.company, requested_by=user)
        else:
            return Response([])

        status_filter = request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter.upper())
        return Response(FeatureRequestSerializer(qs[:200], many=True).data)

    def post(self, request):
        user = request.user
        company = user.company
        if not company:
            return Response({"error": "Company account required"}, status=status.HTTP_400_BAD_REQUEST)

        feature_key = (request.data.get('feature_key') or '').strip()
        feature_name = (request.data.get('feature_name') or '').strip()
        request_type = (request.data.get('request_type') or 'COMPANY_FEATURE').strip().upper()
        note = (request.data.get('note') or '').strip()

        if not feature_key:
            return Response({"error": "feature_key is required"}, status=status.HTTP_400_BAD_REQUEST)
        if request_type not in ['COMPANY_FEATURE', 'USER_PERMISSION']:
            return Response({"error": "Invalid request_type"}, status=status.HTTP_400_BAD_REQUEST)

        if not feature_name:
            match = next((f for f in FEATURE_CATALOG if f['key'] == feature_key), None)
            feature_name = match['name'] if match else feature_key.replace('_', ' ').title()

        existing = FeatureRequest.objects.filter(
            company=company,
            feature_key=feature_key,
            request_type=request_type,
            status='PENDING',
        )
        if request_type == 'USER_PERMISSION':
            existing = existing.filter(requested_by=user)
        if existing.exists():
            return Response(
                {"error": "A pending request for this feature already exists."},
                status=status.HTTP_400_BAD_REQUEST
            )

        req_obj = FeatureRequest.objects.create(
            company=company,
            requested_by=user,
            request_type=request_type,
            feature_key=feature_key,
            feature_name=feature_name,
            note=note,
        )

        from apps.notifications.models import Notification
        if request_type == 'COMPANY_FEATURE':
            recipients = (
                [company.assigned_super_admin]
                if company.assigned_super_admin
                else list(User.objects.filter(role='SUPER_ADMIN', is_active=True)[:5])
            )
            for recipient in recipients:
                if recipient:
                    Notification.objects.create(
                        user=recipient,
                        company=company,
                        title=f"Feature Request: {feature_name}",
                        message=f"{company.name} ({user.full_name}) requested access to '{feature_name}'.",
                        notification_type='SYSTEM',
                        entity_type='feature_request',
                        entity_id=str(req_obj.id),
                    )
        else:
            admins = User.objects.filter(company=company, role='COMPANY_ADMIN', is_active=True)
            for admin in admins:
                Notification.objects.create(
                    user=admin,
                    company=company,
                    title=f"Permission Request: {feature_name}",
                    message=f"{user.full_name} requested '{feature_name}' permission.",
                    notification_type='SYSTEM',
                    entity_type='feature_request',
                    entity_id=str(req_obj.id),
                )

        return Response(FeatureRequestSerializer(req_obj).data, status=status.HTTP_201_CREATED)


class FeatureRequestReviewView(views.APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        user = request.user
        req_obj = FeatureRequest.objects.select_related('company', 'requested_by').filter(id=pk).first()
        if not req_obj:
            return Response({"error": "Feature request not found"}, status=status.HTTP_404_NOT_FOUND)

        if req_obj.request_type == 'COMPANY_FEATURE':
            if not (user.is_master_admin or user.role == 'SUPER_ADMIN'):
                return Response({"error": "Only Super Admin can review company feature requests"}, status=status.HTTP_403_FORBIDDEN)
        else:
            if not (user.is_master_admin or user.role == 'SUPER_ADMIN' or (user.role == 'COMPANY_ADMIN' and user.company_id == req_obj.company_id)):
                return Response({"error": "Only Company Admin can review permission requests"}, status=status.HTTP_403_FORBIDDEN)

        new_status = (request.data.get('status') or '').strip().upper()
        review_note = (request.data.get('review_note') or '').strip()
        if new_status not in ['APPROVED', 'REJECTED']:
            return Response({"error": "Status must be APPROVED or REJECTED"}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            req_obj.status = new_status
            req_obj.reviewed_by = user
            req_obj.reviewed_at = timezone.now()
            req_obj.review_note = review_note
            req_obj.save()

            if new_status == 'APPROVED' and req_obj.request_type == 'COMPANY_FEATURE':
                company = req_obj.company
                current_menus = list(company.allowed_menus or company.get_allowed_menus())
                if req_obj.feature_key not in current_menus:
                    current_menus.append(req_obj.feature_key)
                    company.allowed_menus = current_menus
                    company.save(update_fields=['allowed_menus', 'updated_at'])

        from apps.notifications.models import Notification
        if req_obj.requested_by:
            Notification.objects.create(
                user=req_obj.requested_by,
                company=req_obj.company,
                title=f"Feature Request {new_status.title()}: {req_obj.feature_name}",
                message=f"Your request for '{req_obj.feature_name}' was {new_status.lower()}." + (f" Note: {review_note}" if review_note else ""),
                notification_type='SYSTEM',
                entity_type='feature_request',
                entity_id=str(req_obj.id),
            )

        return Response(FeatureRequestSerializer(req_obj).data)

