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

        if user.role == 'EMPLOYEE' and lead.assigned_to_id != user.id:
            return Response({"error": "You are only authorized to log calls for leads assigned to you."}, status=status.HTTP_403_FORBIDDEN)

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
        if request.user.role == 'EMPLOYEE' and call.employee_id != request.user.id:
            return Response({"error": "Unauthorized"}, status=status.HTTP_403_FORBIDDEN)
        return Response(CallAttemptSerializer(call).data)

class CallRecordingListCreateView(views.APIView):
    permission_classes = [IsEmployee]
    from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get(self, request):
        from apps.calls.models import CallRecording
        from apps.calls.serializers import CallRecordingSerializer

        user = request.user
        company = user.company
        if not company:
            return Response([])

        if user.is_super_admin:
            recordings = CallRecording.objects.all()
        elif user.role == 'EMPLOYEE':
            recordings = CallRecording.objects.filter(company=company, employee=user)
        else:
            recordings = CallRecording.objects.filter(company=company)

        lead_id = request.query_params.get('lead')
        if lead_id:
            recordings = recordings.filter(lead_id=lead_id)

        call_id = request.query_params.get('call')
        if call_id:
            recordings = recordings.filter(call_attempt_id=call_id)

        employee_id = request.query_params.get('employee')
        if employee_id and (user.is_company_admin or user.is_super_admin):
            recordings = recordings.filter(employee_id=employee_id)

        recordings = recordings.select_related('lead', 'employee', 'call_attempt').order_by('-created_at')[:100]
        return Response(CallRecordingSerializer(recordings, many=True, context={'request': request}).data)

    def post(self, request):
        from apps.calls.models import CallRecording, CallAttempt
        from apps.calls.serializers import CallRecordingSerializer
        from apps.leads.models import Lead

        user = request.user
        company = user.company
        if not company:
            return Response({"error": "User must belong to a company"}, status=status.HTTP_400_BAD_REQUEST)

        lead_id = request.data.get('lead_id') or request.data.get('lead')
        if not lead_id:
            return Response({"lead_id": ["Target lead ID is mandatory for recording association."]}, status=status.HTTP_400_BAD_REQUEST)

        lead = Lead.objects.filter(id=lead_id, company=company).first()
        if not lead:
            return Response({"error": "Lead not found in your company."}, status=status.HTTP_404_NOT_FOUND)

        if user.role == 'EMPLOYEE' and lead.assigned_to_id != user.id:
            return Response({"error": "You are only authorized to save recordings for leads assigned to you."}, status=status.HTTP_403_FORBIDDEN)

        call_attempt = None
        call_attempt_id = request.data.get('call_attempt_id') or request.data.get('call_attempt')
        if call_attempt_id:
            call_attempt = CallAttempt.objects.filter(id=call_attempt_id, company=company, lead=lead).first()

        duration = int(request.data.get('duration_seconds', 0) or 0)
        source = request.data.get('source', 'MIC_RECORDING')
        notes = request.data.get('notes', '').strip()
        audio_file = request.FILES.get('audio_file')

        file_size = audio_file.size if audio_file else 0

        recording = CallRecording.objects.create(
            company=company,
            lead=lead,
            employee=user,
            call_attempt=call_attempt,
            audio_file=audio_file,
            duration_seconds=duration,
            file_size_bytes=file_size,
            source=source,
            notes=notes
        )

        return Response(CallRecordingSerializer(recording, context={'request': request}).data, status=status.HTTP_201_CREATED)

class CallRecordingDetailView(views.APIView):
    permission_classes = [IsEmployee]

    def get(self, request, pk):
        from apps.calls.models import CallRecording
        from apps.calls.serializers import CallRecordingSerializer

        recording = CallRecording.objects.filter(id=pk).first()
        if not recording:
            return Response({"error": "Recording not found"}, status=status.HTTP_404_NOT_FOUND)
        if not request.user.is_super_admin and recording.company_id != request.user.company_id:
            return Response({"error": "Unauthorized"}, status=status.HTTP_403_FORBIDDEN)
        if request.user.role == 'EMPLOYEE' and recording.employee_id != request.user.id:
            return Response({"error": "Unauthorized"}, status=status.HTTP_403_FORBIDDEN)
        return Response(CallRecordingSerializer(recording).data)

    def delete(self, request, pk):
        from apps.calls.models import CallRecording

        if not request.user.is_company_admin:
            return Response({"error": "Admin permission required to delete recordings."}, status=status.HTTP_403_FORBIDDEN)

        recording = CallRecording.objects.filter(id=pk, company=request.user.company).first()
        if not recording:
            return Response({"error": "Recording not found"}, status=status.HTTP_404_NOT_FOUND)

        if recording.audio_file:
            recording.audio_file.delete(save=False)
        recording.delete()
        return Response({"message": "Recording deleted successfully."})
