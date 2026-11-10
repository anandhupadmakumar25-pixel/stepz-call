from rest_framework import views, status
from rest_framework.response import Response
from django.utils import timezone
from django.db import transaction
from apps.callbacks.models import Callback, CallbackHistory
from apps.callbacks.serializers import (
    CallbackSerializer,
    CallbackCreateSerializer,
    CallbackRescheduleSerializer,
    CallbackCompleteSerializer
)
from apps.callbacks.services.reminder_service import CallbackReminderService
from apps.leads.models import Lead
from apps.core.permissions import IsEmployee

class CallbackListView(views.APIView):
    permission_classes = [IsEmployee]

    def get(self, request):
        user = request.user
        company = user.company

        if user.is_super_admin:
            callbacks = Callback.objects.all()
        elif user.role == 'EMPLOYEE':
            callbacks = Callback.objects.filter(company=company, assigned_employee=user)
        else:
            callbacks = Callback.objects.filter(company=company)

        # Filters: status (SCHEDULED, DUE, OVERDUE, COMPLETED, RESCHEDULED)
        status_param = request.query_params.get('status')
        if status_param:
            callbacks = callbacks.filter(status=status_param)

        lead_id = request.query_params.get('lead')
        if lead_id:
            callbacks = callbacks.filter(lead_id=lead_id)

        employee_id = request.query_params.get('employee')
        if employee_id and user.is_company_admin:
            callbacks = callbacks.filter(assigned_employee_id=employee_id)

        # Date filter: today, upcoming
        date_filter = request.query_params.get('date_filter')
        now = timezone.now()
        if date_filter == 'today':
            callbacks = callbacks.filter(scheduled_at__date=now.date())
        elif date_filter == 'upcoming':
            callbacks = callbacks.filter(scheduled_at__gte=now, status__in=['SCHEDULED', 'RESCHEDULED'])
        elif date_filter == 'overdue':
            callbacks = callbacks.filter(status='OVERDUE')

        callbacks = callbacks.order_by('scheduled_at')[:100]
        return Response(CallbackSerializer(callbacks, many=True).data)

    def post(self, request):
        user = request.user
        company = user.company
        if not company:
            return Response({"error": "Company required"}, status=status.HTTP_400_BAD_REQUEST)

        serializer = CallbackCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        lead = data['lead']
        if lead.company_id != company.id:
            return Response({"error": "Lead does not belong to your company."}, status=status.HTTP_400_BAD_REQUEST)

        cb = Callback.objects.create(
            company=company,
            lead=lead,
            assigned_employee=user if user.role == 'EMPLOYEE' else (lead.assigned_to or user),
            scheduled_at=data['scheduled_at'],
            initial_notes=data.get('initial_notes', ''),
            status='SCHEDULED'
        )
        return Response(CallbackSerializer(cb).data, status=status.HTTP_201_CREATED)

class CallbackDetailView(views.APIView):
    permission_classes = [IsEmployee]

    def get(self, request, pk):
        cb = Callback.objects.filter(id=pk).first()
        if not cb:
            return Response({"error": "Callback not found"}, status=status.HTTP_404_NOT_FOUND)
        if not request.user.is_super_admin and cb.company_id != request.user.company_id:
            return Response({"error": "Unauthorized"}, status=status.HTTP_403_FORBIDDEN)
        if request.user.role == 'EMPLOYEE' and cb.assigned_employee_id != request.user.id:
            return Response({"error": "Unauthorized"}, status=status.HTTP_403_FORBIDDEN)
        return Response(CallbackSerializer(cb).data)

class CallbackRescheduleView(views.APIView):
    permission_classes = [IsEmployee]

    def post(self, request, pk):
        cb = Callback.objects.filter(id=pk).first()
        if not cb:
            return Response({"error": "Callback not found"}, status=status.HTTP_404_NOT_FOUND)
        if not request.user.is_super_admin and cb.company_id != request.user.company_id:
            return Response({"error": "Unauthorized"}, status=status.HTTP_403_FORBIDDEN)
        if request.user.role == 'EMPLOYEE' and cb.assigned_employee_id != request.user.id:
            return Response({"error": "You are only authorized to modify callbacks assigned to you."}, status=status.HTTP_403_FORBIDDEN)

        serializer = CallbackRescheduleSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        with transaction.atomic():
            old_status = cb.status
            cb.scheduled_at = data['new_scheduled_at']
            cb.status = 'RESCHEDULED'
            cb.rescheduled_count += 1
            cb.last_rescheduled_at = timezone.now()
            cb.reminder_sent = False
            cb.save()

            CallbackHistory.objects.create(
                callback=cb,
                changed_by=request.user,
                from_status=old_status,
                to_status='RESCHEDULED',
                rescheduled_to=data['new_scheduled_at'],
                reason=data['reason']
            )

        return Response(CallbackSerializer(cb).data)

class CallbackCompleteView(views.APIView):
    permission_classes = [IsEmployee]

    def post(self, request, pk):
        cb = Callback.objects.filter(id=pk).first()
        if not cb:
            return Response({"error": "Callback not found"}, status=status.HTTP_404_NOT_FOUND)
        if not request.user.is_super_admin and cb.company_id != request.user.company_id:
            return Response({"error": "Unauthorized"}, status=status.HTTP_403_FORBIDDEN)
        if request.user.role == 'EMPLOYEE' and cb.assigned_employee_id != request.user.id:
            return Response({"error": "You are only authorized to modify callbacks assigned to you."}, status=status.HTTP_403_FORBIDDEN)

        serializer = CallbackCompleteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        with transaction.atomic():
            old_status = cb.status
            cb.status = 'COMPLETED'
            cb.completed_at = timezone.now()
            cb.completion_notes = data['completion_notes']
            cb.save()

            CallbackHistory.objects.create(
                callback=cb,
                changed_by=request.user,
                from_status=old_status,
                to_status='COMPLETED',
                reason="Completed callback"
            )

        return Response(CallbackSerializer(cb).data)

class CheckRemindersTriggerView(views.APIView):
    """
    Triggers the background due/overdue callback processing.
    Can be called by cron/scheduler or manual test trigger.
    """
    permission_classes = [IsEmployee]

    def post(self, request):
        result = CallbackReminderService.process_due_and_overdue_callbacks()
        return Response(result)
