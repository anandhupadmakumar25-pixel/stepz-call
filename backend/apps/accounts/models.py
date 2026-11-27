import uuid
from django.db import models
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin, BaseUserManager
from apps.core.models import TimeStampedModel, TenantModel

class UserManager(BaseUserManager):
    def create_user(self, email, password=None, username=None, **extra_fields):
        if not email:
            raise ValueError('Email address is mandatory')
        email = self.normalize_email(email)
        if username and str(username).strip():
            extra_fields['username'] = str(username).strip()
        user = self.model(email=email, **extra_fields)
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('role', 'SUPER_ADMIN')
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_active', True)

        if extra_fields.get('is_staff') is not True:
            raise ValueError('Superuser must have is_staff=True.')
        if extra_fields.get('is_superuser') is not True:
            raise ValueError('Superuser must have is_superuser=True.')

        return self.create_user(email, password, **extra_fields)

class User(AbstractBaseUser, PermissionsMixin, TimeStampedModel):
    ROLE_CHOICES = [
        ('MASTER_ADMIN', 'Master Admin (Super-Super Admin)'),
        ('SUPER_ADMIN', 'Super Admin'),
        ('COMPANY_ADMIN', 'Company Admin'),
        ('MANAGER', 'Manager'),
        ('EMPLOYEE', 'Employee / Telecaller'),
    ]

    email = models.EmailField(unique=True, db_index=True)
    username = models.CharField(max_length=150, unique=True, null=True, blank=True, db_index=True)
    first_name = models.CharField(max_length=150)
    last_name = models.CharField(max_length=150, blank=True)
    phone = models.CharField(max_length=32, blank=True)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='EMPLOYEE', db_index=True)
    company = models.ForeignKey(
        'companies.Company',
        null=True,
        blank=True,
        on_delete=models.CASCADE,
        related_name='users',
        db_index=True
    )
    branch = models.ForeignKey(
        'leads.Branch',
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='employees',
        db_index=True
    )
    custom_roles = models.ManyToManyField(
        'CustomRole',
        blank=True,
        related_name='assigned_users'
    )
    is_active = models.BooleanField(default=True, db_index=True)
    is_staff = models.BooleanField(default=False)

    objects = UserManager()

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['first_name']

    class Meta:
        ordering = ['-created_at']

    def save(self, *args, **kwargs):
        if self.username:
            self.username = self.username.strip()
            if not self.username:
                self.username = None
        else:
            self.username = None
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.email} ({self.get_role_display()})"

    @property
    def full_name(self):
        return f"{self.first_name} {self.last_name}".strip() or self.email

    def get_full_name(self):
        return self.full_name

    @property
    def is_master_admin(self):
        return self.role == 'MASTER_ADMIN'

    @property
    def is_super_admin(self):
        return self.role in ['MASTER_ADMIN', 'SUPER_ADMIN']

    @property
    def is_company_admin(self):
        return self.role in ['MASTER_ADMIN', 'SUPER_ADMIN', 'COMPANY_ADMIN']

    @property
    def is_manager(self):
        return self.role in ['MASTER_ADMIN', 'SUPER_ADMIN', 'COMPANY_ADMIN', 'MANAGER']

    def _perm_matches(self, granted_list, perm_key: str) -> bool:
        if not granted_list:
            return False
        if '*' in granted_list or perm_key in granted_list:
            return True
        module = perm_key.split('.')[0] if '.' in perm_key else perm_key
        return f"{module}.*" in granted_list

    def get_active_delegations(self):
        from django.utils import timezone
        if not self.company_id or not self.is_active:
            return SectionDelegation.objects.none()
        today = timezone.localdate()
        return self.received_delegations.filter(
            company_id=self.company_id,
            is_active=True,
            start_date__lte=today,
            end_date__gte=today,
        ).select_related('delegator')

    def has_permission(self, perm_key: str) -> bool:
        """
        Tamper-proof permission evaluation:
        1. Inactive users are denied.
        2. Super Admin has all permissions.
        3. Suspended / expired tenant companies are denied.
        4. Module check: If the tenant company does not have the module activated
           in their plan/allowed_menus, action is automatically denied.
        5. Company Admin has all permissions for enabled modules.
        6. Staff / Employees aggregate composite permissions across active CustomRoles
           AND active time-bound SectionDelegations ("Acting In-Charge").
        """
        from apps.accounts.permissions_catalog import (
            get_menu_key_for_permission,
            DEFAULT_MANAGER_PERMISSIONS,
            DEFAULT_EMPLOYEE_PERMISSIONS,
        )

        if not self.is_active:
            return False

        if self.is_super_admin:
            return True

        company = self.company
        if not company or company.status == 'SUSPENDED' or company.is_plan_expired:
            return False

        mapped_menu = get_menu_key_for_permission(perm_key)
        if not company.has_menu_permission(mapped_menu):
            return False

        if self.role == 'COMPANY_ADMIN':
            return True

        # Check active CustomRoles
        active_roles = list(self.custom_roles.filter(is_active=True))
        for r in active_roles:
            if self._perm_matches(r.permissions or [], perm_key):
                return True

        # Check active SectionDelegations (e.g. Acting In-Charge while Admin is on leave)
        for d in self.get_active_delegations():
            if self._perm_matches(d.permissions or [], perm_key):
                return True

        # Baseline fallback ONLY if no CustomRole is assigned yet
        if not active_roles:
            if self.role == 'MANAGER' and perm_key in DEFAULT_MANAGER_PERMISSIONS:
                return True
            if self.role == 'EMPLOYEE' and perm_key in DEFAULT_EMPLOYEE_PERMISSIONS:
                return True

        return False

    @property
    def resolved_permissions(self):
        """
        Returns list of all active permission keys granted to this user
        (from CustomRoles + active SectionDelegations, filtered by company plan).
        """
        from apps.accounts.permissions_catalog import (
            get_menu_key_for_permission,
            DEFAULT_MANAGER_PERMISSIONS,
            DEFAULT_EMPLOYEE_PERMISSIONS,
        )

        if not self.is_active:
            return []
        if self.is_super_admin or self.role == 'COMPANY_ADMIN':
            return ['*']
        if not self.company or self.company.status == 'SUSPENDED' or self.company.is_plan_expired:
            return []

        perms = set()
        active_roles = list(self.custom_roles.filter(is_active=True))
        for r in active_roles:
            for p in (r.permissions or []):
                if p == '*' or self.company.has_menu_permission(get_menu_key_for_permission(p)):
                    perms.add(p)

        for d in self.get_active_delegations():
            for p in (d.permissions or []):
                if p == '*' or self.company.has_menu_permission(get_menu_key_for_permission(p)):
                    perms.add(p)

        if not active_roles:
            baseline = DEFAULT_MANAGER_PERMISSIONS if self.role == 'MANAGER' else (
                DEFAULT_EMPLOYEE_PERMISSIONS if self.role == 'EMPLOYEE' else set()
            )
            for p in baseline:
                if self.company.has_menu_permission(get_menu_key_for_permission(p)):
                    perms.add(p)

        return sorted(perms)

    def is_checkin_required(self):
        if self.is_super_admin or self.role == 'COMPANY_ADMIN' or not self.company:
            return False
        prof = getattr(self, 'employee_profile', None)
        override = getattr(prof, 'require_checkin_override', 'INHERIT') if prof else 'INHERIT'
        if override == 'EXEMPT':
            return False
        if override == 'REQUIRED':
            return True
        policy = getattr(self.company, 'payroll_policy', None)
        return bool(policy and getattr(policy, 'require_checkin_for_menu_access', False))

    def has_active_checkin_today(self):
        from django.utils import timezone
        today = timezone.localdate()
        return self.attendance_records.filter(
            date=today,
            check_in_time__isnull=False,
            check_out_time__isnull=True,
        ).exists()

