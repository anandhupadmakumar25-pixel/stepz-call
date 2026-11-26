from django.db import models
from django.utils import timezone
from apps.core.models import TimeStampedModel, TenantModel

LEGACY_MENU_KEYS = [
    'branches',
    'employees',
    'attendance',
    'leads',
    'tasks',
    'recordings',
    'callbacks',
    'call_history',
    'analytics',
]

V2_EXTENSION_PARENT_MAP = {
    'leave': 'attendance',
    'payroll': 'employees',
    'delegation': 'employees',
    'quotations': 'leads',
    'billing': 'leads',
    'templates': 'leads',
    'reports': 'analytics',
}

ALL_MENU_KEYS = [
    'branches',
    'employees',
    'attendance',
    'leave',
    'payroll',
    'delegation',
    'leads',
    'tasks',
    'recordings',
    'callbacks',
    'call_history',
    'quotations',
    'billing',
    'templates',
    'reports',
    'analytics',
]

class Plan(TimeStampedModel):
    CURRENCY_CHOICES = [
        ('INR', 'INR (₹)'),
        ('USD', 'USD ($)'),
        ('EUR', 'EUR (€)'),
        ('GBP', 'GBP (£)'),
        ('AED', 'AED (د.إ)'),
        ('QAR', 'QAR (QR)'),
    ]

    name = models.CharField(max_length=100)
    code = models.CharField(max_length=50, unique=True)
    currency = models.CharField(max_length=10, choices=CURRENCY_CHOICES, default='INR')
    price_monthly = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    price_yearly = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    max_users = models.PositiveIntegerField(default=5)
    max_leads = models.PositiveIntegerField(default=5000)
    allowed_menus = models.JSONField(default=list, blank=True)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['price_monthly']

    @property
    def currency_symbol(self):
        symbols = {
            'INR': '₹',
            'USD': '$',
            'EUR': '€',
            'GBP': '£',
            'AED': 'د.إ',
            'QAR': 'QR',
        }
        return symbols.get(self.currency, '₹')

    def __str__(self):
        return f"{self.name} ({self.currency_symbol}{self.price_monthly}/mo)"

