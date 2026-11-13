from django.db import models
from apps.core.models import TimeStampedModel, TenantModel

ALL_MENU_KEYS = [
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

class Plan(TimeStampedModel):
    CURRENCY_CHOICES = [
        ('INR', 'INR (₹)'),
        ('USD', 'USD ($)'),
        ('EUR', 'EUR (€)'),
        ('GBP', 'GBP (£)'),
        ('AED', 'AED (د.إ)'),
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
        Auto-suspend the company if its plan has passed the expiry cutoff date.
        """
        if self.is_plan_expired and self.status != 'SUSPENDED':
            self.status = 'SUSPENDED'
            self.save(update_fields=['status'])
            return True
        return False

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
        return menu_key in self.get_allowed_menus()

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
