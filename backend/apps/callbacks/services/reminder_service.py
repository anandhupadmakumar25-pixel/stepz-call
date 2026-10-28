from datetime import timedelta
from django.utils import timezone
from apps.callbacks.models import Callback
from apps.notifications.models import Notification

class CallbackReminderService:
    @staticmethod
    def process_due_and_overdue_callbacks() -> dict:
        """
        Scans all pending callbacks, transitions status, and issues notifications.
        Durable and retry-safe: prevents duplicate notifications via reminder_sent flag or checking existing alerts.
        """
        now = timezone.now()
        due_threshold = now + timedelta(minutes=15)
        overdue_threshold = now - timedelta(minutes=30)

        # 1. Transition scheduled callbacks that are due now or within 15 minutes
        due_callbacks = Callback.objects.filter(
            status='SCHEDULED',
            scheduled_at__lte=due_threshold,
            scheduled_at__gt=overdue_threshold
        )
        due_count = 0
        for cb in due_callbacks:
            cb.status = 'DUE'
            cb.save(update_fields=['status'])
            due_count += 1

            if not cb.reminder_sent:
                Notification.objects.create(
                    company=cb.company,
                    user=cb.assigned_employee,
                    title='Callback Due',
                    message=f'Callback with {cb.lead.full_name} ({cb.lead.normalized_phone}) is due now.',
                    notification_type='CALLBACK_REMINDER',
                    entity_type='callback',
                    entity_id=str(cb.id)
                )
                cb.reminder_sent = True
                cb.save(update_fields=['reminder_sent'])

        # 2. Transition callbacks that are overdue (scheduled time was more than 30 mins ago and not completed)
        overdue_callbacks = Callback.objects.filter(
            status__in=['SCHEDULED', 'DUE'],
            scheduled_at__lte=overdue_threshold
        )
        overdue_count = 0
        for cb in overdue_callbacks:
            cb.status = 'OVERDUE'
            cb.save(update_fields=['status'])
            overdue_count += 1

            # Check if overdue alert already exists
            already_notified = Notification.objects.filter(
                user=cb.assigned_employee,
                notification_type='CALLBACK_OVERDUE',
                entity_id=str(cb.id)
            ).exists()

            if not already_notified:
                Notification.objects.create(
                    company=cb.company,
                    user=cb.assigned_employee,
                    title='Callback Overdue!',
                    message=f'Callback with {cb.lead.full_name} ({cb.lead.normalized_phone}) is overdue.',
                    notification_type='CALLBACK_OVERDUE',
                    entity_type='callback',
                    entity_id=str(cb.id)
                )

        return {
            'marked_due': due_count,
            'marked_overdue': overdue_count,
            'checked_at': now.isoformat()
        }
