import os
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model

User = get_user_model()

class Command(BaseCommand):
    help = 'Securely creates the initial Super Admin user'

    def add_arguments(self, parser):
        parser.add_argument('--email', type=str, help='Admin email address')
        parser.add_argument('--password', type=str, help='Admin password')
        parser.add_argument('--first-name', type=str, default='Super', help='First name')
        parser.add_argument('--last-name', type=str, default='Admin', help='Last name')

    def handle(self, *args, **options):
        email = options.get('email') or os.environ.get('SUPERADMIN_EMAIL', 'superadmin@telecaller.crm')
        password = options.get('password') or os.environ.get('SUPERADMIN_PASSWORD', 'SuperAdmin123!')
        first_name = options.get('first_name', 'Super')
        last_name = options.get('last_name', 'Admin')

        if User.objects.filter(email=email).exists():
            self.stdout.write(self.style.WARNING(f"Super Admin with email '{email}' already exists."))
            return

        user = User.objects.create_superuser(
            email=email,
            password=password,
            first_name=first_name,
            last_name=last_name,
            role='SUPER_ADMIN'
        )
        self.stdout.write(self.style.SUCCESS(f"Successfully created Super Admin: {user.email}"))
