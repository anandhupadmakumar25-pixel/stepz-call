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
            'bank_name', 'account_number', 'ifsc_iban',
        ]
        read_only_fields = ['id', 'gross_salary', 'total_fixed_deductions']


class PayslipSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.full_name', read_only=True)
    user_email = serializers.CharField(source='user.email', read_only=True)

    class Meta:
        model = Payslip
        fields = [
            'id', 'payroll_run', 'user', 'user_name', 'user_email',
            'month', 'year', 'currency',
            'working_days', 'present_days', 'paid_leave_days', 'lop_days',
            'late_days', 'overtime_hours',
            'basic_salary', 'hra', 'allowances', 'overtime_pay', 'bonus', 'gross_earnings',
            'lop_deduction', 'late_deduction', 'statutory_deductions', 'other_deductions', 'net_pay',
            'status', 'payment_reference', 'created_at',
        ]
        read_only_fields = ['id', 'payroll_run', 'user', 'month', 'year', 'created_at']


class PayrollRunSerializer(serializers.ModelSerializer):
    generated_by_name = serializers.CharField(source='generated_by.full_name', read_only=True, default='')
    payslip_count = serializers.IntegerField(source='payslips.count', read_only=True)

    class Meta:
        model = PayrollRun
        fields = [
            'id', 'month', 'year', 'status',
            'generated_by', 'generated_by_name', 'finalized_at',
            'total_gross', 'total_deductions', 'total_net_pay',
            'payslip_count', 'created_at',
        ]
        read_only_fields = ['id', 'generated_by', 'finalized_at', 'created_at']