class Company(TimeStampedModel):
    STATUS_CHOICES = [
        ('ACTIVE', 'Active'),
        ('SUSPENDED', 'Suspended'),
        ('TRIAL', 'Trial'),
    ]

    PLAN_BILLING_CYCLE_CHOICES = [
        ('MONTHLY', 'Monthly'),
        ('QUARTERLY', 'Quarterly'),
        ('YEARLY', 'Yearly'),
        ('CUSTOM', 'Custom'),
    ]

    name = models.CharField(max_length=255)
    subdomain = models.CharField(max_length=100, unique=True, null=True, blank=True)
    contact_email = models.EmailField()
    contact_phone = models.CharField(max_length=32, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='ACTIVE', db_index=True)
    default_country_code = models.CharField(max_length=4, default='+91')
    default_country_iso = models.CharField(max_length=2, default='IN')
    logo = models.TextField(blank=True, default='')
    address = models.TextField(blank=True, default='')
    gstin = models.CharField(max_length=50, blank=True, default='')
    website = models.CharField(max_length=255, blank=True, default='')
    plan = models.ForeignKey(Plan, on_delete=models.SET_NULL, null=True, blank=True, related_name='companies')
    plan_billing_cycle = models.CharField(max_length=20, choices=PLAN_BILLING_CYCLE_CHOICES, default='MONTHLY')
    plan_starts_at = models.DateTimeField(null=True, blank=True)
    plan_expires_at = models.DateTimeField(null=True, blank=True, db_index=True)
    grace_period_days = models.PositiveIntegerField(default=0)
    created_by = models.ForeignKey(
        'accounts.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='onboarded_companies',
        help_text="Super Admin who onboarded this company"
    )
    assigned_super_admin = models.ForeignKey(
        'accounts.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='managed_companies',
        help_text="Super Admin actively managing this company"
    )
    allowed_menus = models.JSONField(default=list, blank=True)
    settings = models.JSONField(default=dict, blank=True)

    class Meta:
        verbose_name_plural = 'Companies'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.name} ({self.status})"

    @property
    def logo_url(self):
        return self.logo

    @property
    def currency(self):
        """
        Auto-resolves the primary operational currency based on country code/ISO,
        plan currency, or falls back to INR (India default).
        """
        iso = (self.default_country_iso or '').upper().strip()
        code = (self.default_country_code or '').strip()
        if iso == 'IN' or code == '+91' or code == '91':
            return 'INR'
        if iso == 'QA' or code == '+974' or code == '974':
            return 'QAR'
        if iso == 'AE' or code == '+971' or code == '971':
            return 'AED'
        if iso == 'SA' or code == '+966' or code == '966':
            return 'SAR'
        if iso == 'OM' or code == '+968' or code == '968':
            return 'OMR'
        if iso == 'KW' or code == '+965' or code == '965':
            return 'KWD'
        if iso == 'BH' or code == '+973' or code == '973':
            return 'BHD'
        if iso in ('US', 'USA') or code == '+1' or code == '1':
            return 'USD'
        if iso in ('GB', 'UK') or code == '+44' or code == '44':
            return 'GBP'
        if self.plan and self.plan.currency:
            return self.plan.currency
        return 'INR'

    @property
    def currency_symbol(self):
        symbols = {
            'INR': '₹',
            'QAR': 'QAR',
            'AED': 'AED',
            'SAR': 'SAR',
            'OMR': 'OMR',
            'KWD': 'KWD',
            'BHD': 'BHD',
            'USD': '$',
            'EUR': '€',
            'GBP': '£',
        }
        return symbols.get(self.currency, '₹')

    @property
    def is_plan_expired(self):
        if not self.plan_expires_at:
            return False
        from django.utils import timezone
        from datetime import timedelta
        cutoff = self.plan_expires_at + timedelta(days=self.grace_period_days)
        return timezone.now() > cutoff

    @property
    def days_until_expiry(self):
        if not self.plan_expires_at:
            return None
        from django.utils import timezone
        delta = self.plan_expires_at - timezone.now()
        # Returns whole days remaining (can be negative if expired)
        return delta.days

    def check_and_update_status(self):
        """
        Auto-suspend the company if its plan has passed the expiry cutoff date,
        and ensure an open renewal DUE entry exists for the expired cycle.
        """
        if not self.is_plan_expired:
            return False

        changed = False
        if self.status != 'SUSPENDED':
            self.status = 'SUSPENDED'
            self.save(update_fields=['status'])
            changed = True

        if self.plan and not self.subscription_history.filter(due_amount__gt=0).exists():
            due_amt = (
                self.plan.price_yearly
                if self.plan_billing_cycle == 'YEARLY'
                else self.plan.price_monthly
            )
            if float(due_amt or 0) > 0:
                CompanySubscriptionHistory.objects.create(
                    company=self,
                    plan_name=self.plan.name,
                    billing_cycle=self.plan_billing_cycle
                    if self.plan_billing_cycle in ['MONTHLY', 'YEARLY', 'DAYS', 'CUSTOM_DATE']
                    else 'MONTHLY',
                    extension_days=0,
                    previous_expiry=self.plan_expires_at,
                    new_expiry=self.plan_expires_at or timezone.now(),
                    amount_paid=0.00,
                    due_amount=due_amt,
                    currency=self.plan.currency,
                    payment_status='DUE',
                    payment_mode='DUE',
                    notes='Auto-generated renewal due after plan duration expired',
                )
        return changed

    def get_allowed_menus(self):
        if self.allowed_menus and len(self.allowed_menus) > 0:
            return self.allowed_menus
        if self.plan and self.plan.allowed_menus:
            return self.plan.allowed_menus
        # Default fallback for initial seed
        return ALL_MENU_KEYS

    def can_manage_branches(self):
        return 'branches' in self.get_allowed_menus()

    def can_manage_employees(self):
        return 'employees' in self.get_allowed_menus()

    def has_menu_permission(self, menu_key):
        menus = self.get_allowed_menus()
        if menu_key in menus:
            return True
        # Backward compatibility: if the company/plan only lists legacy keys,
        # auto-enable v2 extension modules when their parent module is enabled.
        has_v2_keys = any(k in menus for k in V2_EXTENSION_PARENT_MAP.keys())
        if not has_v2_keys and menu_key in V2_EXTENSION_PARENT_MAP:
            return V2_EXTENSION_PARENT_MAP[menu_key] in menus
        return False

    def can_access_recordings(self):
        return 'recordings' in self.get_allowed_menus()