class CustomRole(TenantModel):
    name = models.CharField(max_length=128)
    code = models.CharField(max_length=64, blank=True)
    description = models.TextField(blank=True)
    permissions = models.JSONField(default=list, blank=True)
    is_system_default = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['name']
        unique_together = ('company', 'name')

    def __str__(self):
        return f"{self.name} ({self.company.name if self.company else 'Global'})"

    @classmethod
    def ensure_default_roles(cls, company):
        """
        Ensures the 3 standard seed roles exist for this company.
        """
        defaults = [
            {
                'name': 'Telecaller',
                'code': 'TELECALLER',
                'description': 'Handles outbound calling, dials leads, logs outcomes, and schedules callbacks.',
                'permissions': [
                    'leads.view_assigned',
                    'leads.edit',
                    'tasks.view_assigned',
                    'tasks.execute',
                    'calls.view_history',
                    'calls.view_recordings',
                    'attendance.punch',
                ],
            },
            {
                'name': 'Field Sales Rep',
                'code': 'FIELD_SALES',
                'description': 'Roams on-field, creates client leads, checks in via dynamic GPS, and logs field visits.',
                'permissions': [
                    'leads.view_assigned',
                    'leads.create',
                    'leads.edit',
                    'tasks.view_assigned',
                    'tasks.execute',
                    'attendance.punch',
                    'attendance.field_visit',
                ],
            },
            {
                'name': 'Team Lead / Supervisor',
                'code': 'TEAM_LEAD',
                'description': 'Supervises telecaller and field reps, assigns leads and tasks, and monitors live team attendance.',
                'permissions': [
                    'leads.view_all',
                    'leads.create',
                    'leads.edit',
                    'leads.assign',
                    'tasks.view_all',
                    'tasks.create',
                    'tasks.manage',
                    'calls.view_history',
                    'calls.view_recordings',
                    'attendance.punch',
                    'attendance.field_visit',
                    'attendance.view_team_board',
                    'staff.view',
                    'analytics.view',
                ],
            },
        ]

        roles = []
        for d in defaults:
            role, _ = cls.objects.get_or_create(
                company=company,
                name=d['name'],
                defaults={
                    'code': d['code'],
                    'description': d['description'],
                    'permissions': d['permissions'],
                    'is_system_default': True,
                }
            )
            roles.append(role)
        return roles

