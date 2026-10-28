from rest_framework import views, status, generics
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from django.db.models import Q

from apps.leads.models import Lead, ImportBatch, PermanentPhoneNumberRegistry
from apps.leads.serializers import (
    LeadSerializer,
    LeadDetailSerializer,
    ImportBatchSerializer,
    PermanentPhoneNumberRegistrySerializer,
    BulkAssignSerializer
)
from apps.leads.services.import_service import LeadImportService
from apps.leads.services.assignment_service import LeadAssignmentService
from apps.core.permissions import IsCompanyAdmin, IsEmployee
from apps.core.phone_utils import normalize_phone_number

class LeadListCreateView(views.APIView):
    permission_classes = [IsEmployee]

    def get(self, request):
        user = request.user
        company = user.company

        if user.is_super_admin:
            leads = Lead.objects.all()
        else:
            if not company:
                return Response([])
            if user.role == 'EMPLOYEE':
                leads = Lead.objects.filter(company=company, assigned_to=user)
            else:
                leads = Lead.objects.filter(company=company)

        # Filters
        status_param = request.query_params.get('status')
        if status_param:
            leads = leads.filter(status=status_param)

        assigned_to_param = request.query_params.get('assigned_to')
        if assigned_to_param and user.is_company_admin:
            if assigned_to_param == 'unassigned':
                leads = leads.filter(assigned_to__isnull=True)
            else:
                leads = leads.filter(assigned_to_id=assigned_to_param)

        search = request.query_params.get('search')
        if search:
            leads = leads.filter(
                Q(first_name__icontains=search) |
                Q(last_name__icontains=search) |
                Q(raw_phone__icontains=search) |
                Q(normalized_phone__icontains=search) |
                Q(email__icontains=search) |
                Q(city__icontains=search)
            )

        # Simple pagination or full list
        leads = leads.order_by('-created_at')
        serializer = LeadSerializer(leads[:200], many=True)
        return Response(serializer.data)

    def post(self, request):
        user = request.user
        company = user.company
        if not company:
            return Response({"error": "User must belong to a company to create leads."}, status=status.HTTP_400_BAD_REQUEST)

        raw_phone = request.data.get('raw_phone', '').strip()
        first_name = request.data.get('first_name', '').strip()

        if not raw_phone or not first_name:
            return Response({"error": "First name and phone number are required."}, status=status.HTTP_400_BAD_REQUEST)

        normalized_phone, is_valid, err_msg = normalize_phone_number(raw_phone, company.default_country_iso or 'IN')
        if not is_valid:
            return Response({"raw_phone": [f"Invalid phone number: {err_msg}"]}, status=status.HTTP_400_BAD_REQUEST)

        # MANDATORY INVARIANT: Check Permanent Phone Number Blocking
        if PermanentPhoneNumberRegistry.objects.filter(company=company, normalized_phone=normalized_phone).exists():
            return Response(
                {"raw_phone": [f"Phone number {normalized_phone} is permanently blocked in this company as it was previously assigned."]},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Check existing active leads in company
        if Lead.objects.filter(company=company, normalized_phone=normalized_phone).exists():
            return Response(
                {"raw_phone": [f"A lead with phone number {normalized_phone} already exists in the company directory."]},
                status=status.HTTP_400_BAD_REQUEST
            )

        lead = Lead.objects.create(
            company=company,
            first_name=first_name,
            last_name=request.data.get('last_name', '').strip(),
            raw_phone=raw_phone,
            normalized_phone=normalized_phone,
            email=request.data.get('email', '').strip(),
            city=request.data.get('city', '').strip(),
            state=request.data.get('state', '').strip(),
            source=request.data.get('source', 'MANUAL'),
            status='UNASSIGNED',
            custom_fields=request.data.get('custom_fields', {})
        )

        return Response(LeadSerializer(lead).data, status=status.HTTP_201_CREATED)

class LeadDetailView(views.APIView):
    permission_classes = [IsEmployee]

    def get(self, request, pk):
        user = request.user
        company = user.company
        lead = Lead.objects.filter(id=pk).first()
        if not lead:
            return Response({"error": "Lead not found"}, status=status.HTTP_404_NOT_FOUND)

        if not user.is_super_admin and lead.company_id != company.id:
            return Response({"error": "Unauthorized"}, status=status.HTTP_403_FORBIDDEN)

        if user.role == 'EMPLOYEE' and lead.assigned_to_id != user.id:
            return Response({"error": "Unauthorized"}, status=status.HTTP_403_FORBIDDEN)

        return Response(LeadDetailSerializer(lead).data)

    def patch(self, request, pk):
        user = request.user
        company = user.company
        lead = Lead.objects.filter(id=pk).first()
        if not lead:
            return Response({"error": "Lead not found"}, status=status.HTTP_404_NOT_FOUND)

        if not user.is_super_admin and lead.company_id != company.id:
            return Response({"error": "Unauthorized"}, status=status.HTTP_403_FORBIDDEN)

        serializer = LeadSerializer(lead, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)

class LeadImportUploadView(views.APIView):
    permission_classes = [IsCompanyAdmin]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "Company required"}, status=status.HTTP_400_BAD_REQUEST)

        file_obj = request.FILES.get('file')
        if not file_obj:
            return Response({"error": "No file uploaded. Please upload a .xlsx or .csv file."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            batch = LeadImportService.preview_import(
                company=company,
                uploaded_by=request.user,
                file_obj=file_obj,
                filename=file_obj.name
            )
            return Response(ImportBatchSerializer(batch).data, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

class LeadImportConfirmView(views.APIView):
    permission_classes = [IsCompanyAdmin]

    def post(self, request, pk):
        company = request.user.company
        try:
            created_count = LeadImportService.confirm_import(
                batch_id=pk,
                company=company,
                confirmed_by=request.user
            )
            return Response({
                "success": True,
                "message": f"Successfully imported {created_count} leads.",
                "imported_count": created_count
            })
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

class ImportBatchListView(views.APIView):
    permission_classes = [IsCompanyAdmin]

    def get(self, request):
        company = request.user.company
        batches = ImportBatch.objects.filter(company=company).order_by('-created_at')
        return Response(ImportBatchSerializer(batches, many=True).data)

class LeadBulkAssignView(views.APIView):
    permission_classes = [IsCompanyAdmin]

    def post(self, request):
        company = request.user.company
        serializer = BulkAssignSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            result = LeadAssignmentService.bulk_assign(
                company=company,
                assigned_by=request.user,
                lead_ids=data['lead_ids'],
                allocations=data['allocations'],
                method=data.get('method', 'EQUAL')
            )
            return Response(result)
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

class PermanentRegistryListView(views.APIView):
    permission_classes = [IsCompanyAdmin]

    def get(self, request):
        company = request.user.company
        numbers = PermanentPhoneNumberRegistry.objects.filter(company=company).order_by('-first_assigned_at')
        search = request.query_params.get('search')
        if search:
            numbers = numbers.filter(normalized_phone__icontains=search)
        return Response(PermanentPhoneNumberRegistrySerializer(numbers[:200], many=True).data)
