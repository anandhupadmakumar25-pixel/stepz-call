from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta
from apps.companies.models import Company

class Command(BaseCommand):
    help = 'Check all tenant companies for plan expiration and auto-suspend overdue tenants'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Simulate checking without saving suspended status',
        )

    def handle(self, *args, **options):
        dry_run = options.get('dry_run', False)
        now = timezone.now()
        self.stdout.write(f"[{now.strftime('%Y-%m-%d %H:%M:%S')}] Checking tenant plan expiries...")

        companies = Company.objects.filter(
            plan_expires_at__isnull=False
        ).exclude(status='SUSPENDED')

        suspended_count = 0
        active_count = 0

        for company in companies:
            cutoff = company.plan_expires_at + timedelta(days=company.grace_period_days)
            if now > cutoff:
                self.stdout.write(
                    self.style.WARNING(
                        f"Tenant '{company.name}' (ID: {company.id}) expired on {company.plan_expires_at}. Marking SUSPENDED."
                    )
                )
                if not dry_run:
                    company.status = 'SUSPENDED'
                    company.save(update_fields=['status'])
                suspended_count += 1
            else:
                days_left = (company.plan_expires_at - now).days
                if days_left <= 7:
                    self.stdout.write(
                        self.style.NOTICE(
                            f"Tenant '{company.name}' will expire in {days_left} days ({company.plan_expires_at})."
                        )
                    )
                active_count += 1

        action_word = "Would suspend" if dry_run else "Suspended"
        self.stdout.write(
            self.style.SUCCESS(
                f"Scan complete. {action_word} {suspended_count} overdue tenants. {active_count} tenants remain active."
            )
        )