class Team(TimeStampedModel):
    company = models.ForeignKey(
        'companies.Company',
        on_delete=models.CASCADE,
        related_name='teams',
        db_index=True
    )
    name = models.CharField(max_length=128)
    manager = models.ForeignKey(
        User,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='managed_teams'
    )
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        unique_together = ('company', 'name')
        ordering = ['name']

    def __str__(self):
        return f"{self.name} - {self.company.name}"

class Department(TenantModel):
    ATTENDANCE_MODE_CHOICES = [
        ('GEOFENCE', 'Fixed Office Geo-fence'),
        ('FIELD_STAFF', 'Field Staff (Location & Places Tracking)'),
    ]

    name = models.CharField(max_length=128)
    code = models.CharField(max_length=64, blank=True)
    description = models.TextField(blank=True)
    attendance_mode = models.CharField(
        max_length=20,
        choices=ATTENDANCE_MODE_CHOICES,
        default='GEOFENCE'
    )
    allowed_branches = models.ManyToManyField(
        'leads.Branch',
        blank=True,
        related_name='departments'
    )
    manager = models.ForeignKey(
        User,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='managed_departments'
    )
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['name']
        constraints = [
            models.UniqueConstraint(
                fields=['company', 'name'],
                name='unique_company_department_name'
            )
        ]

    def __str__(self):
        return f"{self.name} ({self.get_attendance_mode_display()})"

