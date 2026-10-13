from django.utils import timezone
from rest_framework.authentication import BaseAuthentication, get_authorization_header
from rest_framework.exceptions import AuthenticationFailed

from .models import AuthSession
from .services import hash_token


class BearerAuthentication(BaseAuthentication):
    def authenticate(self, request):
        parts = get_authorization_header(request).split()
        if not parts or parts[0].lower() != b"bearer":
            return None
        if len(parts) != 2 or len(parts[1]) > 128:
            raise AuthenticationFailed("Invalid Bearer token.")
        try:
            token = parts[1].decode("ascii")
        except UnicodeDecodeError:
            raise AuthenticationFailed("Invalid Bearer token.") from None
        now = timezone.now()
        session = AuthSession.objects.select_related("user", "trusted_device").filter(
            token_hash=hash_token(token), expires_at__gt=now,
            user__is_active=True, user__email_verified=True,
        ).first()
        if session is None:
            raise AuthenticationFailed("Token is invalid or expired.")
        if session.trusted_device and session.trusted_device.expires_at <= now:
            raise AuthenticationFailed("Remembered device has expired. Sign in again.")
        AuthSession.objects.filter(pk=session.pk).update(last_seen_at=now)
        return session.user, session

    def authenticate_header(self, request):
        return "Bearer"
