import uuid
from django.db import models
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin, BaseUserManager
from apps.core.models import TimeStampedModel, TenantModel

class UserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('Email address is mandatory')
        email = self.normalize_email(email)
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

    def __str__(self):
        return f"{self.email} ({self.get_role_display()})"

    @property
    def full_name(self):
        return f"{self.first_name} {self.last_name}".strip() or self.email

    @property
    def is_master_admin(self):
        return self.role == 'MASTER_ADMIN' or (self.role == 'SUPER_ADMIN' and self.is_superuser)

    @property
    def is_super_admin(self):
        return self.role in ['MASTER_ADMIN', 'SUPER_ADMIN']

    @property
    def is_company_admin(self):
        return self.role in ['MASTER_ADMIN', 'SUPER_ADMIN', 'COMPANY_ADMIN']

    @property
    def is_manager(self):
        return self.role in ['MASTER_ADMIN', 'SUPER_ADMIN', 'COMPANY_ADMIN', 'MANAGER']

    def has_permission(self, perm_key: str) -> bool:
        """
        Tamper-proof permission evaluation:
        1. Super Admin has all permissions.
        2. Module check: If the tenant company does not have the module activated
           in their plan/allowed_menus, action is automatically denied.
        3. Company Admin has all permissions for enabled modules.
        4. Staff / Employees aggregate composite permissions across all their active CustomRoles.
        """
        if self.is_super_admin:
            return True

        company = self.company
        if not company:
            return False

        # Module check (e.g. 'leads.export' -> module is 'leads')
        module = perm_key.split('.')[0] if '.' in perm_key else perm_key
        # Map internal permission prefixes to company menu keys if needed
        module_map = {
            'staff': 'employees',
            'roles': 'employees',
            'calls': 'call_history',
        }
        mapped_menu = module_map.get(module, module)
        if not company.has_menu_permission(mapped_menu):
            return False

        if self.role == 'COMPANY_ADMIN':
            return True

        # Check composite custom roles
        for r in self.custom_roles.filter(is_active=True):
            if perm_key in (r.permissions or []):
                return True

        # Legacy fallback if no custom roles assigned yet
        if self.role == 'MANAGER':
            return True

        return False

    @property
    def resolved_permissions(self):
        """
        Returns list of all active permission keys granted to this user.
        """
        if self.is_super_admin or self.role == 'COMPANY_ADMIN':
            return ['*']
        if not self.company:
            return []

        module_map = {
            'staff': 'employees',
            'roles': 'employees',
            'calls': 'call_history',
        }

        perms = set()
        for r in self.custom_roles.filter(is_active=True):
            for p in (r.permissions or []):
                mod = p.split('.')[0] if '.' in p else p
                mapped_menu = module_map.get(mod, mod)
                if self.company.has_menu_permission(mapped_menu):
                    perms.add(p)
        return list(perms)

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
        constraints = [
            models.UniqueConstraint(
                fields=['user', 'date'],
                name='unique_user_daily_attendance'
            )
        ]

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