class EmployeeProfile(TimeStampedModel):
    STATUS_CHOICES = [
        ('ACTIVE', 'Active'),
        ('ON_LEAVE', 'On Leave'),
        ('INACTIVE', 'Inactive'),
    ]

    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='employee_profile'
    )
    department = models.ForeignKey(
        Department,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='members'
    )
    allowed_branches = models.ManyToManyField(
        'leads.Branch',
        blank=True,
        related_name='employee_branch_overrides'
    )
    team = models.ForeignKey(
        Team,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='members'
    )
    manager = models.ForeignKey(
        User,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='managed_employees'
    )
    employee_code = models.CharField(max_length=64, blank=True)
    daily_call_target = models.PositiveIntegerField(default=50)
    is_geofence_required = models.BooleanField(default=True)
    shift_start_time = models.TimeField(null=True, blank=True, default='09:00:00')
    shift_end_time = models.TimeField(null=True, blank=True, default='18:00:00')
    grace_period_minutes = models.PositiveIntegerField(default=15)
    joining_date = models.DateField(null=True, blank=True)
    require_checkin_override = models.CharField(
        max_length=20,
        choices=[
            ('INHERIT', 'Inherit Company Policy'),
            ('REQUIRED', 'Always Require Check-In'),
            ('EXEMPT', 'Exempt from Check-In'),
        ],
        default='INHERIT',
    )
    require_quotation_approval = models.BooleanField(default=False)
    quotation_approver = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='quotation_approval_assignees',
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='ACTIVE', db_index=True)

    def __str__(self):
        return f"Profile: {self.user.full_name} ({self.status})"

class AttendanceRecord(TenantModel):
    STATUS_CHOICES = [
        ('PRESENT', 'Present'),
        ('LATE', 'Late'),
        ('HALF_DAY', 'Half Day'),
        ('OUT_OF_FENCE', 'Out of Fence'),
        ('ABSENT', 'Absent'),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='attendance_records',
        db_index=True
    )
    department = models.ForeignKey(
        Department,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='attendance_records'
    )
    matched_branch = models.ForeignKey(
        'leads.Branch',
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='attendance_records'
    )
    date = models.DateField(db_index=True)
    tracking_mode = models.CharField(max_length=20, default='GEOFENCE')

    # Check-in
    check_in_time = models.DateTimeField(null=True, blank=True)
    check_in_lat = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    check_in_lng = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    check_in_address = models.CharField(max_length=255, blank=True)
    check_in_distance_meters = models.FloatField(null=True, blank=True)
    check_in_in_geofence = models.BooleanField(default=False)

    # Check-out
    check_out_time = models.DateTimeField(null=True, blank=True)
    check_out_lat = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    check_out_lng = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    check_out_address = models.CharField(max_length=255, blank=True)
    check_out_distance_meters = models.FloatField(null=True, blank=True)
    check_out_in_geofence = models.BooleanField(default=False)

    working_hours = models.DecimalField(max_digits=5, decimal_places=2, default=0.0)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PRESENT')
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-date', '-check_in_time']

    def __str__(self):
        return f"{self.user.full_name} - {self.date} ({self.status})"

class FieldVisit(TenantModel):
    attendance = models.ForeignKey(
        AttendanceRecord,
        on_delete=models.CASCADE,
        related_name='field_visits'
    )
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='field_visits'
    )
    place_name = models.CharField(max_length=255)
    latitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    longitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    address = models.CharField(max_length=255, blank=True)
    visited_at = models.DateTimeField()
    remarks = models.TextField(blank=True)

    class Meta:
        ordering = ['visited_at']

    def __str__(self):
        return f"{self.user.full_name} visited {self.place_name} at {self.visited_at}"