class CompanyPayrollPolicy(TimeStampedModel):
    company = models.OneToOneField(
        Company,
        on_delete=models.CASCADE,
        related_name='payroll_policy'
    )
    shift_start_time = models.TimeField(default='09:30:00')
    shift_end_time = models.TimeField(default='18:30:00')
    grace_period_minutes = models.PositiveIntegerField(default=15)
    
    full_day_hours = models.DecimalField(max_digits=4, decimal_places=1, default=8.0)
    half_day_hours = models.DecimalField(max_digits=4, decimal_places=1, default=4.5)
    
    allow_out_of_fence_punch = models.BooleanField(default=True)
    strict_geofence_block = models.BooleanField(default=False)
    
    salary_cycle_start_day = models.PositiveIntegerField(default=1)
    pay_calculation_basis = models.CharField(
        max_length=20,
        choices=[
            ('CALENDAR_DAYS', 'Calendar Days (30/31)'),
            ('FIXED_26_DAYS', 'Fixed 26 Working Days')
        ],
        default='CALENDAR_DAYS'
    )
    overtime_enabled = models.BooleanField(default=False)
    overtime_min_minutes = models.PositiveIntegerField(default=60)
    overtime_hourly_multiplier = models.DecimalField(max_digits=4, decimal_places=2, default=1.0)
    
    custom_profile_fields = models.JSONField(default=list, blank=True)

    class Meta:
        verbose_name = 'Company Payroll Policy'
        verbose_name_plural = 'Company Payroll Policies'

    def __str__(self):
        return f"{self.company.name} Payroll Policy"


class CompanyCustomRule(TenantModel):
    RULE_CATEGORY_CHOICES = [
        ('LATE_ARRIVAL', 'Late Coming & Punctuality'),
        ('WORKING_HOURS', 'Working Hours & Half-Day'),
        ('GEOFENCE', 'Geofence & Absence'),
        ('OVERTIME', 'Overtime & Allowances'),
        ('DEDUCTION', 'Custom Penalties & Deductions'),
    ]

    ACTION_TYPE_CHOICES = [
        ('LOP_DAYS', 'Loss of Pay (LOP) Days'),
        ('FLAT_AMOUNT', 'Flat Currency Deduction'),
        ('PERCENTAGE', 'Percentage Deduction (%)'),
        ('BONUS_AMOUNT', 'Addition / Bonus (+ Amount)'),
        ('WARNING', 'Automated Supervisor Warning'),
    ]

    name = models.CharField(max_length=150)
    category = models.CharField(max_length=30, choices=RULE_CATEGORY_CHOICES, default='LATE_ARRIVAL')
    description = models.TextField(blank=True)

    trigger_metric = models.CharField(max_length=50, default='LATE_COUNT')
    operator = models.CharField(max_length=20, default='EVERY_N')
    threshold_value = models.DecimalField(max_digits=8, decimal_places=2, default=3.0)
    free_allowance_count = models.PositiveIntegerField(default=0)

    action_type = models.CharField(max_length=30, choices=ACTION_TYPE_CHOICES, default='LOP_DAYS')
    action_value = models.DecimalField(max_digits=8, decimal_places=2, default=0.5)

    applicable_department_ids = models.JSONField(default=list, blank=True)
    is_active = models.BooleanField(default=True)
    order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['order', 'created_at']

    def __str__(self):
        return f"{self.name} ({self.company.name})"


class CompanyRenewalRequest(TimeStampedModel):
    CYCLE_CHOICES = [
        ('MONTHLY', 'Monthly (30 Days)'),
        ('YEARLY', 'Yearly (365 Days)'),
        ('DAYS', 'Custom Days'),
        ('CUSTOM_DATE', 'Custom Date Target'),
    ]

    STATUS_CHOICES = [
        ('PENDING', 'Pending Approval'),
        ('APPROVED', 'Approved'),
        ('REJECTED', 'Rejected'),
        ('CANCELLED', 'Cancelled'),
    ]

    company = models.ForeignKey(
        Company,
        on_delete=models.CASCADE,
        related_name='renewal_requests'
    )
    requested_by = models.ForeignKey(
        'accounts.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='company_renewal_requests'
    )
    assigned_super_admin = models.ForeignKey(
        'accounts.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='managed_renewal_requests',
        help_text="Super Admin responsible for reviewing this renewal request"
    )
    plan = models.ForeignKey(
        Plan,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='renewal_requests'
    )
    billing_cycle = models.CharField(
        max_length=20,
        choices=CYCLE_CHOICES,
        default='MONTHLY'
    )
    requested_days = models.PositiveIntegerField(
        default=30,
        help_text="Number of extension days requested (if cycle is DAYS or MONTHLY/YEARLY)"
    )
    requested_date = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Specific target expiry date (if cycle is CUSTOM_DATE)"
    )
    payment_reference = models.CharField(
        max_length=150,
        blank=True,
        help_text="Transaction reference / UTR / invoice note"
    )
    notes = models.TextField(blank=True, help_text="Customer remarks or renewal requirements")
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='PENDING',
        db_index=True
    )
    approved_by = models.ForeignKey(
        'accounts.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='approved_renewal_requests'
    )
    approved_at = models.DateTimeField(null=True, blank=True)
    admin_notes = models.TextField(blank=True, help_text="Notes from reviewing Super Admin")

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Renewal Request: {self.company.name} ({self.billing_cycle} - {self.status})"


