from rest_framework import views, status
from rest_framework.response import Response
from django.db import transaction
from django.utils import timezone
from apps.calls.models import CallAttempt
from apps.calls.serializers import CallAttemptSerializer, LogCallOutcomeSerializer
from apps.leads.models import Lead
from apps.callbacks.models import Callback
from apps.core.permissions import IsEmployee

class CallAttemptListCreateView(views.APIView):
    permission_classes = [IsEmployee]

    def get(self, request):
        user = request.user
        company = user.company

        if user.is_super_admin:
            calls = CallAttempt.objects.all()
        elif user.role == 'EMPLOYEE':
            calls = CallAttempt.objects.filter(company=company, employee=user)
        else:
            calls = CallAttempt.objects.filter(company=company)

        lead_id = request.query_params.get('lead')
        if lead_id:
            calls = calls.filter(lead_id=lead_id)

        outcome = request.query_params.get('outcome')
        if outcome:
            calls = calls.filter(outcome=outcome)

        employee_id = request.query_params.get('employee')
        if employee_id and user.is_company_admin:
            calls = calls.filter(employee_id=employee_id)

        calls = calls.order_by('-created_at')[:100]
        return Response(CallAttemptSerializer(calls, many=True).data)

    def post(self, request):
        user = request.user
        company = user.company
        if not company:
            return Response({"error": "User must belong to a company"}, status=status.HTTP_400_BAD_REQUEST)

        serializer = LogCallOutcomeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        lead = Lead.objects.filter(id=data['lead_id'], company=company).first()
        if not lead:
            return Response({"error": "Lead not found in your company."}, status=status.HTTP_404_NOT_FOUND)

        with transaction.atomic():
            call = CallAttempt.objects.create(
                company=company,
                lead=lead,
                employee=user,
                outcome=data['outcome'],
                notes=data['notes'],
                duration_seconds=data.get('duration_seconds', 0),
                dialer_launched_at=data.get('dialer_launched_at')
            )

            # Map call outcome to lead status
            outcome = data['outcome']
            if outcome == 'CALLBACK_REQUESTED':
                lead.status = 'CALLBACK_REQUESTED'
            elif outcome in ['INTERESTED', 'QUALIFIED']:
                lead.status = outcome
            elif outcome in ['NOT_INTERESTED', 'BUSY', 'NO_ANSWER']:
                lead.status = outcome
            else:
                lead.status = 'IN_PROGRESS'
            lead.save(update_fields=['status'])

            # Handle callback scheduling if requested
            if (outcome == 'CALLBACK_REQUESTED' or data.get('schedule_callback')) and data.get('callback_time'):
                Callback.objects.create(
                    company=company,
                    lead=lead,
                    assigned_employee=user,
                    originating_call_attempt=call,
                    scheduled_at=data['callback_time'],
                    status='SCHEDULED',
                    initial_notes=data.get('callback_notes') or data['notes']
                )

        return Response(CallAttemptSerializer(call).data, status=status.HTTP_201_CREATED)

class CallAttemptDetailView(views.APIView):
    permission_classes = [IsEmployee]

    def get(self, request, pk):
        call = CallAttempt.objects.filter(id=pk).first()
        if not call:
            return Response({"error": "Call attempt not found"}, status=status.HTTP_404_NOT_FOUND)
        if not request.user.is_super_admin and call.company_id != request.user.company_id:
            return Response({"error": "Unauthorized"}, status=status.HTTP_403_FORBIDDEN)
        return Response(CallAttemptSerializer(call).data)
