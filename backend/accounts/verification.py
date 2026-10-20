"""Bind email verification to a pending account in the server-side session."""

import time
from uuid import UUID

from .exceptions import APIProblem
from .models import User


PENDING_VERIFICATION_KEY = "pending_verification"
PENDING_VERIFICATION_TTL_SECONDS = 30 * 60


def clear_pending_verification(request):
    request.session.pop(PENDING_VERIFICATION_KEY, None)


def bind_pending_verification(request, user):
    if not user.is_active or user.email_verified_at is not None:
        clear_pending_verification(request)
        return
    # Rotate the key without changing an existing authenticated session's age.
    request.session.cycle_key()
    request.session[PENDING_VERIFICATION_KEY] = {
        "user_id": str(user.pk),
        "email": user.email,
        "started_at": time.time(),
    }


def pending_verification_user(request, email):
    pending = request.session.get(PENDING_VERIFICATION_KEY)
    valid = isinstance(pending, dict)
    user = None
    if valid:
        started_at = pending.get("started_at")
        valid = (
            isinstance(started_at, (int, float))
            and 0 <= time.time() - started_at < PENDING_VERIFICATION_TTL_SECONDS
            and isinstance(pending.get("email"), str)
        )
    if valid:
        try:
            user_id = UUID(pending.get("user_id", ""))
        except (ValueError, TypeError, AttributeError):
            valid = False
        else:
            user = User.objects.filter(
                pk=user_id, email=pending["email"], is_active=True,
                email_verified_at__isnull=True,
            ).first()
            valid = user is not None
    if not valid:
        clear_pending_verification(request)
        raise APIProblem(
            400, "verification_required",
            "Бүртгүүлэх эсвэл нэвтрэх хэсгээс мэйл баталгаажуулалтыг дахин эхлүүлнэ үү.",
        )
    if User.objects.normalize_email(email) != user.email:
        raise APIProblem(
            400, "verification_email_mismatch",
            "Бүртгүүлсэн мэйл хаягаа өөрчлөх боломжгүй. Тухайн мэйлд ирсэн кодыг оруулна уу.",
        )
    return user
