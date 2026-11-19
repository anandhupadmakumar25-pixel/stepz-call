import math
from rest_framework import generics, status, views
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model
from django.db import transaction, models
from django.utils import timezone

from apps.accounts.models import (
    Team, EmployeeProfile, Department, AttendanceRecord, FieldVisit, CustomRole,
    SectionDelegation, PermissionAuditLog,
)
from apps.accounts.permissions_catalog import (
    PERMISSION_GROUPS, ALL_PERMISSION_KEYS, get_menu_key_for_permission,
)
from apps.leads.models import Branch
from apps.accounts.serializers import (
    CustomTokenObtainPairSerializer,
    UserProfileSerializer,
    EmployeeListSerializer,
    EmployeeCreateSerializer,
    TeamSerializer,
    DepartmentSerializer,
    CustomRoleSerializer,
    AttendanceRecordSerializer,
    FieldVisitSerializer,
    ChangePasswordSerializer,
    SectionDelegationSerializer,
    PermissionAuditLogSerializer,
)
from apps.core.permissions import (
    IsCompanyAdmin, IsManager, require_permission, require_any_permission,
)


def _get_client_ip(request):
    xff = request.META.get('HTTP_X_FORWARDED_FOR')
    if xff:
        return xff.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR')


def _log_permission_audit(request, action, target_model='', target_id='', details=None, on_behalf_of=None):
    company = getattr(request.user, 'company', None)
    if not company:
        return
    PermissionAuditLog.objects.create(
        company=company,
        actor=request.user,
        on_behalf_of=on_behalf_of,
        action=action,
        target_model=target_model,
        target_id=str(target_id) if target_id else '',
        details=details or {},
        ip_address=_get_client_ip(request),
    )

User = get_user_model()

class CustomTokenObtainPairView(TokenObtainPairView):
    permission_classes = [AllowAny]
    serializer_class = CustomTokenObtainPairSerializer

