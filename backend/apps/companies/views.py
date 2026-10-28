from rest_framework import generics, status, views
from rest_framework.response import Response
from django.db import transaction
from django.contrib.auth import get_user_model
from apps.companies.models import Company
from apps.companies.serializers import CompanySerializer, CompanyCreateSerializer
from apps.core.permissions import IsSuperAdmin, IsCompanyAdmin

User = get_user_model()

class CompanyListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'POST':
            return [IsSuperAdmin()]
        return [IsCompanyAdmin()]

    def get(self, request):
        if request.user.is_super_admin:
            companies = Company.objects.all().order_by('-created_at')
            return Response(CompanySerializer(companies, many=True).data)
        elif request.user.company:
            return Response([CompanySerializer(request.user.company).data])
        return Response([])

    def post(self, request):
        serializer = CompanyCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        admin_email = data.pop('admin_email')
        admin_password = data.pop('admin_password')
        admin_first_name = data.pop('admin_first_name')
        admin_last_name = data.pop('admin_last_name', '')

        if User.objects.filter(email=admin_email).exists():
            return Response({"admin_email": ["User with this email already exists."]}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            company = Company.objects.create(**data)
            admin_user = User.objects.create_user(
                email=admin_email,
                password=admin_password,
                first_name=admin_first_name,
                last_name=admin_last_name,
                role='COMPANY_ADMIN',
                company=company,
                is_active=True
            )

        return Response(CompanySerializer(company).data, status=status.HTTP_201_CREATED)

class CompanyDetailView(views.APIView):
    def get_permissions(self):
        return [IsCompanyAdmin()]

    def get(self, request, pk):
        if request.user.is_super_admin:
            company = Company.objects.filter(id=pk).first()
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

        # Non-super admin cannot change company status
        if not request.user.is_super_admin and 'status' in request.data:
            return Response({"error": "Only super admin can change company status."}, status=status.HTTP_403_FORBIDDEN)

        serializer = CompanySerializer(company, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)
