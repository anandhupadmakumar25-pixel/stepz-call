from rest_framework import generics, status, views
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model
from django.db import transaction

from apps.accounts.models import Team, EmployeeProfile
from apps.accounts.serializers import (
    CustomTokenObtainPairSerializer,
    UserProfileSerializer,
    EmployeeListSerializer,
    EmployeeCreateSerializer,
    TeamSerializer,
    ChangePasswordSerializer
)
from apps.core.permissions import IsCompanyAdmin, IsManager

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
    permission_classes = [IsCompanyAdmin]

    def get(self, request):
        company = request.user.company
        if not company:
            if request.user.is_super_admin:
                employees = User.objects.filter(role__in=['COMPANY_ADMIN', 'MANAGER', 'EMPLOYEE'])
            else:
                return Response([])
        else:
            employees = User.objects.filter(company=company, role__in=['MANAGER', 'EMPLOYEE'])
            
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

            EmployeeProfile.objects.create(
                user=user,
                team=team,
                manager=manager,
                employee_code=data.get('employee_code', ''),
                daily_call_target=data.get('daily_call_target', 50),
                status='ACTIVE'
            )

        return Response(EmployeeListSerializer(user).data, status=status.HTTP_201_CREATED)

class EmployeeDetailView(views.APIView):
    permission_classes = [IsCompanyAdmin]

    def get(self, request, pk):
        company = request.user.company
        user = User.objects.filter(id=pk, company=company).first()
        if not user:
            return Response({"error": "Employee not found."}, status=status.HTTP_404_NOT_FOUND)
        return Response(EmployeeListSerializer(user).data)

    def patch(self, request, pk):
        from apps.leads.models import Branch
        company = request.user.company
        user = User.objects.filter(id=pk, company=company).first()
        if not user:
            return Response({"error": "Employee not found."}, status=status.HTTP_404_NOT_FOUND)

        # Allow updating active status, name, phone, branch, team, daily target
        if 'is_active' in request.data:
            user.is_active = bool(request.data['is_active'])
        if 'branch_id' in request.data:
            bid = request.data['branch_id']
            user.branch = Branch.objects.filter(id=bid, company=company).first() if bid else None
        if 'first_name' in request.data:
            user.first_name = request.data['first_name']
        if 'last_name' in request.data:
            user.last_name = request.data['last_name']
        if 'phone' in request.data:
            user.phone = request.data['phone']
        user.save()

        profile, _ = EmployeeProfile.objects.get_or_create(user=user)
        if 'status' in request.data:
            profile.status = request.data['status']
        if 'daily_call_target' in request.data:
            profile.daily_call_target = int(request.data['daily_call_target'])
        if 'team_id' in request.data:
            team_id = request.data['team_id']
            profile.team = Team.objects.filter(id=team_id, company=company).first() if team_id else None
        profile.save()

        return Response(EmployeeListSerializer(user).data)

class TeamListCreateView(views.APIView):
    permission_classes = [IsCompanyAdmin]

    def get(self, request):
        company = request.user.company
        teams = Team.objects.filter(company=company) if company else Team.objects.all()
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
    permission_classes = [IsCompanyAdmin]

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
            return Response({"old_password": ["Wrong password."]}, status=status.HTTP_400_BAD_REQUEST)
        user.set_password(serializer.validated_data['new_password'])
        user.save()
        return Response({"message": "Password changed successfully."})