class LogoutView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            refresh_token = request.data.get("refresh")
            if refresh_token:
                token = RefreshToken(refresh_token)
                token.blacklist()
            return Response({"message": "Successfully logged out."}, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

class UserProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserProfileSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user

class EmployeeListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [require_any_permission('employees.view', 'employees.create', 'employees.edit', 'delegation.manage', 'leads.assign', 'tasks.manage_team')()]
        return [require_permission('employees.create')()]

    def get(self, request):
        company = request.user.company
        if not company:
            if request.user.is_super_admin:
                employees = User.objects.filter(role__in=['COMPANY_ADMIN', 'MANAGER', 'EMPLOYEE'])
            else:
                return Response([])
        else:
            employees = User.objects.filter(company=company, role__in=['COMPANY_ADMIN', 'MANAGER', 'EMPLOYEE'])
            
            # Optional query filters
            role = request.query_params.get('role')
            if role:
                employees = employees.filter(role=role)
            branch_id = request.query_params.get('branch')
            if branch_id and branch_id != 'ALL':
                employees = employees.filter(branch_id=branch_id)
            team_id = request.query_params.get('team')
            if team_id:
                employees = employees.filter(employee_profile__team_id=team_id)
            search = request.query_params.get('search')
            if search:
                employees = employees.filter(
                    models.Q(first_name__icontains=search) |
                    models.Q(last_name__icontains=search) |
                    models.Q(email__icontains=search)
                )

        serializer = EmployeeListSerializer(employees.select_related('branch', 'employee_profile').order_by('-created_at'), many=True)
        return Response(serializer.data)

    def post(self, request):
        from apps.leads.models import Branch
        serializer = EmployeeCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        company = request.user.company
        if not company:
            return Response({"error": "Admin must be associated with a company to add employees."}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            branch = None
            if data.get('branch_id'):
                branch = Branch.objects.filter(id=data['branch_id'], company=company).first()

            user = User.objects.create_user(
                email=data['email'],
                password=data['password'],
                first_name=data['first_name'],
                last_name=data.get('last_name', ''),
                phone=data.get('phone', ''),
                role=data['role'],
                company=company,
                branch=branch,
                is_active=True
            )

            team = None
            if data.get('team_id'):
                team = Team.objects.filter(id=data['team_id'], company=company).first()

            manager = None
            if data.get('manager_id'):
                manager = User.objects.filter(id=data['manager_id'], company=company).first()

            department = None
            if data.get('department_id'):
                department = Department.objects.filter(id=data['department_id'], company=company).first()

            profile = EmployeeProfile.objects.create(
                user=user,
                team=team,
                manager=manager,
                department=department,
                employee_code=data.get('employee_code', ''),
                daily_call_target=data.get('daily_call_target', 50),
                is_geofence_required=data.get('is_geofence_required', True),
                status='ACTIVE'
            )

            # Assign allowed branches
            if data.get('allowed_branch_ids'):
                branches = Branch.objects.filter(id__in=data['allowed_branch_ids'], company=company)
                profile.allowed_branches.set(branches)
            elif department and department.allowed_branches.exists():
                profile.allowed_branches.set(department.allowed_branches.all())
            elif branch:
                profile.allowed_branches.add(branch)

            # Assign custom roles
            if data.get('custom_role_ids'):
                roles = CustomRole.objects.filter(id__in=data['custom_role_ids'], company=company)
                user.custom_roles.set(roles)

        return Response(EmployeeListSerializer(user).data, status=status.HTTP_201_CREATED)

class EmployeeDetailView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [require_permission('employees.view')()]
        if self.request.method == 'DELETE':
            return [require_permission('employees.deactivate')()]
        return [require_permission('employees.edit')()]

    def get(self, request, pk):
        company = request.user.company
        user = User.objects.filter(id=pk, company=company).first()
        if not user:
            return Response({"error": "Employee not found."}, status=status.HTTP_404_NOT_FOUND)
        return Response(EmployeeListSerializer(user).data)

    def patch(self, request, pk):
        company = request.user.company
        user = User.objects.filter(id=pk, company=company).first()
        if not user:
            return Response({"error": "Employee not found."}, status=status.HTTP_404_NOT_FOUND)

        if 'is_active' in request.data:
            new_active = bool(request.data['is_active'])
            if not new_active and str(user.id) == str(request.user.id):
                return Response(
                    {"error": "You cannot deactivate your own currently logged-in account."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            user.is_active = new_active
        if 'branch_id' in request.data:
            bid = request.data['branch_id']
            user.branch = Branch.objects.filter(id=bid, company=company).first() if bid else None
        if 'first_name' in request.data:
            user.first_name = request.data['first_name']
        if 'last_name' in request.data:
            user.last_name = request.data['last_name']
        if 'phone' in request.data:
            user.phone = request.data['phone']
        if 'role' in request.data and request.data['role'] in ['MANAGER', 'EMPLOYEE']:
            user.role = request.data['role']
        if 'password' in request.data and request.data['password']:
            user.set_password(request.data['password'])
        user.save()

        if 'custom_role_ids' in request.data:
            role_ids = request.data.get('custom_role_ids', [])
            user.custom_roles.set(CustomRole.objects.filter(id__in=role_ids, company=company))

        profile, _ = EmployeeProfile.objects.get_or_create(user=user)
        if 'status' in request.data:
            profile.status = request.data['status']
        if 'daily_call_target' in request.data:
            profile.daily_call_target = int(request.data['daily_call_target'])
        if 'department_id' in request.data:
            dept_id = request.data['department_id']
            profile.department = Department.objects.filter(id=dept_id, company=company).first() if dept_id else None
        if 'allowed_branch_ids' in request.data:
            branch_ids = request.data.get('allowed_branch_ids', [])
            profile.allowed_branches.set(Branch.objects.filter(id__in=branch_ids, company=company))
        if 'is_geofence_required' in request.data:
            profile.is_geofence_required = bool(request.data['is_geofence_required'])
        if 'shift_start_time' in request.data:
            profile.shift_start_time = request.data['shift_start_time']
        if 'shift_end_time' in request.data:
            profile.shift_end_time = request.data['shift_end_time']
        if 'team_id' in request.data:
            team_id = request.data['team_id']
            profile.team = Team.objects.filter(id=team_id, company=company).first() if team_id else None
        profile.save()

        return Response(EmployeeListSerializer(user).data)

class DepartmentListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [require_any_permission('departments.manage', 'employees.view', 'attendance.view_team')()]
        return [require_permission('departments.manage')()]

    def get(self, request):
        company = request.user.company
        if not company:
            depts = Department.objects.all() if request.user.is_super_admin else Department.objects.none()
        else:
            depts = Department.objects.filter(company=company)
        return Response(DepartmentSerializer(depts, many=True).data)

    def post(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "Company required"}, status=status.HTTP_400_BAD_REQUEST)

        name = request.data.get('name', '').strip()
        if not name:
            return Response({"error": "Department name is required."}, status=status.HTTP_400_BAD_REQUEST)

        code = request.data.get('code', '').strip().lower().replace(' ', '_') or name.lower().replace(' ', '_')
        attendance_mode = request.data.get('attendance_mode', 'GEOFENCE')
        description = request.data.get('description', '')

        with transaction.atomic():
            dept = Department.objects.create(
                company=company,
                name=name,
                code=code,
                attendance_mode=attendance_mode,
                description=description,
                is_active=True
            )
            branch_ids = request.data.get('allowed_branches', [])
            if branch_ids:
                branches = Branch.objects.filter(id__in=branch_ids, company=company)
                dept.allowed_branches.set(branches)

        return Response(DepartmentSerializer(dept).data, status=status.HTTP_201_CREATED)

class DepartmentDetailView(views.APIView):
    permission_classes = [require_permission('departments.manage')]

    def get(self, request, pk):
        company = request.user.company
        dept = Department.objects.filter(id=pk, company=company).first()
        if not dept:
            return Response({"error": "Department not found."}, status=status.HTTP_404_NOT_FOUND)
        return Response(DepartmentSerializer(dept).data)

    def patch(self, request, pk):
        company = request.user.company
        dept = Department.objects.filter(id=pk, company=company).first()
        if not dept:
            return Response({"error": "Department not found."}, status=status.HTTP_404_NOT_FOUND)

        if 'name' in request.data:
            dept.name = request.data['name'].strip()
        if 'code' in request.data:
            dept.code = request.data['code'].strip().lower().replace(' ', '_')
        if 'description' in request.data:
            dept.description = request.data['description']
        if 'attendance_mode' in request.data:
            dept.attendance_mode = request.data['attendance_mode']
        if 'is_active' in request.data:
            dept.is_active = bool(request.data['is_active'])
        dept.save()

        if 'allowed_branches' in request.data:
            branch_ids = request.data.get('allowed_branches', [])
            branches = Branch.objects.filter(id__in=branch_ids, company=company)
            dept.allowed_branches.set(branches)

        return Response(DepartmentSerializer(dept).data)

    def delete(self, request, pk):
        company = request.user.company
        dept = Department.objects.filter(id=pk, company=company).first()
        if not dept:
            return Response({"error": "Department not found."}, status=status.HTTP_404_NOT_FOUND)
        dept.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

class CustomRoleListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [require_any_permission('roles.manage', 'employees.view')()]
        return [require_permission('roles.manage')()]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response([])

        # Ensure standard default roles exist
        CustomRole.ensure_default_roles(company)

        roles = CustomRole.objects.filter(company=company, is_active=True).order_by('name')
        return Response(CustomRoleSerializer(roles, many=True).data)

    def post(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "Company required"}, status=status.HTTP_400_BAD_REQUEST)

        name = request.data.get('name', '').strip()
        if not name:
            return Response({"error": "Role name is required"}, status=status.HTTP_400_BAD_REQUEST)

        code = request.data.get('code', '').strip() or name.upper().replace(' ', '_')
        description = request.data.get('description', '').strip()
        permissions = request.data.get('permissions', [])

        if request.user.role != 'COMPANY_ADMIN' and not request.user.is_superuser:
            disallowed = [p for p in permissions if not request.user.has_permission(p)]
            if disallowed:
                return Response(
                    {"error": f"You cannot grant permissions you do not hold: {', '.join(disallowed)}"},
                    status=status.HTTP_403_FORBIDDEN
                )

        role = CustomRole.objects.create(
            company=company,
            name=name,
            code=code,
            description=description,
            permissions=permissions,
            is_system_default=False,
            is_active=True
        )

        return Response(CustomRoleSerializer(role).data, status=status.HTTP_201_CREATED)

class CustomRoleDetailView(views.APIView):
    permission_classes = [require_permission('roles.manage')]

    def get(self, request, pk):
        company = request.user.company
        role = CustomRole.objects.filter(id=pk, company=company).first()
        if not role:
            return Response({"error": "Role not found"}, status=status.HTTP_404_NOT_FOUND)
        return Response(CustomRoleSerializer(role).data)

    def patch(self, request, pk):
        company = request.user.company
        role = CustomRole.objects.filter(id=pk, company=company).first()
        if not role:
            return Response({"error": "Role not found"}, status=status.HTTP_404_NOT_FOUND)

        if 'name' in request.data:
            role.name = request.data['name'].strip()
        if 'code' in request.data:
            role.code = request.data['code'].strip()
        if 'description' in request.data:
            role.description = request.data['description'].strip()
        if 'permissions' in request.data:
            new_perms = request.data['permissions']
            if request.user.role != 'COMPANY_ADMIN' and not request.user.is_superuser:
                disallowed = [p for p in new_perms if not request.user.has_permission(p)]
                if disallowed:
                    return Response(
                        {"error": f"You cannot grant permissions you do not hold: {', '.join(disallowed)}"},
                        status=status.HTTP_403_FORBIDDEN
                    )
            role.permissions = new_perms
        if 'is_active' in request.data:
            role.is_active = bool(request.data['is_active'])

        role.save()
        return Response(CustomRoleSerializer(role).data)

    def delete(self, request, pk):
        company = request.user.company
        role = CustomRole.objects.filter(id=pk, company=company).first()
        if not role:
            return Response({"error": "Role not found"}, status=status.HTTP_404_NOT_FOUND)
        if role.is_system_default:
            return Response({"error": "System default roles cannot be deleted."}, status=status.HTTP_400_BAD_REQUEST)

        role.is_active = False
        role.save()
        return Response(status=status.HTTP_204_NO_CONTENT)


def calculate_haversine_distance(lat1, lon1, lat2, lon2):
    R = 6371000.0  # Earth radius in meters
    phi1 = math.radians(float(lat1))
    phi2 = math.radians(float(lat2))
    delta_phi = math.radians(float(lat2) - float(lat1))
    delta_lambda = math.radians(float(lon2) - float(lon1))

    a = math.sin(delta_phi / 2.0)**2 + \
        math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0)**2
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c

class AttendanceCheckInView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        if not (user.is_company_admin or user.has_permission('attendance.punch')):
            return Response({"error": "Permission denied: requires 'attendance.punch' permission."}, status=status.HTTP_403_FORBIDDEN)

        company = user.company
        if not company:
            return Response({"error": "Company not found for user."}, status=status.HTTP_400_BAD_REQUEST)

        today = timezone.now().date()
        att = AttendanceRecord.objects.filter(user=user, date=today).first()
        if att and att.check_in_time:
            return Response({"error": "You have already checked in today.", "attendance": AttendanceRecordSerializer(att).data}, status=status.HTTP_400_BAD_REQUEST)

        lat = request.data.get('latitude')
        lng = request.data.get('longitude')
        address = request.data.get('address', '')
        notes = request.data.get('notes', '')

        profile = getattr(user, 'employee_profile', None)
        department = profile.department if profile else None

        # Tracking mode
        tracking_mode = department.attendance_mode if department else 'GEOFENCE'

        matched_branch = None
        min_distance = None
        is_in_geofence = False
        att_status = 'PRESENT'

        if tracking_mode == 'GEOFENCE':
            # Resolve allowed branches: user overrides -> department branches -> user.branch
            branches = []
            if profile and profile.allowed_branches.exists():
                branches = list(profile.allowed_branches.filter(is_active=True))
            elif department and department.allowed_branches.exists():
                branches = list(department.allowed_branches.filter(is_active=True))
            elif user.branch:
                branches = [user.branch]
            else:
                branches = list(Branch.objects.filter(company=company, is_active=True))

            if lat is not None and lng is not None and branches:
                closest_branch = None
                closest_dist = float('inf')
                for b in branches:
                    if b.latitude is not None and b.longitude is not None:
                        dist = calculate_haversine_distance(lat, lng, b.latitude, b.longitude)
                        if dist < closest_dist:
                            closest_dist = dist
                            closest_branch = b

                if closest_branch is not None:
                    matched_branch = closest_branch
                    min_distance = round(closest_dist, 1)
                    radius = closest_branch.radius_meters or 100
                    if closest_dist <= radius:
                        is_in_geofence = True
                        att_status = 'PRESENT'
                    else:
                        return Response(
                            {
                                "error": f"Check-in blocked: You are {min_distance}m away from {closest_branch.name} (allowed radius: {radius}m). Move inside the office radius to check in."
                            },
                            status=status.HTTP_403_FORBIDDEN,
                        )
                else:
                    # No branch has GPS configured; accept check-in
                    is_in_geofence = True
                    att_status = 'PRESENT'
            else:
                is_in_geofence = True
                att_status = 'PRESENT'
        else:
            # Field Staff mode: always valid check-in with dynamic GPS recording
            is_in_geofence = True
            att_status = 'PRESENT'

        now = timezone.now()
        # Lateness evaluation if within fence or field staff
        if att_status != 'OUT_OF_FENCE' and profile and profile.shift_start_time:
            grace = profile.grace_period_minutes or 15
            current_minute = now.hour * 60 + now.minute
            shift_minute = profile.shift_start_time.hour * 60 + profile.shift_start_time.minute
            if current_minute > shift_minute + grace:
                att_status = 'LATE'

        if not att:
            att = AttendanceRecord(
                company=company,
                user=user,
                department=department,
                matched_branch=matched_branch,
                date=today,
                tracking_mode=tracking_mode,
            )
        else:
            att.department = department
            att.matched_branch = matched_branch
            att.tracking_mode = tracking_mode

        att.check_in_time = now
        att.check_in_lat = lat
        att.check_in_lng = lng
        att.check_in_address = address
        att.check_in_distance_meters = min_distance
        att.check_in_in_geofence = is_in_geofence
        att.status = att_status
        if notes:
            att.notes = notes
        att.save()

        return Response(AttendanceRecordSerializer(att).data, status=status.HTTP_200_OK)

class AttendanceCheckOutView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        today = timezone.now().date()
        att = AttendanceRecord.objects.filter(user=user, date=today).first()
        if not att or not att.check_in_time:
            return Response({"error": "No check-in record found for today. Please check-in first."}, status=status.HTTP_400_BAD_REQUEST)

        now = timezone.now()
        lat = request.data.get('latitude')
        lng = request.data.get('longitude')
        address = request.data.get('address', '')
        notes = request.data.get('notes', '')

        att.check_out_time = now
        att.check_out_lat = lat
        att.check_out_lng = lng
        att.check_out_address = address
        if notes:
            att.notes = f"{att.notes}\nCheck-out note: {notes}".strip()

        # Calculate working hours
        duration_seconds = (now - att.check_in_time).total_seconds()
        att.working_hours = round(max(0.0, duration_seconds / 3600.0), 2)
        att.save()

        return Response(AttendanceRecordSerializer(att).data, status=status.HTTP_200_OK)

class FieldVisitListCreateView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        today = timezone.now().date()
        visits = FieldVisit.objects.filter(user=user, attendance__date=today).order_by('visited_at')
        return Response(FieldVisitSerializer(visits, many=True).data)

    def post(self, request):
        user = request.user
        if not (user.is_company_admin or user.has_permission('attendance.field_visit')):
            return Response({"error": "Permission denied: requires 'attendance.field_visit' permission."}, status=status.HTTP_403_FORBIDDEN)

        company = user.company
        today = timezone.now().date()
        att = AttendanceRecord.objects.filter(user=user, date=today).first()
        if not att:
            return Response({"error": "You must check-in before recording field visits."}, status=status.HTTP_400_BAD_REQUEST)

        place_name = request.data.get('place_name', '').strip()
        if not place_name:
            return Response({"error": "Place or client name is required."}, status=status.HTTP_400_BAD_REQUEST)

        lat = request.data.get('latitude')
        lng = request.data.get('longitude')
        address = request.data.get('address', '')
        remarks = request.data.get('remarks', '')

        visit = FieldVisit.objects.create(
            company=company,
            attendance=att,
            user=user,
            place_name=place_name,
            latitude=lat,
            longitude=lng,
            address=address,
            visited_at=timezone.now(),
            remarks=remarks
        )

        return Response(FieldVisitSerializer(visit).data, status=status.HTTP_201_CREATED)

class AttendanceTodayView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        today = timezone.now().date()
        att = AttendanceRecord.objects.filter(user=user, date=today).first()
        if not att:
            return Response({"checked_in": False, "attendance": None})
        return Response({
            "checked_in": att.check_in_time is not None,
            "checked_out": att.check_out_time is not None,
            "attendance": AttendanceRecordSerializer(att).data
        })

class AttendanceAdminRecordsView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        if not (user.is_company_admin or user.has_permission('attendance.view_team') or user.has_permission('attendance.view_team_board')):
            return Response({"error": "Permission denied: requires 'attendance.view_team' permission."}, status=status.HTTP_403_FORBIDDEN)

        company = request.user.company
        if not company:
            return Response({"error": "Company required"}, status=status.HTTP_400_BAD_REQUEST)

        date_from = request.query_params.get('date_from')
        date_to = request.query_params.get('date_to')
        date_str = request.query_params.get('date')
        if date_from or date_to:
            records = AttendanceRecord.objects.filter(company=company).select_related('user', 'department', 'matched_branch')
            if date_from:
                records = records.filter(date__gte=date_from)
            if date_to:
                records = records.filter(date__lte=date_to)
            target_date = timezone.now().date()
        else:
            if date_str:
                try:
                    target_date = timezone.datetime.strptime(date_str, '%Y-%m-%d').date()
                except ValueError:
                    target_date = timezone.now().date()
            else:
                target_date = timezone.now().date()
            records = AttendanceRecord.objects.filter(company=company, date=target_date).select_related('user', 'department', 'matched_branch')

        branch_id = request.query_params.get('branch_id')
        if branch_id and branch_id != 'ALL':
            records = records.filter(matched_branch_id=branch_id)

        department_id = request.query_params.get('department_id')
        if department_id and department_id != 'ALL':
            records = records.filter(department_id=department_id)

        status_filter = request.query_params.get('status')
        if status_filter:
            records = records.filter(status=status_filter)

        total_employees = User.objects.filter(company=company, role__in=['MANAGER', 'EMPLOYEE'], is_active=True).count()
        present_count = records.filter(status__in=['PRESENT', 'LATE']).count()
        late_count = records.filter(status='LATE').count()
        out_of_fence_count = records.filter(status='OUT_OF_FENCE').count()
        checked_in_count = records.filter(check_in_time__isnull=False).count()
        absent_count = max(0, total_employees - checked_in_count)

        return Response({
            'date': str(target_date),
            'summary': {
                'total_employees': total_employees,
                'present_count': present_count,
                'late_count': late_count,
                'out_of_fence_count': out_of_fence_count,
                'absent_count': absent_count,
                'checked_in_count': checked_in_count,
            },
            'records': AttendanceRecordSerializer(records, many=True).data
        })

class TeamListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [require_any_permission('departments.manage', 'employees.view')()]
        return [require_permission('departments.manage')()]

    def get(self, request):
        company = request.user.company
        if not company:
            teams = Team.objects.all() if request.user.is_super_admin else Team.objects.none()
        else:
            teams = Team.objects.filter(company=company)
        return Response(TeamSerializer(teams, many=True).data)

    def post(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "Company required"}, status=status.HTTP_400_BAD_REQUEST)

        serializer = TeamSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        team = serializer.save(company=company)
        return Response(TeamSerializer(team).data, status=status.HTTP_201_CREATED)

class TeamDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = TeamSerializer
    permission_classes = [require_permission('departments.manage')]

    def get_queryset(self):
        if self.request.user.is_super_admin:
            return Team.objects.all()
        return Team.objects.filter(company=self.request.user.company)

class ChangePasswordView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = request.user
        if not user.check_password(serializer.validated_data['old_password']):
            return Response({
                "detail": "Current or temporary password is incorrect.",
                "error": "Current or temporary password is incorrect.",
                "old_password": ["Wrong password."]
            }, status=status.HTTP_400_BAD_REQUEST)
        user.set_password(serializer.validated_data['new_password'])
        user.save()
        return Response({"message": "Password changed successfully."})


class PermissionCatalogView(views.APIView):
    """
    Returns the grouped permission catalog filtered by the company's enabled plan modules.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        company = request.user.company
        groups = []
        for grp in PERMISSION_GROUPS:
            if company and not request.user.is_super_admin:
                if not company.has_menu_permission(grp['menu_key']):
                    continue
            groups.append(grp)
        return Response({'groups': groups})


class SectionDelegationListCreateView(views.APIView):
    """
    GET: Lists company delegations (or own received delegations).
    POST: Grants a time-bound section delegation ("Acting In-Charge") to an employee.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "Company required"}, status=status.HTTP_400_BAD_REQUEST)

        qs = SectionDelegation.objects.filter(company=company).select_related('delegator', 'delegatee', 'revoked_by')
        if not request.user.has_permission('delegation.manage'):
            qs = qs.filter(models.Q(delegator=request.user) | models.Q(delegatee=request.user))

        status_filter = request.query_params.get('status')
        today = timezone.localdate()
        if status_filter == 'ACTIVE':
            qs = qs.filter(is_active=True, start_date__lte=today, end_date__gte=today)
        elif status_filter == 'UPCOMING':
            qs = qs.filter(is_active=True, start_date__gt=today)
        elif status_filter == 'EXPIRED':
            qs = qs.filter(models.Q(is_active=False) | models.Q(end_date__lt=today))

        return Response(SectionDelegationSerializer(qs, many=True).data)

    def post(self, request):
        if not request.user.has_permission('delegation.manage'):
            return Response({"error": "Permission denied: requires 'delegation.manage'."}, status=status.HTTP_403_FORBIDDEN)

        company = request.user.company
        if not company:
            return Response({"error": "Company required"}, status=status.HTTP_400_BAD_REQUEST)

        serializer = SectionDelegationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        delegatee = serializer.validated_data['delegatee']
        if delegatee.company_id != company.id or not delegatee.is_active:
            return Response({"error": "Delegatee must be an active employee of your company."}, status=status.HTTP_400_BAD_REQUEST)
        if delegatee.id == request.user.id:
            return Response({"error": "You cannot delegate sections to yourself."}, status=status.HTTP_400_BAD_REQUEST)

        # Prevent privilege escalation: validate requested permissions
        requested_perms = serializer.validated_data.get('permissions') or []
        requested_sections = serializer.validated_data.get('sections') or []

        # If sections are specified without explicit permissions, expand all permissions in those sections
        if requested_sections and not requested_perms:
            for grp in PERMISSION_GROUPS:
                if grp['key'] in requested_sections:
                    for p in grp['permissions']:
                        if request.user.has_permission(p['key']):
                            requested_perms.append(p['key'])

        invalid_perms = [p for p in requested_perms if p not in ALL_PERMISSION_KEYS and not p.endswith('.*')]
        if invalid_perms:
            return Response({"error": f"Unknown permission keys: {invalid_perms}"}, status=status.HTTP_400_BAD_REQUEST)

        unauthorized_perms = [
            p for p in requested_perms
            if not p.endswith('.*') and not request.user.has_permission(p)
        ]
        if unauthorized_perms:
            return Response(
                {"error": f"You cannot delegate permissions you do not hold: {unauthorized_perms}"},
                status=status.HTTP_403_FORBIDDEN
            )

        with transaction.atomic():
            delegation = serializer.save(
                company=company,
                delegator=request.user,
                permissions=list(dict.fromkeys(requested_perms)),
                sections=list(dict.fromkeys(requested_sections)),
            )
            _log_permission_audit(
                request,
                action='DELEGATION_CREATED',
                target_model='SectionDelegation',
                target_id=delegation.id,
                details={
                    'delegatee_id': str(delegatee.id),
                    'delegatee_name': delegatee.full_name,
                    'sections': delegation.sections,
                    'permissions_count': len(delegation.permissions),
                    'start_date': str(delegation.start_date),
                    'end_date': str(delegation.end_date),
                },
            )

        return Response(SectionDelegationSerializer(delegation).data, status=status.HTTP_201_CREATED)


