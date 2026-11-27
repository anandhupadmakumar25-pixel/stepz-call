from django.core.management.base import BaseCommand
from apps.accounts.views_hr import dispatch_payroll_reminders


class Command(BaseCommand):
    help = 'Dispatch deduplicated upcoming payday and overdue salary balance reminders to Company Admins.'

    def handle(self, *args, **options):
        count = dispatch_payroll_reminders()
        self.stdout.write(self.style.SUCCESS(f'Dispatched {count} payroll reminder notification(s).'))