class CompanySubscriptionHistory(TimeStampedModel):
    CYCLE_CHOICES = [
        ('MONTHLY', 'Monthly'),
        ('YEARLY', 'Yearly'),
        ('DAYS', 'Custom Days'),
        ('CUSTOM_DATE', 'Custom Date Target'),
    ]

    company = models.ForeignKey(
        Company,
        on_delete=models.CASCADE,
        related_name='subscription_history'
    )
    plan_name = models.CharField(max_length=150)
    billing_cycle = models.CharField(max_length=20, choices=CYCLE_CHOICES, default='MONTHLY')
    extension_days = models.PositiveIntegerField(default=0)
    previous_expiry = models.DateTimeField(null=True, blank=True)
    new_expiry = models.DateTimeField()
    amount_paid = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    due_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    currency = models.CharField(max_length=10, default='INR')
    payment_status = models.CharField(
        max_length=20,
        choices=[('PAID', 'Paid'), ('PARTIAL', 'Partial'), ('DUE', 'Due / Unpaid')],
        default='PAID',
    )
    payment_mode = models.CharField(max_length=32, default='BANK_TRANSFER')
    transaction_ref = models.CharField(max_length=120, blank=True)
    receipt_number = models.CharField(max_length=40, blank=True, db_index=True)
    approved_by = models.ForeignKey(
        'accounts.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='logged_subscription_renewals'
    )
    renewal_request = models.ForeignKey(
        CompanyRenewalRequest,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='history_logs'
    )
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-created_at']

    def save(self, *args, **kwargs):
        if not self.receipt_number and self.payment_status in ('PAID', 'PARTIAL') and float(self.amount_paid or 0) > 0:
            yr = timezone.now().year
            prefix = f'SUB-{yr}-'
            last = CompanySubscriptionHistory.objects.filter(
                receipt_number__startswith=prefix
            ).order_by('-receipt_number').first()
            seq = 1
            if last and last.receipt_number:
                try:
                    seq = int(last.receipt_number.split('-')[-1]) + 1
                except (ValueError, IndexError):
                    seq = CompanySubscriptionHistory.objects.filter(receipt_number__startswith=prefix).count() + 1
            self.receipt_number = f'{prefix}{seq:04d}'
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.company.name} renewed ({self.billing_cycle}) until {self.new_expiry.strftime('%Y-%m-%d')}"


