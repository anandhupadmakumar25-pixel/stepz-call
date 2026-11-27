from rest_framework import serializers
from apps.accounts.models import (
    CompanyHoliday,
    LeaveType,
    LeaveBalance,
    LeaveRequest,
    AttendanceRegularization,
    EmployeeSalaryStructure,
    PayrollRun,
    Payslip,
    PayslipPayment,
)


class CompanyHolidaySerializer(serializers.ModelSerializer):
    class Meta:
        model = CompanyHoliday
        fields = ['id', 'name', 'date', 'is_optional', 'description', 'created_at']
        read_only_fields = ['id', 'created_at']


class LeaveTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = LeaveType
        fields = ['id', 'name', 'code', 'annual_quota', 'is_paid', 'is_active', 'created_at']
        read_only_fields = ['id', 'created_at']


class LeaveBalanceSerializer(serializers.ModelSerializer):
    leave_type_name = serializers.CharField(source='leave_type.name', read_only=True)
    leave_type_code = serializers.CharField(source='leave_type.code', read_only=True)
    is_paid = serializers.BooleanField(source='leave_type.is_paid', read_only=True)
    remaining = serializers.FloatField(read_only=True)

    class Meta:
        model = LeaveBalance
        fields = [
            'id', 'user', 'leave_type', 'leave_type_name', 'leave_type_code',
            'is_paid', 'year', 'allocated', 'used', 'remaining',
        ]
        read_only_fields = ['id', 'remaining']


class LeaveRequestSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.full_name', read_only=True)
    user_email = serializers.CharField(source='user.email', read_only=True)
    leave_type_name = serializers.CharField(source='leave_type.name', read_only=True)
    leave_type_code = serializers.CharField(source='leave_type.code', read_only=True)
    is_paid = serializers.BooleanField(source='leave_type.is_paid', read_only=True)
    reviewed_by_name = serializers.CharField(source='reviewed_by.full_name', read_only=True, default='')

    class Meta:
        model = LeaveRequest
        fields = [
            'id', 'user', 'user_name', 'user_email',
            'leave_type', 'leave_type_name', 'leave_type_code', 'is_paid',
            'start_date', 'end_date', 'is_half_day', 'days_count',
            'reason', 'status', 'reviewed_by', 'reviewed_by_name',
            'reviewed_at', 'review_notes', 'created_at',
        ]
        read_only_fields = ['id', 'user', 'status', 'reviewed_by', 'reviewed_at', 'created_at']

    def validate(self, attrs):
        start = attrs.get('start_date')
        end = attrs.get('end_date')
        if start and end and end < start:
            raise serializers.ValidationError({'end_date': 'End date must be on or after start date.'})
        return attrs


class AttendanceRegularizationSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.full_name', read_only=True)
    reviewed_by_name = serializers.CharField(source='reviewed_by.full_name', read_only=True, default='')

    class Meta:
        model = AttendanceRegularization
        fields = [
            'id', 'user', 'user_name', 'date',
            'requested_check_in', 'requested_check_out',
            'reason', 'status', 'reviewed_by', 'reviewed_by_name',
            'reviewed_at', 'review_notes', 'created_at',
        ]
        read_only_fields = ['id', 'user', 'status', 'reviewed_by', 'reviewed_at', 'created_at']


class EmployeeSalaryStructureSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.full_name', read_only=True)
    user_email = serializers.CharField(source='user.email', read_only=True)
    gross_salary = serializers.FloatField(read_only=True)
    total_fixed_deductions = serializers.FloatField(read_only=True)

    class Meta:
        model = EmployeeSalaryStructure
        fields = [
            'id', 'user', 'user_name', 'user_email', 'currency',
            'basic_salary', 'hra', 'allowances',
            'pf_deduction', 'esi_deduction', 'tax_deduction',
            'gross_salary', 'total_fixed_deductions',
            'bank_name', 'account_number', 'ifsc_iban', 'salary_day_override',
        ]
        read_only_fields = ['id', 'gross_salary', 'total_fixed_deductions']


