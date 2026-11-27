import calendar
from datetime import date, datetime, timedelta
from decimal import Decimal
from django.db import transaction
from django.utils import timezone
from rest_framework import status, views
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from apps.accounts.models import (
    User,
    AttendanceRecord,
    CompanyHoliday,
    LeaveType,
    LeaveBalance,
    LeaveRequest,
    AttendanceRegularization,
    EmployeeSalaryStructure,
    PayrollRun,
    Payslip,
    PayslipPayment,
    PayrollReminderLog,
)
from apps.companies.models import CompanyCustomRule
from apps.accounts.serializers_hr import (
    CompanyHolidaySerializer,
    LeaveTypeSerializer,
    LeaveBalanceSerializer,
    LeaveRequestSerializer,
    AttendanceRegularizationSerializer,
    EmployeeSalaryStructureSerializer,
    PayrollRunSerializer,
    PayslipSerializer,
    PayslipPaymentSerializer,
)
from apps.core.permissions import require_permission, require_any_permission


def _ensure_default_leave_types(company):
    if not LeaveType.objects.filter(company=company).exists():
        defaults = [
            ('Casual Leave', 'CL', 12.0, True),
            ('Sick Leave', 'SL', 10.0, True),
            ('Earned Leave', 'EL', 15.0, True),
            ('Loss of Pay', 'LOP', 0.0, False),
        ]
        for name, code, quota, is_paid in defaults:
            LeaveType.objects.get_or_create(
                company=company,
                code=code,
                defaults={'name': name, 'annual_quota': quota, 'is_paid': is_paid},
            )


def _ensure_leave_balances_for_user(user, year):
    _ensure_default_leave_types(user.company)
    for lt in LeaveType.objects.filter(company=user.company, is_active=True):
        LeaveBalance.objects.get_or_create(
            company=user.company,
            user=user,
            leave_type=lt,
            year=year,
            defaults={'allocated': lt.annual_quota, 'used': 0.0},
        )


class CompanyHolidayListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [require_permission('leave.manage_types')()]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response([])
        qs = CompanyHoliday.objects.filter(company=company)
        year = request.query_params.get('year')
        if year:
            qs = qs.filter(date__year=year)
        return Response(CompanyHolidaySerializer(qs, many=True).data)

    def post(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "Company required"}, status=status.HTTP_400_BAD_REQUEST)
        serializer = CompanyHolidaySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        holiday = serializer.save(company=company)
        return Response(CompanyHolidaySerializer(holiday).data, status=status.HTTP_201_CREATED)


class CompanyHolidayDetailView(views.APIView):
    permission_classes = [require_permission('leave.manage_types')]

    def delete(self, request, pk):
        holiday = CompanyHoliday.objects.filter(id=pk, company=request.user.company).first()
        if not holiday:
            return Response({"error": "Holiday not found"}, status=status.HTTP_404_NOT_FOUND)
        holiday.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class LeaveTypeListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [require_permission('leave.manage_types')()]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response([])
        _ensure_default_leave_types(company)
        qs = LeaveType.objects.filter(company=company, is_active=True)
        return Response(LeaveTypeSerializer(qs, many=True).data)

    def post(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "Company required"}, status=status.HTTP_400_BAD_REQUEST)
        serializer = LeaveTypeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        lt = serializer.save(company=company)
        return Response(LeaveTypeSerializer(lt).data, status=status.HTTP_201_CREATED)


class MyLeaveBalancesView(views.APIView):
    permission_classes = [require_any_permission('leave.apply_own', 'leave.approve', 'leave.manage_types')]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response([])
        year = int(request.query_params.get('year') or timezone.localdate().year)
        _ensure_leave_balances_for_user(request.user, year)
        qs = LeaveBalance.objects.filter(company=company, user=request.user, year=year).select_related('leave_type')
        return Response(LeaveBalanceSerializer(qs, many=True).data)


class LeaveRequestListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [require_any_permission('leave.apply_own', 'leave.approve', 'leave.manage_types')()]
        return [require_any_permission('leave.apply_own', 'leave.approve')()]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response([])
        qs = LeaveRequest.objects.filter(company=company).select_related('user', 'leave_type', 'reviewed_by')
        if not request.user.has_permission('leave.approve'):
            qs = qs.filter(user=request.user)
        elif request.query_params.get('mine') == 'true':
            qs = qs.filter(user=request.user)
        elif request.query_params.get('user_id'):
            qs = qs.filter(user_id=request.query_params.get('user_id'))

        stat = request.query_params.get('status')
        if stat and stat != 'ALL':
            qs = qs.filter(status=stat)
        return Response(LeaveRequestSerializer(qs, many=True).data)

    def post(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "Company required"}, status=status.HTTP_400_BAD_REQUEST)
        serializer = LeaveRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        start = serializer.validated_data['start_date']
        end = serializer.validated_data['end_date']
        is_half = serializer.validated_data.get('is_half_day', False)
        lt = serializer.validated_data['leave_type']
        if lt.company_id != company.id:
            return Response({"error": "Invalid leave type"}, status=status.HTTP_400_BAD_REQUEST)

        target_user = request.user
        req_user_id = request.data.get('user_id')
        if req_user_id and str(req_user_id) != str(request.user.id):
            if not (request.user.is_company_admin or request.user.has_permission('leave.approve')):
                return Response({"error": "Permission denied to apply leave for another employee."}, status=status.HTTP_403_FORBIDDEN)
            found = User.objects.filter(id=req_user_id, company=company).first()
            if not found:
                return Response({"error": "Employee not found in your company."}, status=status.HTTP_404_NOT_FOUND)
            target_user = found

        days_count = Decimal('0.5') if is_half else Decimal(str((end - start).days + 1))

        # Check leave balance if paid
        if lt.is_paid:
            _ensure_leave_balances_for_user(target_user, start.year)
            bal = LeaveBalance.objects.filter(user=target_user, leave_type=lt, year=start.year).first()
            if bal and bal.remaining < float(days_count):
                return Response(
                    {"error": f"Insufficient {lt.name} balance. Remaining: {bal.remaining} days."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        req = serializer.save(company=company, user=target_user, days_count=days_count)
        return Response(LeaveRequestSerializer(req).data, status=status.HTTP_201_CREATED)


class LeaveRequestActionView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        company = request.user.company
        lr = LeaveRequest.objects.filter(id=pk, company=company).select_related('leave_type', 'user').first()
        if not lr:
            return Response({"error": "Leave request not found"}, status=status.HTTP_404_NOT_FOUND)

        action = (request.data.get('action') or '').upper()
        notes = request.data.get('review_notes', '')

        if action == 'CANCEL':
            if lr.user_id != request.user.id and not request.user.has_permission('leave.approve'):
                return Response({"error": "Permission denied"}, status=status.HTTP_403_FORBIDDEN)
            if lr.status != 'PENDING':
                return Response({"error": "Only pending requests can be cancelled"}, status=status.HTTP_400_BAD_REQUEST)
            lr.status = 'CANCELLED'
            lr.save(update_fields=['status', 'updated_at'])
            return Response(LeaveRequestSerializer(lr).data)

        if action not in ('APPROVE', 'REJECT'):
            return Response({"error": "Invalid action. Use APPROVE, REJECT, or CANCEL."}, status=status.HTTP_400_BAD_REQUEST)

        if not request.user.has_permission('leave.approve'):
            return Response({"error": "Permission denied: requires 'leave.approve'."}, status=status.HTTP_403_FORBIDDEN)
        if lr.status != 'PENDING':
            return Response({"error": "Leave request has already been processed."}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            lr.status = 'APPROVED' if action == 'APPROVE' else 'REJECTED'
            lr.reviewed_by = request.user
            lr.reviewed_at = timezone.now()
            lr.review_notes = notes
            lr.save(update_fields=['status', 'reviewed_by', 'reviewed_at', 'review_notes', 'updated_at'])

            if lr.status == 'APPROVED':
                if lr.leave_type.is_paid:
                    _ensure_leave_balances_for_user(lr.user, lr.start_date.year)
                    bal = LeaveBalance.objects.select_for_update().filter(
                        user=lr.user, leave_type=lr.leave_type, year=lr.start_date.year
                    ).first()
                    if bal:
                        bal.used = Decimal(str(bal.used)) + Decimal(str(lr.days_count))
                        bal.save(update_fields=['used', 'updated_at'])

                # Sync attendance records for approved leave dates
                cur = lr.start_date
                while cur <= lr.end_date:
                    AttendanceRecord.objects.update_or_create(
                        company=company,
                        user=lr.user,
                        date=cur,
                        defaults={
                            'status': 'HALF_DAY' if lr.is_half_day else 'ON_LEAVE',
                            'notes': f"Approved {lr.leave_type.code}: {lr.reason[:100]}",
                        },
                    )
                    cur += timedelta(days=1)

        return Response(LeaveRequestSerializer(lr).data)


class AttendanceRegularizationListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [require_any_permission('attendance.mark_own', 'attendance.view_team', 'attendance.approve_corrections')()]
        return [require_any_permission('attendance.mark_own', 'attendance.approve_corrections')()]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response([])
        qs = AttendanceRegularization.objects.filter(company=company).select_related('user', 'reviewed_by')
        if not request.user.has_permission('attendance.approve_corrections'):
            qs = qs.filter(user=request.user)
        return Response(AttendanceRegularizationSerializer(qs, many=True).data)

    def post(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "Company required"}, status=status.HTTP_400_BAD_REQUEST)
        serializer = AttendanceRegularizationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        reg = serializer.save(company=company, user=request.user)
        return Response(AttendanceRegularizationSerializer(reg).data, status=status.HTTP_201_CREATED)


class AttendanceRegularizationActionView(views.APIView):
    permission_classes = [require_permission('attendance.approve_corrections')]

    def post(self, request, pk):
        company = request.user.company
        reg = AttendanceRegularization.objects.filter(id=pk, company=company).select_related('user').first()
        if not reg:
            return Response({"error": "Regularization request not found"}, status=status.HTTP_404_NOT_FOUND)
        if reg.status != 'PENDING':
            return Response({"error": "Request already processed"}, status=status.HTTP_400_BAD_REQUEST)

        action = (request.data.get('action') or '').upper()
        if action not in ('APPROVE', 'REJECT'):
            return Response({"error": "Use APPROVE or REJECT"}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            reg.status = 'APPROVED' if action == 'APPROVE' else 'REJECTED'
            reg.reviewed_by = request.user
            reg.reviewed_at = timezone.now()
            reg.review_notes = request.data.get('review_notes', '')
            reg.save(update_fields=['status', 'reviewed_by', 'reviewed_at', 'review_notes', 'updated_at'])

            if reg.status == 'APPROVED':
                cin_dt = timezone.make_aware(datetime.combine(reg.date, reg.requested_check_in))
                cout_dt = timezone.make_aware(datetime.combine(reg.date, reg.requested_check_out)) if reg.requested_check_out else None
                hrs = round((cout_dt - cin_dt).total_seconds() / 3600.0, 2) if cout_dt and cout_dt > cin_dt else 0.0
                AttendanceRecord.objects.update_or_create(
                    company=company,
                    user=reg.user,
                    date=reg.date,
                    defaults={
                        'check_in_time': cin_dt,
                        'check_out_time': cout_dt,
                        'working_hours': hrs,
                        'status': 'PRESENT',
                        'notes': f"Regularized: {reg.reason[:100]}",
                    },
                )
        return Response(AttendanceRegularizationSerializer(reg).data)


class EmployeeSalaryStructureListUpsertView(views.APIView):
    permission_classes = [require_permission('payroll.manage_rules')]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response([])
        qs = EmployeeSalaryStructure.objects.filter(company=company).select_related('user')
        return Response(EmployeeSalaryStructureSerializer(qs, many=True).data)

    def post(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "Company required"}, status=status.HTTP_400_BAD_REQUEST)
        user_id = request.data.get('user')
        emp = User.objects.filter(id=user_id, company=company).first()
        if not emp:
            return Response({"error": "Employee not found in your company"}, status=status.HTTP_404_NOT_FOUND)

        existing = EmployeeSalaryStructure.objects.filter(user=emp, company=company).first()
        data = request.data.copy()
        if not data.get('currency'):
            data['currency'] = company.currency
        serializer = EmployeeSalaryStructureSerializer(existing, data=data, partial=bool(existing))
        serializer.is_valid(raise_exception=True)
        obj = serializer.save(company=company, user=emp)
        return Response(EmployeeSalaryStructureSerializer(obj).data, status=status.HTTP_200_OK if existing else status.HTTP_201_CREATED)


def _compute_payslip_due_date(year, month, salary_day):
    pay_month = 1 if month == 12 else month + 1
    pay_year = year + 1 if month == 12 else year
    max_day = calendar.monthrange(pay_year, pay_month)[1]
    clamped_day = max(1, min(int(salary_day or 5), max_day))
    return date(pay_year, pay_month, clamped_day)


def _generate_payslip_receipt_number(company, year):
    prefix = f"SAL-{year}-"
    existing_count = PayslipPayment.objects.filter(
        company=company,
        receipt_number__startswith=prefix,
    ).count()
    return f"{prefix}{existing_count + 1:04d}"


def dispatch_payroll_reminders(company=None):
    from apps.notifications.models import Notification
    today = timezone.localdate()
    slips_qs = Payslip.objects.filter(
        balance_due__gt=0,
        due_date__isnull=False,
        status__in=['DRAFT', 'FINALIZED'],
    ).select_related('company', 'user')
    if company is not None:
        slips_qs = slips_qs.filter(company=company)

    # Group pending slips by (company, month, year)
    grouped = {}
    for slip in slips_qs:
        key = (slip.company_id, slip.month, slip.year)
        grouped.setdefault(key, {'company': slip.company, 'slips': []})['slips'].append(slip)

    dispatched = 0
    for (comp_id, month, year), bundle in grouped.items():
        comp = bundle['company']
        slips = bundle['slips']
        policy = getattr(comp, 'payroll_policy', None)
        reminder_days = int(getattr(policy, 'reminder_days_before', 2) or 2)

        upcoming = [
            s for s in slips
            if s.due_date and (s.due_date - timedelta(days=reminder_days)) <= today <= s.due_date
        ]
        overdue = [
            s for s in slips
            if s.due_date and today > s.due_date
        ]

        admins = list(User.objects.filter(company=comp, role='COMPANY_ADMIN', is_active=True))
        month_label = date(year, month, 1).strftime('%b %Y')
        curr = comp.currency or 'INR'

        if upcoming:
            total_due = sum((s.balance_due for s in upcoming), Decimal('0.00'))
            nearest_due = min(s.due_date for s in upcoming)
            for adm in admins:
                _, created = PayrollReminderLog.objects.get_or_create(
                    company=comp,
                    user=adm,
                    month=month,
                    year=year,
                    reminder_type='UPCOMING_PAYDAY',
                    sent_date=today,
                )
                if created:
                    Notification.objects.create(
                        company=comp,
                        user=adm,
                        title='Upcoming Salary Payday Reminder',
                        message=(
                            f"Payroll for {month_label} is due on {nearest_due.strftime('%d %b %Y')} "
                            f"({len(upcoming)} staff, Total Due: {curr} {total_due:,.2f})."
                        ),
                        notification_type='SYSTEM',
                        entity_type='payroll',
                        entity_id=f"{year}-{month:02d}",
                    )
                    dispatched += 1

        if overdue:
            total_overdue = sum((s.balance_due for s in overdue), Decimal('0.00'))
            for adm in admins:
                _, created = PayrollReminderLog.objects.get_or_create(
                    company=comp,
                    user=adm,
                    month=month,
                    year=year,
                    reminder_type='OVERDUE_BALANCE',
                    sent_date=today,
                )
                if created:
                    Notification.objects.create(
                        company=comp,
                        user=adm,
                        title='Salary Balance Due Reminder',
                        message=(
                            f"{len(overdue)} employee(s) have overdue salary balance "
                            f"({curr} {total_overdue:,.2f}) for {month_label}."
                        ),
                        notification_type='SYSTEM',
                        entity_type='payroll',
                        entity_id=f"{year}-{month:02d}",
                    )
                    dispatched += 1

    return dispatched


class PayrollRunListGenerateView(views.APIView):
    permission_classes = [require_permission('payroll.process_salary')]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response([])
        runs = PayrollRun.objects.filter(company=company).select_related('generated_by').prefetch_related('payslips')
        return Response(PayrollRunSerializer(runs, many=True).data)

    def post(self, request):
        company = request.user.company
        if not company:
            return Response({"error": "Company required"}, status=status.HTTP_400_BAD_REQUEST)

        month = int(request.data.get('month') or timezone.localdate().month)
        year = int(request.data.get('year') or timezone.localdate().year)
        if not (1 <= month <= 12):
            return Response({"error": "Invalid month (1-12)"}, status=status.HTTP_400_BAD_REQUEST)

        existing_run = PayrollRun.objects.filter(company=company, month=month, year=year).first()
        if existing_run and existing_run.status != 'DRAFT':
            return Response({"error": f"Payroll for {month}/{year} is already {existing_run.status} and locked."}, status=status.HTTP_400_BAD_REQUEST)

        days_in_month = calendar.monthrange(year, month)[1]
        month_start = date(year, month, 1)
        month_end = date(year, month, days_in_month)
        today = timezone.localdate()

        policy = getattr(company, 'payroll_policy', None)
        calc_basis = policy.pay_calculation_basis if policy else 'CALENDAR_DAYS'
        base_working_days = 26 if calc_basis == 'FIXED_26_DAYS' else days_in_month
        auto_deduct_absent = policy.auto_deduct_absent_lop if policy else False
        default_salary_day = policy.salary_day if policy else 5
        overtime_enabled = policy.overtime_enabled if policy else False
        overtime_min_mins = policy.overtime_min_minutes if policy else 60
        overtime_mult = Decimal(str(policy.overtime_hourly_multiplier if policy else 1.0))
        full_day_hours = Decimal(str(policy.full_day_hours if policy else 8.0))

        holiday_dates = set(
            CompanyHoliday.objects.filter(
                company=company,
                date__year=year,
                date__month=month,
                is_optional=False,
            ).values_list('date', flat=True)
        )
        month_holidays_count = len(holiday_dates)

        structures = EmployeeSalaryStructure.objects.filter(
            company=company, user__is_active=True
        ).select_related('user', 'user__employee_profile')
        if not structures.exists():
            return Response({"error": "No employee salary structures configured yet."}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            if existing_run:
                existing_run.payslips.all().delete()
                run = existing_run
            else:
                run = PayrollRun.objects.create(
                    company=company,
                    month=month,
                    year=year,
                    generated_by=request.user,
                    status='DRAFT',
                )

            tot_gross = Decimal('0.00')
            tot_ded = Decimal('0.00')
            tot_net = Decimal('0.00')

            active_rules = list(CompanyCustomRule.objects.filter(company=company, is_active=True))

            for st in structures:
                prof = getattr(st.user, 'employee_profile', None)
                joining_date = getattr(prof, 'joining_date', None) if prof else None
                if joining_date and joining_date > month_end:
                    continue

                # Effective working days (after holidays and joining-date pro-rata)
                emp_working_days = max(1, base_working_days - month_holidays_count)
                rule_breakdown = []
                if joining_date and month_start < joining_date <= month_end:
                    active_cal_days = (month_end - joining_date).days + 1
                    holidays_after_join = sum(1 for h in holiday_dates if h >= joining_date)
                    prorated_days = max(1, active_cal_days - holidays_after_join)
                    if calc_basis == 'FIXED_26_DAYS':
                        prorated_days = max(1, round((prorated_days / days_in_month) * emp_working_days))
                    emp_working_days = min(emp_working_days, prorated_days)
                    rule_breakdown.append({
                        'rule_name': 'Joining-Date Pro-Rata',
                        'category': 'PRO_RATA',
                        'metric': 'JOINING_DATE',
                        'count': emp_working_days,
                        'action_type': 'INFO',
                        'amount': 0.0,
                        'detail': f'Joined {joining_date.isoformat()} ({emp_working_days} working days)',
                    })

                att_qs = AttendanceRecord.objects.filter(company=company, user=st.user, date__year=year, date__month=month)
                present_dates = set(
                    att_qs.filter(status__in=['PRESENT', 'LATE', 'OUT_OF_FENCE']).values_list('date', flat=True)
                )
                half_dates = set(
                    att_qs.filter(status='HALF_DAY').values_list('date', flat=True)
                ) - present_dates
                present_days = Decimal(str(len(present_dates))) + (Decimal(str(len(half_dates))) * Decimal('0.5'))
                late_days = att_qs.filter(status='LATE').values('date').distinct().count()
                out_of_fence_days = att_qs.filter(check_in_in_geofence=False).values('date').distinct().count()

                # Overtime calculation
                overtime_hours = Decimal('0.00')
                if overtime_enabled and prof:
                    shift_start_dt = datetime.combine(month_start, prof.shift_start_time)
                    shift_end_dt = datetime.combine(month_start, prof.shift_end_time)
                    if shift_end_dt <= shift_start_dt:
                        shift_end_dt += timedelta(days=1)
                    shift_hours = Decimal(str((shift_end_dt - shift_start_dt).total_seconds() / 3600.0))
                    daily_hours = {}
                    for rec in att_qs:
                        if rec.working_hours:
                            daily_hours[rec.date] = daily_hours.get(rec.date, Decimal('0.00')) + Decimal(str(rec.working_hours))
                    min_ot_hours = Decimal(str(overtime_min_mins)) / Decimal('60')
                    for hrs in daily_hours.values():
                        extra = hrs - shift_hours
                        if extra >= min_ot_hours:
                            overtime_hours += extra
                    overtime_hours = round(overtime_hours, 2)

                # Paid & Unpaid leaves in this month
                paid_leaves = Decimal('0.0')
                unpaid_leaves = Decimal('0.0')
                approved_leaves = LeaveRequest.objects.filter(
                    company=company, user=st.user, status='APPROVED',
                    start_date__year=year, start_date__month=month,
                ).select_related('leave_type')
                for lr in approved_leaves:
                    if lr.leave_type.is_paid:
                        paid_leaves += Decimal(str(lr.days_count))
                    else:
                        unpaid_leaves += Decimal(str(lr.days_count))

                # Unexcused absent days
                absent_days = Decimal('0.0')
                if auto_deduct_absent:
                    if date(year, month, 1) < date(today.year, today.month, 1):
                        elapsed_days = emp_working_days
                    elif year == today.year and month == today.month:
                        join_eff = joining_date if (joining_date and joining_date >= month_start) else month_start
                        elapsed_cal = max(0, (today - join_eff).days + 1)
                        hol_elapsed = sum(1 for h in holiday_dates if join_eff <= h <= today)
                        elapsed_days = min(emp_working_days, max(0, elapsed_cal - hol_elapsed))
                    else:
                        elapsed_days = 0
                    absent_days = max(
                        Decimal('0.0'),
                        Decimal(str(elapsed_days)) - present_days - paid_leaves - unpaid_leaves,
                    )

                lop_days = unpaid_leaves + absent_days

                # Pro-rated salary if joined mid-month
                full_gross = Decimal(str(round(st.gross_salary, 2)))
                if joining_date and month_start < joining_date <= month_end:
                    prorate_ratio = Decimal(str(emp_working_days)) / Decimal(str(max(1, base_working_days - month_holidays_count)))
                    eff_basic = round(Decimal(str(st.basic_salary)) * prorate_ratio, 2)
                    eff_hra = round(Decimal(str(st.hra)) * prorate_ratio, 2)
                    eff_allow = round(Decimal(str(st.allowances)) * prorate_ratio, 2)
                else:
                    eff_basic = Decimal(str(round(float(st.basic_salary), 2)))
                    eff_hra = Decimal(str(round(float(st.hra), 2)))
                    eff_allow = Decimal(str(round(float(st.allowances), 2)))

                gross = eff_basic + eff_hra + eff_allow
                per_day = gross / Decimal(str(emp_working_days)) if emp_working_days > 0 else Decimal('0.00')
                hourly_rate = (per_day / full_day_hours) if full_day_hours > 0 else Decimal('0.00')
                overtime_pay = round(hourly_rate * overtime_hours * overtime_mult, 2) if overtime_hours > 0 else Decimal('0.00')
                lop_ded = round(per_day * lop_days, 2)
                stat_ded = Decimal(str(round(st.total_fixed_deductions, 2)))

                # Evaluate active company attendance/discipline rules
                late_ded = Decimal('0.00')
                other_ded = Decimal('0.00')
                bonus_amt = Decimal('0.00')
                emp_dept_id = str(prof.department_id) if (prof and prof.department_id) else None

                for rule in active_rules:
                    if rule.applicable_department_ids:
                        allowed_depts = [str(d) for d in rule.applicable_department_ids]
                        if not emp_dept_id or emp_dept_id not in allowed_depts:
                            continue

                    metric = (rule.trigger_metric or '').upper()
                    thresh = float(rule.threshold_value or 0)
                    free_allow = int(rule.free_allowance_count or 0)
                    op = (rule.operator or 'GREATER_EQUAL').upper()

                    metric_val = 0.0
                    if metric == 'LATE_COUNT':
                        metric_val = float(late_days)
                    elif metric == 'GEOFENCE_OUT_COUNT':
                        metric_val = float(out_of_fence_days)
                    elif metric == 'ABSENT_COUNT':
                        metric_val = float(lop_days)
                    else:
                        continue

                    chargeable = max(0.0, metric_val - free_allow)
                    multiplier = 0
                    if op == 'EVERY_N' and thresh > 0:
                        multiplier = int(chargeable // thresh)
                    elif op == 'GREATER_EQUAL':
                        multiplier = 1 if chargeable >= thresh else 0
                    elif op == 'EQUALS':
                        multiplier = 1 if chargeable == thresh else 0
                    elif op == 'LESS_THAN':
                        multiplier = 1 if metric_val < thresh else 0

                    if multiplier <= 0:
                        continue

                    act_type = (rule.action_type or '').upper()
                    act_val = Decimal(str(rule.action_value or 0)) * Decimal(str(multiplier))
                    amt = Decimal('0.00')
                    if act_type == 'LOP_DAYS':
                        amt = round(per_day * act_val, 2)
                        if metric == 'LATE_COUNT':
                            late_ded += amt
                        else:
                            other_ded += amt
                    elif act_type == 'FLAT_AMOUNT':
                        amt = round(act_val, 2)
                        if metric == 'LATE_COUNT':
                            late_ded += amt
                        else:
                            other_ded += amt
                    elif act_type == 'PERCENTAGE':
                        amt = round((eff_basic * act_val) / Decimal('100'), 2)
                        if metric == 'LATE_COUNT':
                            late_ded += amt
                        else:
                            other_ded += amt
                    elif act_type == 'BONUS_AMOUNT':
                        amt = round(act_val, 2)
                        bonus_amt += amt

                    rule_breakdown.append({
                        'rule_name': rule.name,
                        'category': rule.category,
                        'metric': metric,
                        'count': metric_val,
                        'multiplier': multiplier,
                        'action_type': act_type,
                        'amount': float(amt),
                    })

                gross_earnings = round(gross + overtime_pay + bonus_amt, 2)
                total_emp_ded = round(lop_ded + late_ded + stat_ded + other_ded, 2)
                net_pay = max(Decimal('0.00'), round(gross_earnings - total_emp_ded, 2))
                due_date = _compute_payslip_due_date(year, month, st.salary_day_override or default_salary_day)

                Payslip.objects.create(
                    company=company,
                    payroll_run=run,
                    user=st.user,
                    month=month,
                    year=year,
                    currency=st.currency or company.currency,
                    working_days=emp_working_days,
                    present_days=present_days,
                    paid_leave_days=paid_leaves,
                    unpaid_leave_days=unpaid_leaves,
                    absent_days=absent_days,
                    lop_days=lop_days,
                    late_days=late_days,
                    overtime_hours=overtime_hours,
                    basic_salary=eff_basic,
                    hra=eff_hra,
                    allowances=eff_allow,
                    overtime_pay=overtime_pay,
                    bonus=bonus_amt,
                    gross_earnings=gross_earnings,
                    lop_deduction=lop_ded,
                    late_deduction=late_ded,
                    statutory_deductions=stat_ded,
                    other_deductions=other_ded,
                    net_pay=net_pay,
                    due_date=due_date,
                    paid_amount=Decimal('0.00'),
                    balance_due=net_pay,
                    payment_status='PAID' if net_pay == 0 else 'UNPAID',
                    rule_breakdown=rule_breakdown,
                    status='DRAFT',
                )
                tot_gross += gross_earnings
                tot_ded += total_emp_ded
                tot_net += net_pay

            run.total_gross = tot_gross
            run.total_deductions = tot_ded
            run.total_net_pay = tot_net
            run.save(update_fields=['total_gross', 'total_deductions', 'total_net_pay', 'updated_at'])

        return Response(PayrollRunSerializer(run).data, status=status.HTTP_201_CREATED)


class PayrollRunDetailView(views.APIView):
    permission_classes = [require_permission('payroll.process_salary')]

    def get(self, request, pk):
        run = PayrollRun.objects.filter(id=pk, company=request.user.company).first()
        if not run:
            return Response({"error": "Payroll run not found"}, status=status.HTTP_404_NOT_FOUND)
        slips = run.payslips.select_related('user', 'user__employee_profile', 'user__salary_structure').prefetch_related('payments').all()
        return Response({
            'run': PayrollRunSerializer(run).data,
            'payslips': PayslipSerializer(slips, many=True).data,
        })


class PayrollRunFinalizePayView(views.APIView):
    permission_classes = [require_permission('payroll.process_salary')]

    def post(self, request, pk):
        from apps.notifications.models import Notification
        run = PayrollRun.objects.filter(id=pk, company=request.user.company).first()
        if not run:
            return Response({"error": "Payroll run not found"}, status=status.HTTP_404_NOT_FOUND)

        action = (request.data.get('action') or '').upper()
        if action not in ('FINALIZE', 'MARK_PAID'):
            return Response({"error": "Use FINALIZE or MARK_PAID"}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            if action == 'FINALIZE':
                run.status = 'FINALIZED'
                run.finalized_at = timezone.now()
                run.save(update_fields=['status', 'finalized_at', 'updated_at'])
                run.payslips.filter(status='DRAFT').update(status='FINALIZED')
            elif action == 'MARK_PAID':
                run.status = 'PAID'
                if not run.finalized_at:
                    run.finalized_at = timezone.now()
                run.save(update_fields=['status', 'finalized_at', 'updated_at'])
                ref = request.data.get('payment_reference', '')
                mode = request.data.get('payment_mode', 'BANK_TRANSFER')
                for slip in run.payslips.select_related('user').all():
                    if slip.balance_due > 0:
                        amt = slip.balance_due
                        receipt_num = _generate_payslip_receipt_number(run.company, run.year)
                        PayslipPayment.objects.create(
                            company=run.company,
                            payslip=slip,
                            receipt_number=receipt_num,
                            amount=amt,
                            payment_mode=mode,
                            transaction_ref=ref,
                            paid_by=request.user,
                            notes='Full payroll payout',
                        )
                        slip.paid_amount = slip.net_pay
                        slip.balance_due = Decimal('0.00')
                        slip.payment_status = 'PAID'
                        slip.status = 'PAID'
                        slip.payment_reference = ref
                        slip.save(update_fields=['paid_amount', 'balance_due', 'payment_status', 'status', 'payment_reference'])
                        Notification.objects.create(
                            company=run.company,
                            user=slip.user,
                            title='Salary Credited',
                            message=(
                                f"Salary Credited: {slip.currency} {amt:,.2f} paid via "
                                f"{dict(PayslipPayment.PAYMENT_MODE_CHOICES).get(mode, mode)} "
                                f"(Receipt: {receipt_num})."
                            ),
                            notification_type='SYSTEM',
                            entity_type='payroll',
                            entity_id=str(slip.id),
                        )

        return Response(PayrollRunSerializer(run).data)


class PayslipDetailUpdateView(views.APIView):
    permission_classes = [require_permission('payroll.process_salary')]

    def patch(self, request, pk):
        slip = Payslip.objects.filter(id=pk, company=request.user.company).select_related('payroll_run').first()
        if not slip:
            return Response({"error": "Payslip not found"}, status=status.HTTP_404_NOT_FOUND)
        if slip.payroll_run.status != 'DRAFT':
            return Response({"error": "Only DRAFT payslips can be adjusted."}, status=status.HTTP_400_BAD_REQUEST)

        for field in ('overtime_pay', 'bonus', 'other_deductions'):
            if field in request.data:
                setattr(slip, field, Decimal(str(request.data[field] or 0)))
        if 'notes' in request.data:
            slip.notes = str(request.data['notes'] or '')
        if 'due_date' in request.data and request.data['due_date']:
            slip.due_date = request.data['due_date']

        slip.gross_earnings = round(
            slip.basic_salary + slip.hra + slip.allowances + slip.overtime_pay + slip.bonus,
            2,
        )
        total_ded = round(
            slip.lop_deduction + slip.late_deduction + slip.statutory_deductions + slip.other_deductions,
            2,
        )
        slip.net_pay = max(Decimal('0.00'), round(slip.gross_earnings - total_ded, 2))
        slip.balance_due = max(Decimal('0.00'), round(slip.net_pay - slip.paid_amount, 2))
        slip.payment_status = 'PAID' if slip.balance_due == 0 else ('PARTIAL' if slip.paid_amount > 0 else 'UNPAID')
        slip.save()

        run = slip.payroll_run
        all_slips = run.payslips.all()
        run.total_gross = sum((s.gross_earnings for s in all_slips), Decimal('0.00'))
        run.total_net_pay = sum((s.net_pay for s in all_slips), Decimal('0.00'))
        run.total_deductions = sum(
            (s.lop_deduction + s.late_deduction + s.statutory_deductions + s.other_deductions for s in all_slips),
            Decimal('0.00'),
        )
        run.save(update_fields=['total_gross', 'total_deductions', 'total_net_pay', 'updated_at'])
        return Response(PayslipSerializer(slip).data)


class PayslipPayInstallmentView(views.APIView):
    permission_classes = [require_permission('payroll.process_salary')]

    def post(self, request, pk):
        from apps.notifications.models import Notification
        slip = Payslip.objects.filter(id=pk, company=request.user.company).select_related('payroll_run', 'user').first()
        if not slip:
            return Response({"error": "Payslip not found"}, status=status.HTTP_404_NOT_FOUND)

        try:
            amount = Decimal(str(request.data.get('amount') or 0))
        except Exception:
            return Response({"error": "Invalid payment amount"}, status=status.HTTP_400_BAD_REQUEST)

        if amount <= 0:
            return Response({"error": "Payment amount must be greater than 0."}, status=status.HTTP_400_BAD_REQUEST)
        if amount > slip.balance_due:
            return Response(
                {"error": f"Payment amount ({amount}) exceeds remaining balance due ({slip.balance_due})."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        mode = request.data.get('payment_mode') or 'BANK_TRANSFER'
        valid_modes = dict(PayslipPayment.PAYMENT_MODE_CHOICES)
        if mode not in valid_modes:
            return Response({"error": "Invalid payment mode."}, status=status.HTTP_400_BAD_REQUEST)

        ref = str(request.data.get('transaction_ref') or '')
        notes = str(request.data.get('notes') or '')

        with transaction.atomic():
            receipt_num = _generate_payslip_receipt_number(slip.company, slip.year)
            payment = PayslipPayment.objects.create(
                company=slip.company,
                payslip=slip,
                receipt_number=receipt_num,
                amount=amount,
                payment_mode=mode,
                transaction_ref=ref,
                paid_by=request.user,
                notes=notes,
            )
            slip.paid_amount = round(slip.paid_amount + amount, 2)
            slip.balance_due = max(Decimal('0.00'), round(slip.net_pay - slip.paid_amount, 2))
            slip.payment_status = 'PAID' if slip.balance_due == 0 else 'PARTIAL'
            if slip.balance_due == 0:
                slip.status = 'PAID'
            elif slip.status == 'DRAFT':
                slip.status = 'FINALIZED'
            slip.payment_reference = ref or receipt_num
            slip.save()

            run = slip.payroll_run
            if not run.payslips.filter(balance_due__gt=0).exists():
                run.status = 'PAID'
                if not run.finalized_at:
                    run.finalized_at = timezone.now()
                run.save(update_fields=['status', 'finalized_at', 'updated_at'])

            Notification.objects.create(
                company=slip.company,
                user=slip.user,
                title='Salary Credited',
                message=(
                    f"Salary Credited: {slip.currency} {amount:,.2f} paid via {valid_modes[mode]} "
                    f"(Remaining Balance: {slip.currency} {slip.balance_due:,.2f})."
                ),
                notification_type='SYSTEM',
                entity_type='payroll',
                entity_id=str(slip.id),
            )

        return Response({
            'payment': PayslipPaymentSerializer(payment).data,
            'payslip': PayslipSerializer(slip).data,
        }, status=status.HTTP_201_CREATED)


class PayrollReminderCheckView(views.APIView):
    permission_classes = [require_permission('payroll.process_salary')]

    def get(self, request):
        dispatched = dispatch_payroll_reminders(company=request.user.company)
        return Response({'dispatched': dispatched})

    def post(self, request):
        dispatched = dispatch_payroll_reminders(company=request.user.company)
        return Response({'dispatched': dispatched})


class MyPayslipsView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from django.db.models import Q
        company = request.user.company
        if not company:
            return Response([])
        slips = (
            Payslip.objects.filter(company=company, user=request.user)
            .filter(Q(status__in=['FINALIZED', 'PAID']) | Q(paid_amount__gt=0))
            .select_related('user', 'user__employee_profile', 'user__salary_structure')
            .prefetch_related('payments')
        )
        return Response(PayslipSerializer(slips, many=True).data)

