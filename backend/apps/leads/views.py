from rest_framework import views, status, generics
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from django.db.models import Q

from apps.leads.models import Lead, Branch, LeadCategory, CallingTask, ImportBatch, PermanentPhoneNumberRegistry
from apps.leads.serializers import (
    LeadSerializer,
    LeadDetailSerializer,
    BranchSerializer,
    LeadCategorySerializer,
    CallingTaskSerializer,
    ImportBatchSerializer,
    PermanentPhoneNumberRegistrySerializer,
    BulkAssignSerializer
)
from apps.leads.services.import_service import LeadImportService
from apps.leads.services.assignment_service import LeadAssignmentService
from apps.core.permissions import IsCompanyAdmin, IsEmployee
from apps.core.phone_utils import normalize_phone_number

class BranchListCreateView(views.APIView):
    permission_classes = [IsEmployee]

    def get(self, request):
        user = request.user
        company = user.company
        if not company:
            return Response([])
        branches = Branch.objects.filter(company=company, is_active=True).order_by('name')
        return Response(BranchSerializer(branches, many=True).data)

    def post(self, request):
        user = request.user
        company = user.company
        if not company or not user.is_company_admin:
            return Response({"error": "Admin permission required."}, status=status.HTTP_403_FORBIDDEN)
        name = request.data.get('name', '').strip()
        if not name:
            return Response({"name": ["Branch name is required."]}, status=status.HTTP_400_BAD_REQUEST)
        branch, created = Branch.objects.get_or_create(
            company=company,
            name=name,
            defaults={
                'code': request.data.get('code', '').strip(),
                'address': request.data.get('address', '').strip(),
                'is_active': True
            }
        )
        if not created and not branch.is_active:
            branch.is_active = True
            branch.save(update_fields=['is_active'])
        return Response(BranchSerializer(branch).data, status=status.HTTP_201_CREATED)

class BranchDetailView(views.APIView):
    permission_classes = [IsCompanyAdmin]

    def delete(self, request, pk):
        branch = Branch.objects.filter(id=pk, company=request.user.company).first()
        if not branch:
            return Response({"error": "Branch not found."}, status=status.HTTP_404_NOT_FOUND)
        branch.is_active = False
        branch.save(update_fields=['is_active'])
        return Response({"message": "Branch deleted successfully."}, status=status.HTTP_200_OK)

class LeadCategoryListCreateView(views.APIView):
    permission_classes = [IsEmployee]

    def get(self, request):
        user = request.user
        company = user.company
        if not company:
            return Response([])
        categories = LeadCategory.objects.filter(company=company, is_active=True).order_by('name')
        return Response(LeadCategorySerializer(categories, many=True).data)

    def post(self, request):
        user = request.user
        company = user.company
        if not company or not user.is_company_admin:
            return Response({"error": "Admin permission required."}, status=status.HTTP_403_FORBIDDEN)
        name = request.data.get('name', '').strip()
        if not name:
            return Response({"name": ["Category name is required."]}, status=status.HTTP_400_BAD_REQUEST)
        category, created = LeadCategory.objects.get_or_create(
            company=company,
            name=name,
            defaults={
                'color_code': request.data.get('color_code', '#6366F1'),
                'description': request.data.get('description', '').strip(),
                'is_active': True
            }
        )
        if not created and not category.is_active:
            category.is_active = True
            category.save(update_fields=['is_active'])
        return Response(LeadCategorySerializer(category).data, status=status.HTTP_201_CREATED)

