from datetime import timedelta

from django.core.management.base import BaseCommand, CommandError
from django.db.models import Q
from django.utils import timezone

from accounts.models import AuthSession, EmailChallenge, TrustedDevice


class Command(BaseCommand):
    help = "Delete expired sessions/devices and old email verification challenges."

    def add_arguments(self, parser):
        parser.add_argument(
            "--days", type=int, default=7,
            help="Retain expired email challenges for this many days (default: 7).",
        )

    def handle(self, *args, **options):
        days = options["days"]
        if days < 0:
            raise CommandError("--days must be zero or greater.")
        now = timezone.now()
        sessions, _ = AuthSession.objects.filter(
            Q(expires_at__lte=now) | Q(trusted_device__expires_at__lte=now)
        ).delete()
        devices, _ = TrustedDevice.objects.filter(expires_at__lte=now).delete()
        challenges, _ = EmailChallenge.objects.filter(expires_at__lte=now - timedelta(days=days)).delete()
        self.stdout.write(self.style.SUCCESS(
            f"Deleted {sessions} expired sessions, {devices} expired devices and {challenges} old challenges."
        ))