class Invitation(TimeStampedModel):
    company = models.ForeignKey(
        'companies.Company',
        on_delete=models.CASCADE,
        related_name='invitations'
    )
    email = models.EmailField()
    role = models.CharField(max_length=20, choices=User.ROLE_CHOICES, default='EMPLOYEE')
    team = models.ForeignKey(
        Team,
        null=True,
        blank=True,
        on_delete=models.SET_NULL
    )
    token = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    invited_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        related_name='sent_invitations'
    )
    is_accepted = models.BooleanField(default=False)
    expires_at = models.DateTimeField()

    def __str__(self):
        return f"Invite for {self.email} to {self.company.name} as {self.role}"


class SectionDelegation(TenantModel):
    """
    Time-bound delegation ("Acting In-Charge") allowing a Company Admin or Manager
    to temporarily assign specific sections and permissions to another employee
    while on leave, with automatic start/expiry and full auditability.
    """
    delegator = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='granted_delegations'
    )
    delegatee = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='received_delegations'
    )
    title = models.CharField(max_length=160, blank=True, help_text="e.g. Acting Billing & Leave In-Charge")
    sections = models.JSONField(default=list, blank=True, help_text="Module keys delegated e.g. ['quotations', 'billing']")
    permissions = models.JSONField(default=list, blank=True, help_text="Exact granular permission keys granted")
    start_date = models.DateField(db_index=True)
    end_date = models.DateField(db_index=True)
    reason = models.TextField(blank=True)
    is_active = models.BooleanField(default=True, db_index=True)
    revoked_at = models.DateTimeField(null=True, blank=True)
    revoked_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='revoked_delegations'
    )

    class Meta:
        ordering = ['-start_date', '-created_at']

    @property
    def is_currently_effective(self):
        from django.utils import timezone
        if not self.is_active:
            return False
        today = timezone.localdate()
        return self.start_date <= today <= self.end_date

    def __str__(self):
        return f"{self.delegator.full_name} -> {self.delegatee.full_name} ({self.start_date} to {self.end_date})"


class PermissionAuditLog(TenantModel):
    """
    Immutable security audit trail for role edits, section delegations,
    and actions executed under delegated authority.
    """
    actor = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        related_name='permission_audit_actions'
    )
    on_behalf_of = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='delegated_audit_actions'
    )
    action = models.CharField(max_length=100, db_index=True)
    target_model = models.CharField(max_length=80, blank=True)
    target_id = models.CharField(max_length=80, blank=True)
    details = models.JSONField(default=dict, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"[{self.action}] by {self.actor_id} at {self.created_at}"


class CompanyHoliday(TenantModel):
    name = models.CharField(max_length=120)
    date = models.DateField(db_index=True)
    is_optional = models.BooleanField(default=False)
    description = models.TextField(blank=True)

    class Meta:
        ordering = ['date']
        unique_together = ('company', 'date', 'name')

    def __str__(self):
        return f"{self.name} ({self.date})"


class LeaveType(TenantModel):
    name = models.CharField(max_length=80)
    code = models.CharField(max_length=20)
    annual_quota = models.DecimalField(max_digits=5, decimal_places=1, default=12.0)
    is_paid = models.BooleanField(default=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['name']
        unique_together = ('company', 'code')

    def __str__(self):
        return f"{self.name} ({self.code})"


class LeaveBalance(TenantModel):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='leave_balances')
    leave_type = models.ForeignKey(LeaveType, on_delete=models.CASCADE, related_name='balances')
    year = models.PositiveIntegerField(db_index=True)
    allocated = models.DecimalField(max_digits=5, decimal_places=1, default=0.0)
    used = models.DecimalField(max_digits=5, decimal_places=1, default=0.0)

    class Meta:
        unique_together = ('user', 'leave_type', 'year')

    @property
    def remaining(self):
        return max(0.0, float(self.allocated) - float(self.used))


class LeaveRequest(TenantModel):
    STATUS_CHOICES = [
        ('PENDING', 'Pending Approval'),
        ('APPROVED', 'Approved'),
        ('REJECTED', 'Rejected'),
        ('CANCELLED', 'Cancelled'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='leave_requests')
    leave_type = models.ForeignKey(LeaveType, on_delete=models.CASCADE, related_name='requests')
    start_date = models.DateField(db_index=True)
    end_date = models.DateField(db_index=True)
    is_half_day = models.BooleanField(default=False)
    days_count = models.DecimalField(max_digits=5, decimal_places=1, default=1.0)
    reason = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING', db_index=True)
    reviewed_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='reviewed_leaves')
    reviewed_at = models.DateTimeField(null=True, blank=True)
    review_notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-created_at']


class AttendanceRegularization(TenantModel):
    STATUS_CHOICES = [
        ('PENDING', 'Pending'),
        ('APPROVED', 'Approved'),
        ('REJECTED', 'Rejected'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='regularization_requests')
    date = models.DateField(db_index=True)
    requested_check_in = models.TimeField()
    requested_check_out = models.TimeField(null=True, blank=True)
    reason = models.TextField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING', db_index=True)
    reviewed_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='reviewed_regularizations')
    reviewed_at = models.DateTimeField(null=True, blank=True)
    review_notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-date', '-created_at']


class EmployeeSalaryStructure(TenantModel):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='salary_structure')
    currency = models.CharField(max_length=10, default='INR')
    basic_salary = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    hra = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    allowances = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    pf_deduction = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    esi_deduction = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    tax_deduction = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    bank_name = models.CharField(max_length=120, blank=True)
    account_number = models.CharField(max_length=64, blank=True)
    ifsc_iban = models.CharField(max_length=64, blank=True)

    @property
    def gross_salary(self):
        return float(self.basic_salary) + float(self.hra) + float(self.allowances)

    @property
    def total_fixed_deductions(self):
        return float(self.pf_deduction) + float(self.esi_deduction) + float(self.tax_deduction)