class LeadCategoryDetailView(views.APIView):
    permission_classes = [IsCompanyAdmin]

    def delete(self, request, pk):
        category = LeadCategory.objects.filter(id=pk, company=request.user.company).first()
        if not category:
            return Response({"error": "Category not found."}, status=status.HTTP_404_NOT_FOUND)
        category.is_active = False
        category.save(update_fields=['is_active'])
        return Response({"message": "Category deleted successfully."}, status=status.HTTP_200_OK)

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
        if status_param and status_param != 'ALL':
            leads = leads.filter(status=status_param)

        branch_param = request.query_params.get('branch')
        if branch_param and branch_param != 'ALL':
            leads = leads.filter(branch_id=branch_param)

        category_param = request.query_params.get('category')
        if category_param and category_param != 'ALL':
            leads = leads.filter(category_id=category_param)

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
        leads = leads.select_related('branch', 'category', 'assigned_to').order_by('-created_at')
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

        # Dynamic Branch and Category resolution
        branch_id = request.data.get('branch') or request.data.get('branch_id')
        category_id = request.data.get('category') or request.data.get('category_id')

        branch = None
        if branch_id:
            branch = Branch.objects.filter(id=branch_id, company=company).first()

        category = None
        if category_id:
            category = LeadCategory.objects.filter(id=category_id, company=company).first()

        lead = Lead.objects.create(
            company=company,
            branch=branch,
            category=category,
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

        if 'notes' in request.data or 'note' in request.data:
            note_val = request.data.get('note') or request.data.get('notes', '')
            cf = dict(lead.custom_fields or {})
            cf['notes'] = note_val
            lead.custom_fields = cf
            lead.save(update_fields=['custom_fields'])

            if note_val:
                from apps.calls.models import CallAttempt
                CallAttempt.objects.create(
                    company=lead.company,
                    lead=lead,
                    employee=user,
                    outcome='NOTE_UPDATED',
                    notes=note_val,
                    call_duration=0
                )

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
        branch_id = request.data.get('branch_id')
        category_id = request.data.get('category_id')
        try:
            created_count = LeadImportService.confirm_import(
                batch_id=pk,
                company=company,
                confirmed_by=request.user,
                branch_id=branch_id,
                category_id=category_id,
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

class CallingTaskListCreateView(views.APIView):
    permission_classes = [IsEmployee]

    def get(self, request):
        user = request.user
        company = user.company
        if not company:
            return Response([])

        tasks = CallingTask.objects.filter(company=company)
        if user.role == 'EMPLOYEE':
            tasks = tasks.filter(assigned_to=user)
        else:
            # Filters for Admin / Manager
            assigned_to = request.query_params.get('assigned_to')
            if assigned_to and assigned_to != 'ALL':
                tasks = tasks.filter(assigned_to_id=assigned_to)

        branch_id = request.query_params.get('branch')
        if branch_id and branch_id != 'ALL':
            tasks = tasks.filter(branch_id=branch_id)

        category_id = request.query_params.get('category')
        if category_id and category_id != 'ALL':
            tasks = tasks.filter(category_id=category_id)

        status_param = request.query_params.get('status')
        if status_param and status_param != 'ALL':
            tasks = tasks.filter(status=status_param)

        search = request.query_params.get('search')
        if search:
            tasks = tasks.filter(
                Q(title__icontains=search) |
                Q(description__icontains=search)
            )

        tasks = tasks.select_related('branch', 'category', 'assigned_to', 'created_by').prefetch_related('leads').order_by('-created_at')
        return Response(CallingTaskSerializer(tasks, many=True).data)

    def post(self, request):
        from django.contrib.auth import get_user_model
        from django.utils import timezone
        from apps.leads.models import LeadAssignmentHistory
        from django.db import transaction

        user = request.user
        company = user.company
        if not company or not user.is_company_admin:
            return Response({"error": "Admin permission required to create calling tasks."}, status=status.HTTP_403_FORBIDDEN)

        title = request.data.get('title', '').strip()
        if not title:
            return Response({"title": ["Task title is required."]}, status=status.HTTP_400_BAD_REQUEST)

        assigned_to_id = request.data.get('assigned_to_id')
        User = get_user_model()
        assigned_user = User.objects.filter(id=assigned_to_id, company=company).first()
        if not assigned_user:
            return Response({"assigned_to_id": ["Target employee not found in your company."]}, status=status.HTTP_400_BAD_REQUEST)

        branch_id = request.data.get('branch_id')
        branch = Branch.objects.filter(id=branch_id, company=company).first() if branch_id else None

        category_id = request.data.get('category_id')
        category = LeadCategory.objects.filter(id=category_id, company=company).first() if category_id else None

        priority = request.data.get('priority', 'MEDIUM')
        due_date = request.data.get('due_date') or None
        description = request.data.get('description', '').strip()

        with transaction.atomic():
            task = CallingTask.objects.create(
                company=company,
                title=title,
                description=description,
                branch=branch,
                category=category,
                assigned_to=assigned_user,
                created_by=user,
                priority=priority,
                due_date=due_date,
                status='PENDING'
            )

            # Determine leads to attach to this task
            lead_ids = request.data.get('lead_ids', [])
            lead_count = int(request.data.get('lead_count', 0) or 0)

            leads_to_assign = []
            if lead_ids:
                leads_to_assign = list(Lead.objects.filter(id__in=lead_ids, company=company))
            elif lead_count > 0:
                qs = Lead.objects.filter(company=company, status='UNASSIGNED')
                if branch:
                    qs = qs.filter(branch=branch)
                if category:
                    qs = qs.filter(category=category)
                leads_to_assign = list(qs[:lead_count])

            now = timezone.now()
            registries_to_create = []
            history_to_create = []

            for lead in leads_to_assign:
                lead.task = task
                lead.assigned_to = assigned_user
                lead.assigned_at = now
                lead.status = 'ASSIGNED'
                lead.is_assigned_ever = True
                lead.save(update_fields=['task', 'assigned_to', 'assigned_at', 'status', 'is_assigned_ever'])

                # Permanent Registry Invariant
                if not PermanentPhoneNumberRegistry.objects.filter(company=company, normalized_phone=lead.normalized_phone).exists():
                    registries_to_create.append(PermanentPhoneNumberRegistry(
                        company=company,
                        normalized_phone=lead.normalized_phone,
                        first_assigned_to=assigned_user,
                        original_lead_id=lead.id,
                        notes=f"Auto-registered via Task '{task.title}'"
                    ))

                history_to_create.append(LeadAssignmentHistory(
                    company=company,
                    lead=lead,
                    assigned_to=assigned_user,
                    assigned_by=user,
                    assignment_method='CUSTOM',
                    notes=f"Assigned via Calling Task: {task.title}"
                ))

            if registries_to_create:
                PermanentPhoneNumberRegistry.objects.bulk_create(registries_to_create, ignore_conflicts=True)
            if history_to_create:
                LeadAssignmentHistory.objects.bulk_create(history_to_create)

            task.target_count = len(leads_to_assign)
            task.save(update_fields=['target_count'])

        return Response(CallingTaskSerializer(task).data, status=status.HTTP_201_CREATED)

class CallingTaskDetailView(views.APIView):
    permission_classes = [IsEmployee]

    def get(self, request, pk):
        user = request.user
        company = user.company
        task = CallingTask.objects.filter(id=pk, company=company).first()
        if not task:
            return Response({"error": "Calling task not found."}, status=status.HTTP_404_NOT_FOUND)
        if user.role == 'EMPLOYEE' and task.assigned_to_id != user.id:
            return Response({"error": "Permission denied."}, status=status.HTTP_403_FORBIDDEN)

        data = CallingTaskSerializer(task).data
        # Include task leads
        leads = task.leads.select_related('branch', 'category').order_by('-created_at')
        data['leads'] = LeadSerializer(leads, many=True).data
        return Response(data)

    def patch(self, request, pk):
        user = request.user
        company = user.company
        task = CallingTask.objects.filter(id=pk, company=company).first()
        if not task:
            return Response({"error": "Calling task not found."}, status=status.HTTP_404_NOT_FOUND)

        if user.role == 'EMPLOYEE' and task.assigned_to_id != user.id:
            return Response({"error": "Permission denied."}, status=status.HTTP_403_FORBIDDEN)

        if 'status' in request.data:
            task.status = request.data['status']
        if user.is_company_admin:
            if 'priority' in request.data:
                task.priority = request.data['priority']
            if 'title' in request.data:
                task.title = request.data['title']
            if 'description' in request.data:
                task.description = request.data['description']
            if 'due_date' in request.data:
                task.due_date = request.data['due_date'] or None

        task.save()
        return Response(CallingTaskSerializer(task).data)

    def delete(self, request, pk):
        user = request.user
        if not user.is_company_admin:
            return Response({"error": "Admin permission required."}, status=status.HTTP_403_FORBIDDEN)
        task = CallingTask.objects.filter(id=pk, company=user.company).first()
        if not task:
            return Response({"error": "Calling task not found."}, status=status.HTTP_404_NOT_FOUND)
        task.status = 'CANCELLED'
        task.save(update_fields=['status'])
        return Response({"message": "Task cancelled successfully."})
