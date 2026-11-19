from django.db import migrations
from django.contrib.auth.hashers import make_password


def reset_for_beta(apps, schema_editor):
    # Clear all demo/test tenant data in dependency-safe order (keep Plan records)
    models_to_clear = [
        ('notifications', 'Notification'),
        ('callbacks', 'Callback'),
        ('calls', 'CallRecording'),
        ('calls', 'CallAttempt'),
        ('billing', 'ReceiptVoucher'),
        ('billing', 'Invoice'),
        ('billing', 'Quotation'),
        ('billing', 'DocumentTemplate'),
        ('billing', 'Product'),
        ('leads', 'LeadAssignmentHistory'),
        ('leads', 'PermanentPhoneNumberRegistry'),
        ('leads', 'CallingTask'),
        ('leads', 'Lead'),
        ('leads', 'ImportBatch'),
        ('leads', 'LeadCategory'),
        ('leads', 'Branch'),
        ('accounts', 'PermissionAuditLog'),
        ('accounts', 'SectionDelegation'),
        ('accounts', 'Payslip'),
        ('accounts', 'PayrollRun'),
        ('accounts', 'EmployeeSalaryStructure'),
        ('accounts', 'AttendanceRegularization'),
        ('accounts', 'LeaveRequest'),
        ('accounts', 'CompanyHoliday'),
        ('accounts', 'LeaveType'),
        ('accounts', 'FieldVisit'),
        ('accounts', 'AttendanceRecord'),
        ('accounts', 'EmployeeProfile'),
        ('accounts', 'CustomRole'),
        ('accounts', 'Department'),
        ('accounts', 'Team'),
        ('accounts', 'Invitation'),
        ('companies', 'FeatureRequest'),
        ('companies', 'CompanySubscriptionHistory'),
        ('companies', 'CompanyRenewalRequest'),
        ('companies', 'CompanyCustomRule'),
        ('companies', 'CompanyPayrollPolicy'),
        ('companies', 'Company'),
        ('accounts', 'User'),
    ]

    for app_label, model_name in models_to_clear:
        try:
            model = apps.get_model(app_label, model_name)
            model.objects.all().delete()
        except LookupError:
            pass

    User = apps.get_model('accounts', 'User')
    User.objects.create(
        email='masteradmin@stepz.com',
        username='masteradmin',
        first_name='Master',
        last_name='Admin',
        role='MASTER_ADMIN',
        is_staff=True,
        is_superuser=True,
        is_active=True,
        password=make_password('Stepz@2026'),
    )


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0008_attendanceregularization_employeesalarystructure_and_more'),
        ('billing', '0006_invoice_template_snapshot_and_more'),
        ('callbacks', '0001_initial'),
        ('calls', '0003_alter_callrecording_source'),
        ('companies', '0010_featurerequest'),
        ('leads', '0008_callingtask_completion_report_and_more'),
        ('notifications', '0001_initial'),
    ]

    operations = [
        migrations.RunPython(reset_for_beta, migrations.RunPython.noop),
    ]