class PayrollRun(TenantModel):
    STATUS_CHOICES = [
        ('DRAFT', 'Draft'),
        ('FINALIZED', 'Finalized / Locked'),
        ('PAID', 'Paid'),
    ]

    month = models.PositiveIntegerField()
    year = models.PositiveIntegerField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='DRAFT', db_index=True)
    generated_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='generated_payroll_runs')
    finalized_at = models.DateTimeField(null=True, blank=True)
    total_gross = models.DecimalField(max_digits=14, decimal_places=2, default=0.00)
    total_deductions = models.DecimalField(max_digits=14, decimal_places=2, default=0.00)
    total_net_pay = models.DecimalField(max_digits=14, decimal_places=2, default=0.00)

    class Meta:
        ordering = ['-year', '-month']
        unique_together = ('company', 'month', 'year')


class Payslip(TenantModel):
    payroll_run = models.ForeignKey(PayrollRun, on_delete=models.CASCADE, related_name='payslips')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='payslips')
    month = models.PositiveIntegerField()
    year = models.PositiveIntegerField()
    currency = models.CharField(max_length=10, default='INR')

    working_days = models.PositiveIntegerField(default=26)
    present_days = models.DecimalField(max_digits=5, decimal_places=1, default=0.0)
    paid_leave_days = models.DecimalField(max_digits=5, decimal_places=1, default=0.0)
    lop_days = models.DecimalField(max_digits=5, decimal_places=1, default=0.0)
    late_days = models.PositiveIntegerField(default=0)
    overtime_hours = models.DecimalField(max_digits=6, decimal_places=2, default=0.00)

    basic_salary = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    hra = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    allowances = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    overtime_pay = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    bonus = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    gross_earnings = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)

    lop_deduction = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    late_deduction = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    statutory_deductions = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    other_deductions = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    net_pay = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)

    status = models.CharField(max_length=20, default='DRAFT')
    payment_reference = models.CharField(max_length=100, blank=True)

    class Meta:
        ordering = ['-year', '-month', 'user__first_name']
        unique_together = ('payroll_run', 'user')