FEATURE_CATALOG = [
    {
        'key': 'branches',
        'name': 'Multi-Branch Management',
        'category': 'Organization',
        'description': 'Create and manage multiple office branches, branch logos, geo-fencing radiuses, and multi-branch employee check-ins.',
        'highlights': ['Create unlimited branches', 'Custom branch logo & address', 'Branch-level geo-fencing & check-ins'],
    },
    {
        'key': 'employees',
        'name': 'Employee & RBAC Management',
        'category': 'Organization',
        'description': 'Manage staff accounts, custom functional roles, granular permissions, and daily call quotas.',
        'highlights': ['Staff directory & status controls', 'Custom functional roles (RBAC)', 'Daily call quota tracking'],
    },
    {
        'key': 'attendance',
        'name': 'Attendance & Geo-Fencing',
        'category': 'HR & Operations',
        'description': 'Track daily employee check-ins/check-outs with GPS geo-fencing and field visit logs.',
        'highlights': ['Fixed office geo-fence check-in', 'Field/remote tracking mode', 'Daily attendance reports'],
    },
    {
        'key': 'leave',
        'name': 'Leave Management',
        'category': 'HR & Operations',
        'description': 'Employee leave applications, approval workflows, and leave balance policies.',
        'highlights': ['Leave requests & approvals', 'Leave balance tracking', 'Holiday calendar'],
    },
    {
        'key': 'delegation',
        'name': 'Delegation & Access Handover',
        'category': 'Organization',
        'description': 'Temporarily delegate manager or admin responsibilities to another staff member.',
        'highlights': ['Time-bound delegation', 'Audit trail of delegated actions'],
    },
    {
        'key': 'leads',
        'name': 'Lead Directory & Assignment',
        'category': 'CRM & Sales',
        'description': 'Centralized lead pool, CSV import, staff assignment/reassignment, and status pipeline.',
        'highlights': ['CSV bulk lead import', 'Staff assignment & reassignment', 'Lead call history & notes'],
    },
    {
        'key': 'tasks',
        'name': 'Employee Tasks & Reporting',
        'category': 'CRM & Sales',
        'description': 'Assign general or lead-linked tasks to any employee role with due dates and completion reports.',
        'highlights': ['Role-wide task assignment', 'Due dates & priority levels', 'Employee completion reports'],
    },
    {
        'key': 'recordings',
        'name': 'Call Recordings',
        'category': 'CRM & Sales',
        'description': 'Capture, store, and playback employee-customer call recordings for quality assurance.',
        'highlights': ['Cloud recording storage', 'In-app audio playback', 'Linked to lead timeline'],
    },
    {
        'key': 'callbacks',
        'name': 'Scheduled Callbacks',
        'category': 'CRM & Sales',
        'description': 'Schedule and track customer callback reminders so no follow-up is missed.',
        'highlights': ['Callback reminders', 'Overdue callback alerts'],
    },
    {
        'key': 'call_history',
        'name': 'Call History & Logs',
        'category': 'CRM & Sales',
        'description': 'Detailed call duration, outcome, and timestamps across all company staff.',
        'highlights': ['Full call audit log', 'Filter by employee & date'],
    },
    {
        'key': 'quotations',
        'name': 'Quotations & Estimates',
        'category': 'Billing & Finance',
        'description': 'Generate branded customer quotations directly from leads with custom templates.',
        'highlights': ['Lead-linked quotations', 'PDF export & sharing', 'Status tracking'],
    },
    {
        'key': 'billing',
        'name': 'Invoices & Receipt Vouchers',
        'category': 'Billing & Finance',
        'description': 'Create GST/tax invoices, record payments, and issue receipt vouchers.',
        'highlights': ['Invoice generation', 'Payment & receipt tracking', 'Partial payment support'],
    },
    {
        'key': 'templates',
        'name': 'Document Templates',
        'category': 'Billing & Finance',
        'description': 'Design custom quotation, invoice, and receipt templates with branch logos.',
        'highlights': ['Visual template designer', 'Branch logo selection'],
    },
    {
        'key': 'reports',
        'name': 'Advanced Reports',
        'category': 'Analytics',
        'description': 'Exportable performance, conversion, and revenue reports across branches and staff.',
        'highlights': ['Branch & staff breakdown', 'Date-range exports'],
    },
    {
        'key': 'analytics',
        'name': 'Analytics Dashboard',
        'category': 'Analytics',
        'description': 'Real-time KPIs, call conversion funnels, and team productivity charts.',
        'highlights': ['Live KPI dashboard', 'Team conversion metrics'],
    },
]


class FeatureRequest(TimeStampedModel):
    REQUEST_TYPE_CHOICES = [
        ('COMPANY_FEATURE', 'Company Feature'),
        ('USER_PERMISSION', 'User Permission'),
    ]
    STATUS_CHOICES = [
        ('PENDING', 'Pending'),
        ('APPROVED', 'Approved'),
        ('REJECTED', 'Rejected'),
    ]

    company = models.ForeignKey(
        Company,
        on_delete=models.CASCADE,
        related_name='feature_requests'
    )
    requested_by = models.ForeignKey(
        'accounts.User',
        on_delete=models.CASCADE,
        related_name='submitted_feature_requests'
    )
    request_type = models.CharField(
        max_length=25,
        choices=REQUEST_TYPE_CHOICES,
        default='COMPANY_FEATURE',
        db_index=True
    )
    feature_key = models.CharField(max_length=100, db_index=True)
    feature_name = models.CharField(max_length=150)
    note = models.TextField(blank=True)
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='PENDING',
        db_index=True
    )
    reviewed_by = models.ForeignKey(
        'accounts.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='reviewed_feature_requests'
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    review_note = models.TextField(blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.company.name}: {self.feature_name} ({self.request_type} - {self.status})"