class PayslipPaymentSerializer(serializers.ModelSerializer):
    payment_mode_display = serializers.CharField(source='get_payment_mode_display', read_only=True)
    paid_by_name = serializers.CharField(source='paid_by.full_name', read_only=True, default='')

    class Meta:
        model = PayslipPayment
        fields = [
            'id', 'payslip', 'receipt_number', 'amount',
            'payment_mode', 'payment_mode_display', 'transaction_ref',
            'paid_at', 'paid_by', 'paid_by_name', 'notes',
        ]
        read_only_fields = ['id', 'payslip', 'receipt_number', 'paid_at', 'paid_by']


class PayslipSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.full_name', read_only=True)
    user_email = serializers.CharField(source='user.email', read_only=True)
    user_department = serializers.SerializerMethodField()
    user_designation = serializers.SerializerMethodField()
    joining_date = serializers.SerializerMethodField()
    bank_name = serializers.SerializerMethodField()
    account_number = serializers.SerializerMethodField()
    ifsc_iban = serializers.SerializerMethodField()
    payments = PayslipPaymentSerializer(many=True, read_only=True)

    class Meta:
        model = Payslip
        fields = [
            'id', 'payroll_run', 'user', 'user_name', 'user_email',
            'user_department', 'user_designation', 'joining_date',
            'bank_name', 'account_number', 'ifsc_iban',
            'month', 'year', 'currency',
            'working_days', 'present_days', 'paid_leave_days',
            'unpaid_leave_days', 'absent_days', 'lop_days',
            'late_days', 'overtime_hours',
            'basic_salary', 'hra', 'allowances', 'overtime_pay', 'bonus', 'gross_earnings',
            'lop_deduction', 'late_deduction', 'statutory_deductions', 'other_deductions', 'net_pay',
            'due_date', 'paid_amount', 'balance_due', 'payment_status',
            'rule_breakdown', 'notes', 'payments',
            'status', 'payment_reference', 'created_at',
        ]
        read_only_fields = ['id', 'payroll_run', 'user', 'month', 'year', 'created_at']

    def get_user_department(self, obj):
        prof = getattr(obj.user, 'employee_profile', None)
        return prof.department.name if prof and prof.department else ''

    def get_user_designation(self, obj):
        prof = getattr(obj.user, 'employee_profile', None)
        return getattr(prof, 'designation', '') if prof else ''

    def get_joining_date(self, obj):
        prof = getattr(obj.user, 'employee_profile', None)
        return prof.joining_date.isoformat() if prof and prof.joining_date else None

    def get_bank_name(self, obj):
        st = getattr(obj.user, 'salary_structure', None)
        return st.bank_name if st else ''

    def get_account_number(self, obj):
        st = getattr(obj.user, 'salary_structure', None)
        return st.account_number if st else ''

    def get_ifsc_iban(self, obj):
        st = getattr(obj.user, 'salary_structure', None)
        return st.ifsc_iban if st else ''


class PayrollRunSerializer(serializers.ModelSerializer):
    generated_by_name = serializers.CharField(source='generated_by.full_name', read_only=True, default='')
    payslip_count = serializers.IntegerField(source='payslips.count', read_only=True)
    total_paid = serializers.SerializerMethodField()
    total_balance_due = serializers.SerializerMethodField()

    class Meta:
        model = PayrollRun
        fields = [
            'id', 'month', 'year', 'status',
            'generated_by', 'generated_by_name', 'finalized_at',
            'total_gross', 'total_deductions', 'total_net_pay',
            'total_paid', 'total_balance_due',
            'payslip_count', 'created_at',
        ]
        read_only_fields = ['id', 'generated_by', 'finalized_at', 'created_at']

    def get_total_paid(self, obj):
        return float(sum((p.paid_amount for p in obj.payslips.all()), 0))

    def get_total_balance_due(self, obj):
        return float(sum((p.balance_due for p in obj.payslips.all()), 0))

