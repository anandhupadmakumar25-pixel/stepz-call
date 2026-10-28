import time
from django.core.management.base import BaseCommand
from apps.callbacks.services.reminder_service import CallbackReminderService

class Command(BaseCommand):
    help = 'Runs durable background worker to process due and overdue callbacks'

    def add_arguments(self, parser):
        parser.add_argument('--interval', type=int, default=60, help='Polling interval in seconds (default: 60)')
        parser.add_argument('--once', action='store_true', help='Run once and exit')

    def handle(self, *args, **options):
        interval = options.get('interval', 60)
        once = options.get('once', False)

        self.stdout.write(self.style.NOTICE(f"Starting callback reminder worker (interval: {interval}s)..."))

        while True:
            try:
                res = CallbackReminderService.process_due_and_overdue_callbacks()
                if res['marked_due'] > 0 or res['marked_overdue'] > 0:
                    self.stdout.write(self.style.SUCCESS(
                        f"Processed callbacks: {res['marked_due']} marked DUE, {res['marked_overdue']} marked OVERDUE at {res['checked_at']}"
                    ))
            except Exception as e:
                self.stdout.write(self.style.ERROR(f"Error checking callbacks: {e}"))

            if once:
                break
            time.sleep(interval)