class SectionDelegationRevokeView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        company = request.user.company
        delegation = SectionDelegation.objects.filter(id=pk, company=company).first()
        if not delegation:
            return Response({"error": "Delegation not found."}, status=status.HTTP_404_NOT_FOUND)

        if delegation.delegator_id != request.user.id and not request.user.has_permission('delegation.manage'):
            return Response({"error": "Permission denied."}, status=status.HTTP_403_FORBIDDEN)

        if not delegation.is_active:
            return Response({"message": "Delegation is already inactive."})

        with transaction.atomic():
            delegation.is_active = False
            delegation.revoked_at = timezone.now()
            delegation.revoked_by = request.user
            delegation.save(update_fields=['is_active', 'revoked_at', 'revoked_by', 'updated_at'])
            _log_permission_audit(
                request,
                action='DELEGATION_REVOKED',
                target_model='SectionDelegation',
                target_id=delegation.id,
                details={
                    'delegatee_name': delegation.delegatee.full_name,
                    'sections': delegation.sections,
                },
            )

        return Response(SectionDelegationSerializer(delegation).data)


class PermissionAuditLogListView(views.APIView):
    permission_classes = [require_any_permission('roles.manage', 'delegation.manage')]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "Company required"}, status=status.HTTP_400_BAD_REQUEST)
        logs = PermissionAuditLog.objects.filter(company=company).select_related('actor', 'on_behalf_of')[:100]
        return Response(PermissionAuditLogSerializer(logs, many=True).data)
