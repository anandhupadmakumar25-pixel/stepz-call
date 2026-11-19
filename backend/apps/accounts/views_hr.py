import calendar
from datetime import datetime, timedelta
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
)
from apps.accounts.serializers_hr import (
    CompanyHolidaySerializer,
    LeaveTypeSerializer,
    LeaveBalanceSerializer,
    LeaveRequestSerializer,
    AttendanceRegularizationSerializer,
    EmployeeSalaryStructureSerializer,
    PayrollRunSerializer,
    PayslipSerializer,
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

        days_count = Decimal('0.5') if is_half else Decimal(str((end - start).days + 1))

        # Check leave balance if paid
        if lt.is_paid:
            _ensure_leave_balances_for_user(request.user, start.year)
            bal = LeaveBalance.objects.filter(user=request.user, leave_type=lt, year=start.year).first()
            if bal and bal.remaining < float(days_count):
                return Response(
                    {"error": f"Insufficient {lt.name} balance. Remaining: {bal.remaining} days."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        req = serializer.save(company=company, user=request.user, days_count=days_count)
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


class PayrollRunListGenerateView(views.APIView):
    permission_classes = [require_permission('payroll.process_salary')]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response([])
        runs = PayrollRun.objects.filter(company=company).select_related('generated_by')
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
        policy = getattr(company, 'payroll_policy', None)
        calc_basis = policy.pay_calculation_basis if policy else 'CALENDAR_DAYS'
        working_days = 26 if calc_basis == 'FIXED_26_DAYS' else days_in_month

        structures = EmployeeSalaryStructure.objects.filter(company=company, user__is_active=True).select_related('user')
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

            for st in structures:
                att_qs = AttendanceRecord.objects.filter(company=company, user=st.user, date__year=year, date__month=month)
                present_days = Decimal(str(att_qs.filter(status__in=['PRESENT', 'LATE', 'OUT_OF_FENCE']).count()))
                half_days = Decimal(str(att_qs.filter(status='HALF_DAY').count())) * Decimal('0.5')
                present_days += half_days
                late_days = att_qs.filter(status='LATE').count()

                # Paid & LOP leaves in this month
                paid_leaves = Decimal('0.0')
                lop_days = Decimal('0.0')
                approved_leaves = LeaveRequest.objects.filter(
                    company=company, user=st.user, status='APPROVED',
                    start_date__year=year, start_date__month=month,
                ).select_related('leave_type')
                for lr in approved_leaves:
                    if lr.leave_type.is_paid:
                        paid_leaves += Decimal(str(lr.days_count))
                    else:
                        lop_days += Decimal(str(lr.days_count))

                gross = Decimal(str(round(st.gross_salary, 2)))
                per_day = gross / Decimal(str(working_days)) if working_days > 0 else Decimal('0.00')
                lop_ded = round(per_day * lop_days, 2)
                stat_ded = Decimal(str(round(st.total_fixed_deductions, 2)))
                net_pay = max(Decimal('0.00'), round(gross - lop_ded - stat_ded, 2))

                Payslip.objects.create(
                    company=company,
                    payroll_run=run,
                    user=st.user,
                    month=month,
                    year=year,
                    currency=st.currency or company.currency,
                    working_days=working_days,
                    present_days=present_days,
                    paid_leave_days=paid_leaves,
                    lop_days=lop_days,
                    late_days=late_days,
                    basic_salary=st.basic_salary,
                    hra=st.hra,
                    allowances=st.allowances,
                    gross_earnings=gross,
                    lop_deduction=lop_ded,
                    statutory_deductions=stat_ded,
                    net_pay=net_pay,
                    status='DRAFT',
                )
                tot_gross += gross
                tot_ded += (lop_ded + stat_ded)
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
        slips = run.payslips.select_related('user').all()
        return Response({
            'run': PayrollRunSerializer(run).data,
            'payslips': PayslipSerializer(slips, many=True).data,
        })


class PayrollRunFinalizePayView(views.APIView):
    permission_classes = [require_permission('payroll.process_salary')]

    def post(self, request, pk):
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
                run.payslips.update(status='FINALIZED')
            elif action == 'MARK_PAID':
                run.status = 'PAID'
                if not run.finalized_at:
                    run.finalized_at = timezone.now()
                run.save(update_fields=['status', 'finalized_at', 'updated_at'])
                ref = request.data.get('payment_reference', '')
                run.payslips.update(status='PAID', payment_reference=ref)

        return Response(PayrollRunSerializer(run).data)


class MyPayslipsView(views.APIView):
    permission_classes = [require_permission('payroll.view_own_payslip')]

    def get(self, request):
        company = request.user.company
        if not company:
            return Response([])
        slips = Payslip.objects.filter(
            company=company,
            user=request.user,
            status__in=['FINALIZED', 'PAID'],
        ).select_related('user')
        return Response(PayslipSerializer(slips, many=True).data)

