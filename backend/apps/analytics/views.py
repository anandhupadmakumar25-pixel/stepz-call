from datetime import timedelta
from django.utils import timezone
from django.db.models import Count, Q, Max
from rest_framework import views
from rest_framework.response import Response
from apps.leads.models import Lead, ImportBatch
from apps.calls.models import CallAttempt
from apps.callbacks.models import Callback
from apps.accounts.models import User
from apps.core.permissions import IsCompanyAdmin, IsEmployee

class AdminDashboardMetricsView(views.APIView):
    permission_classes = [IsCompanyAdmin]

    def get(self, request):
        company = request.user.company
        if not company and not request.user.is_super_admin:
            return Response({})

        lead_qs = Lead.objects.all() if request.user.is_super_admin else Lead.objects.filter(company=company)
        call_qs = CallAttempt.objects.all() if request.user.is_super_admin else CallAttempt.objects.filter(company=company)
        cb_qs = Callback.objects.all() if request.user.is_super_admin else Callback.objects.filter(company=company)
        emp_qs = User.objects.filter(role__in=['EMPLOYEE', 'MANAGER'], is_active=True) if request.user.is_super_admin else User.objects.filter(company=company, role__in=['EMPLOYEE', 'MANAGER'], is_active=True)

        now = timezone.now()
        today = now.date()
        week_ago = now - timedelta(days=7)

        # 1. KPI Cards
        total_registered_leads = lead_qs.count()
        newly_imported_leads = lead_qs.filter(created_at__gte=week_ago).count()
        assigned_leads = lead_qs.filter(status__in=['ASSIGNED', 'IN_PROGRESS', 'CALLBACK_REQUESTED']).count()
        unassigned_leads = lead_qs.filter(status='UNASSIGNED').count()
        calls_logged_today = call_qs.filter(created_at__date=today).count()
        calls_logged_total = call_qs.count()
        completed_leads = lead_qs.filter(status='COMPLETED').count()
        scheduled_callbacks = cb_qs.filter(status__in=['SCHEDULED', 'RESCHEDULED']).count()
        completed_callbacks = cb_qs.filter(status='COMPLETED').count()
        overdue_callbacks = cb_qs.filter(status='OVERDUE').count()

        # 2. Call Outcomes Distribution
        outcome_counts = list(
            call_qs.values('outcome').annotate(count=Count('id')).order_by('-count')
        )

        # 3. Lead Status Distribution
        status_counts = list(
            lead_qs.values('status').annotate(count=Count('id')).order_by('-count')
        )

        # 4. Activity Over Time (last 7 days)
        activity_timeline = []
        for d in range(6, -1, -1):
            day_date = today - timedelta(days=d)
            count = call_qs.filter(created_at__date=day_date).count()
            activity_timeline.append({
                'date': day_date.strftime('%Y-%m-%d'),
                'day': day_date.strftime('%a'),
                'calls': count
            })

        # 5. Employee Performance Table
        employee_performance = []
        for emp in emp_qs:
            assigned = lead_qs.filter(assigned_to=emp, status__in=['ASSIGNED', 'IN_PROGRESS', 'CALLBACK_REQUESTED']).count()
            calls_today = call_qs.filter(employee=emp, created_at__date=today).count()
            calls_total = call_qs.filter(employee=emp).count()
            completed = lead_qs.filter(assigned_to=emp, status='COMPLETED').count()
            cbs_due = cb_qs.filter(assigned_employee=emp, status='DUE').count()
            cbs_done = cb_qs.filter(assigned_employee=emp, status='COMPLETED').count()
            cbs_overdue = cb_qs.filter(assigned_employee=emp, status='OVERDUE').count()
            last_call = call_qs.filter(employee=emp).aggregate(last_act=Max('created_at'))['last_act']

            target = 50
            if hasattr(emp, 'employee_profile') and emp.employee_profile:
                target = emp.employee_profile.daily_call_target

            employee_performance.append({
                'employee_id': str(emp.id),
                'name': emp.full_name,
                'email': emp.email,
                'assigned_leads': assigned,
                'calls_today': calls_today,
                'daily_target': target,
                'calls_total': calls_total,
                'completed_leads': completed,
                'callbacks_due': cbs_due,
                'callbacks_done': cbs_done,
                'callbacks_overdue': cbs_overdue,
                'last_activity': last_call.isoformat() if last_call else None,
            })

        return Response({
            'kpis': {
                'total_registered_leads': total_registered_leads,
                'newly_imported_leads': newly_imported_leads,
                'assigned_leads': assigned_leads,
                'unassigned_leads': unassigned_leads,
                'calls_logged_today': calls_logged_today,
                'calls_logged_total': calls_logged_total,
                'completed_leads': completed_leads,
                'scheduled_callbacks': scheduled_callbacks,
                'completed_callbacks': completed_callbacks,
                'overdue_callbacks': overdue_callbacks,
            },
            'outcomes': outcome_counts,
            'lead_statuses': status_counts,
            'activity_timeline': activity_timeline,
            'employee_performance': employee_performance,
        })

class TelecallerDashboardMetricsView(views.APIView):
    permission_classes = [IsEmployee]

    def get(self, request):
        user = request.user
        company = user.company
        now = timezone.now()
        today = now.date()

        assigned_leads = Lead.objects.filter(
            company=company,
            assigned_to=user,
            status__in=['ASSIGNED', 'IN_PROGRESS', 'CALLBACK_REQUESTED']
        ).count()

        completed_leads = Lead.objects.filter(
            company=company,
            assigned_to=user,
            status='COMPLETED'
        ).count()

        calls_today = CallAttempt.objects.filter(
            company=company,
            employee=user,
            created_at__date=today
        ).count()

        daily_target = 50
        if hasattr(user, 'employee_profile') and user.employee_profile:
            daily_target = user.employee_profile.daily_call_target

        callbacks_due_today = Callback.objects.filter(
            company=company,
            assigned_employee=user,
            scheduled_at__date=today,
            status__in=['SCHEDULED', 'DUE', 'RESCHEDULED']
        ).count()

        callbacks_upcoming = Callback.objects.filter(
            company=company,
            assigned_employee=user,
            scheduled_at__gt=now,
            status__in=['SCHEDULED', 'RESCHEDULED']
        ).count()

        callbacks_overdue = Callback.objects.filter(
            company=company,
            assigned_employee=user,
            status='OVERDUE'
        ).count()

        recent_calls = CallAttempt.objects.filter(
            company=company,
            employee=user
        ).order_by('-created_at')[:5]

        from apps.calls.serializers import CallAttemptSerializer

        return Response({
            'kpis': {
                'assigned_leads': assigned_leads,
                'completed_leads': completed_leads,
                'calls_today': calls_today,
                'daily_target': daily_target,
                'callbacks_due_today': callbacks_due_today,
                'callbacks_upcoming': callbacks_upcoming,
                'callbacks_overdue': callbacks_overdue,
            },
            'recent_calls': CallAttemptSerializer(recent_calls, many=True).data
        })
