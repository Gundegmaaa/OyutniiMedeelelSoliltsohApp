"""Email verification and revocable, opaque authentication credentials."""

import hashlib
import math
import secrets
from datetime import timedelta

from django.conf import settings
from django.contrib.auth.hashers import make_password
from django.core.exceptions import ValidationError
from django.core.mail import send_mail
from django.db import IntegrityError, transaction
from django.utils import timezone
from django.utils.crypto import salted_hmac

from .models import AuthSession, EmailChallenge, TrustedDevice, User


class APIError(Exception):
    def __init__(self, code, message, status=400, retry_after=None):
        super().__init__(message)
        self.code = code
        self.message = message
        self.status = status
        self.retry_after = retry_after


def hash_token(token):
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _code_hash(challenge_id, code):
    return salted_hmac(
        "accounts.email-verification", f"{challenge_id}:{code}", algorithm="sha256"
    ).hexdigest()


def _seconds(name, default):
    return int(getattr(settings, name, default))


def _send_code(challenge, code):
    minutes = max(1, math.ceil(_seconds("AUTH_CODE_TTL_SECONDS", 600) / 60))
    action = "бүртгэлээ баталгаажуулах" if challenge.purpose == "register" else "нэвтрэх"
    try:
        delivered = send_mail(
            subject="Оюутны мэдээлэл солилцох апп — баталгаажуулах код",
            message=(
                f"Таны {action} код: {code}\n\n"
                f"Код {minutes} минутын хугацаанд хүчинтэй. "
                "Кодоо бусадтай бүү хуваалцаарай.\n"
                "Та энэ хүсэлтийг илгээгээгүй бол энэ мэйлийг үл тоомсорлож болно."
            ),
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[challenge.email],
            fail_silently=False,
        )
        if delivered != 1:
            raise RuntimeError("Email was not delivered.")
    except Exception:
        # Provider exceptions may contain credentials or account details.
        raise APIError(
            "email_unavailable", "Баталгаажуулах мэйл илгээх боломжгүй байна. Дахин оролдоно уу.", 503
        ) from None


def _create_challenge(purpose, email, **fields):
    code = f"{secrets.randbelow(1_000_000):06d}"
    # Creating a challenge and delivering its email are one transaction. Failed
    # delivery leaves neither a usable new challenge nor invalidates an old one.
    with transaction.atomic():
        if purpose == EmailChallenge.Purpose.LOGIN:
            # All login mutations acquire the user before credentials/challenges.
            user = User.objects.select_for_update().get(pk=fields["user"].pk)
            if not user.is_active or not user.email_verified:
                raise APIError("invalid_credentials", "Нэвтрэх боломжгүй бүртгэл байна.", 401)
            fields["user"] = user
        elif User.objects.filter(email=email).exists():
            raise APIError("email_exists", "Энэ мэйл хаяг бүртгэлтэй байна.", 409)
        previous = (
            EmailChallenge.objects.select_for_update()
            .filter(email=email, purpose=purpose)
            .order_by("-last_sent_at")
            .first()
        )
        now = timezone.now()
        if previous:
            wait = _seconds("AUTH_CODE_RESEND_SECONDS", 60) - (now - previous.last_sent_at).total_seconds()
            if wait > 0:
                raise APIError("resend_too_soon", "Код дахин авахын өмнө түр хүлээнэ үү.", 429, math.ceil(wait))
        challenge = EmailChallenge(
            purpose=purpose,
            email=email,
            last_sent_at=now,
            expires_at=now + timedelta(seconds=_seconds("AUTH_CODE_TTL_SECONDS", 600)),
            **fields,
        )
        challenge.code_hash = _code_hash(challenge.id, code)
        EmailChallenge.objects.filter(
            email=email, purpose=purpose, consumed_at__isnull=True
        ).update(consumed_at=now, password_hash="", code_hash="")
        challenge.save()
        _send_code(challenge, code)
    return challenge


def register(email, password, full_name=""):
    email = User.objects.normalize_email(email)
    if User.objects.filter(email=email).exists():
        raise APIError("email_exists", "Энэ мэйл хаяг бүртгэлтэй байна.", 409)
    return _create_challenge(
        EmailChallenge.Purpose.REGISTER,
        email,
        password_hash=make_password(password),
        full_name=full_name.strip(),
    )


def create_session(user, trusted_device=None):
    if not user.is_active or not user.email_verified:
        raise APIError("invalid_credentials", "Нэвтрэх мэдээлэл буруу байна.", 401)
    token = secrets.token_urlsafe(32)
    session = AuthSession.objects.create(
        user=user,
        token_hash=hash_token(token),
        trusted_device=trusted_device,
        expires_at=timezone.now()
        + timedelta(seconds=_seconds("AUTH_SESSION_TTL_SECONDS", 7200)),
    )
    return {
        "authenticated": True,
        "user": user,
        "session": session,
        "token": token,
        "trusted_device": trusted_device,
        "device_token": None,
    }


def start_login(email, password, remember_device=False, device_name="", device_token=""):
    email = User.objects.normalize_email(email)
    user = User.objects.filter(email=email).first()
    if user is None:
        # Match the expensive password hashing work for unknown accounts.
        make_password(password)
        valid = False
    else:
        valid = user.check_password(password) and user.is_active and user.email_verified
    if not valid:
        raise APIError("invalid_credentials", "Мэйл хаяг эсвэл нууц үг буруу байна.", 401)
    if device_token:
        with transaction.atomic():
            user = User.objects.select_for_update().filter(pk=user.pk).first()
            if user is None or not user.is_active or not user.email_verified:
                raise APIError("invalid_credentials", "Нэвтрэх боломжгүй бүртгэл байна.", 401)
            now = timezone.now()
            device = TrustedDevice.objects.select_for_update().filter(
                user=user, token_hash=hash_token(device_token), expires_at__gt=now
            ).first()
            if device:
                device.last_used_at = now
                device.save(update_fields=["last_used_at"])
                return create_session(user, device)
    challenge = _create_challenge(
        EmailChallenge.Purpose.LOGIN,
        email,
        user=user,
        remember_device=remember_device,
        device_name=device_name.strip(),
    )
    return {"authenticated": False, "challenge": challenge}


def _locked_challenge(challenge_id):
    try:
        owner_id = EmailChallenge.objects.filter(id=challenge_id).values_list("user_id", flat=True).first()
        if owner_id is not None:
            User.objects.select_for_update().filter(pk=owner_id).first()
        return EmailChallenge.objects.select_for_update().get(id=challenge_id)
    except (EmailChallenge.DoesNotExist, ValidationError, ValueError, TypeError):
        raise APIError("challenge_not_found", "Баталгаажуулах хүсэлт олдсонгүй.", 404) from None


def _check_challenge(challenge, now, expected_purpose=None):
    if expected_purpose and challenge.purpose != expected_purpose:
        return APIError("invalid_challenge", "Баталгаажуулах хүсэлтийн төрөл буруу байна.")
    if challenge.consumed_at is not None:
        return APIError("challenge_used", "Энэ баталгаажуулах хүсэлтийг ашигласан байна.")
    if challenge.expires_at <= now:
        return APIError("code_expired", "Баталгаажуулах кодын хугацаа дууссан байна.")
    if challenge.attempts >= _seconds("AUTH_CODE_MAX_ATTEMPTS", 5):
        return APIError("code_attempts_exceeded", "Код шалгах оролдлогын хязгаарт хүрсэн байна.", 429)
    return None


def verify(challenge_id, code, expected_purpose):
    error = None
    result = None
    with transaction.atomic():
        challenge = _locked_challenge(challenge_id)
        now = timezone.now()
        error = _check_challenge(challenge, now, expected_purpose)
        if error is None:
            challenge.attempts += 1
            challenge.save(update_fields=["attempts"])
            if not secrets.compare_digest(challenge.code_hash, _code_hash(challenge.id, code)):
                error = (
                    APIError("code_attempts_exceeded", "Код шалгах оролдлогын хязгаарт хүрсэн байна.", 429)
                    if challenge.attempts >= _seconds("AUTH_CODE_MAX_ATTEMPTS", 5)
                    else APIError("invalid_code", "Баталгаажуулах код буруу байна.")
                )
            else:
                if challenge.purpose == EmailChallenge.Purpose.REGISTER:
                    if User.objects.filter(email=challenge.email).exists():
                        error = APIError("email_exists", "Энэ мэйл хаяг бүртгэлтэй байна.", 409)
                    else:
                        try:
                            # Keep a concurrent unique-email failure isolated so
                            # the consumed challenge can still be persisted.
                            with transaction.atomic():
                                user = User.objects.create(
                                    email=challenge.email,
                                    full_name=challenge.full_name,
                                    password=challenge.password_hash,
                                    email_verified=True,
                                )
                        except IntegrityError:
                            error = APIError("email_exists", "Энэ мэйл хаяг бүртгэлтэй байна.", 409)
                else:
                    user = challenge.user
                    if user is None or not user.is_active or not user.email_verified:
                        error = APIError("invalid_credentials", "Нэвтрэх боломжгүй бүртгэл байна.", 401)

                challenge.consumed_at = now
                challenge.password_hash = ""
                challenge.code_hash = ""
                challenge.save(update_fields=["consumed_at", "password_hash", "code_hash"])
                if error is None:
                    device = None
                    device_token = None
                    if challenge.purpose == EmailChallenge.Purpose.LOGIN and challenge.remember_device:
                        device_token = secrets.token_urlsafe(32)
                        device = TrustedDevice.objects.create(
                            user=user,
                            token_hash=hash_token(device_token),
                            name=challenge.device_name,
                            expires_at=now + timedelta(days=_seconds("AUTH_DEVICE_TTL_DAYS", 30)),
                            last_used_at=now,
                        )
                    result = create_session(user, device)
                    result["device_token"] = device_token
    # Wrong codes must commit their attempt count before reporting an error.
    if error:
        raise error
    return result


def resend(challenge_id):
    error = None
    with transaction.atomic():
        challenge = _locked_challenge(challenge_id)
        now = timezone.now()
        # An expired code can be replaced while the challenge is still unused.
        if challenge.consumed_at is not None:
            error = APIError("challenge_used", "Энэ баталгаажуулах хүсэлтийг ашигласан байна.")
        elif challenge.attempts >= _seconds("AUTH_CODE_MAX_ATTEMPTS", 5):
            error = APIError("code_attempts_exceeded", "Код шалгах оролдлогын хязгаарт хүрсэн байна.", 429)
        elif challenge.sends >= _seconds("AUTH_CODE_MAX_SENDS", 5):
            error = APIError("code_sends_exceeded", "Код илгээх оролдлогын хязгаарт хүрсэн байна.", 429)
        else:
            wait = _seconds("AUTH_CODE_RESEND_SECONDS", 60) - (now - challenge.last_sent_at).total_seconds()
            if wait > 0:
                error = APIError("resend_too_soon", "Код дахин авахын өмнө түр хүлээнэ үү.", 429, math.ceil(wait))
            else:
                code = f"{secrets.randbelow(1_000_000):06d}"
                challenge.code_hash = _code_hash(challenge.id, code)
                challenge.expires_at = now + timedelta(seconds=_seconds("AUTH_CODE_TTL_SECONDS", 600))
                challenge.last_sent_at = now
                challenge.sends += 1
                challenge.save(update_fields=["code_hash", "expires_at", "last_sent_at", "sends"])
                _send_code(challenge, code)
    if error:
        raise error
    return challenge


def revoke_session(session, forget_device=False):
    with transaction.atomic():
        user_id = session.user_id
        User.objects.select_for_update().filter(pk=user_id).first()
        current = AuthSession.objects.select_for_update().filter(pk=session.pk, user_id=user_id).first()
        if current is None:
            return
        device_id = current.trusted_device_id
        if forget_device and device_id:
            TrustedDevice.objects.select_for_update().filter(id=device_id, user_id=user_id).first()
        current.delete()
        if forget_device and device_id:
            # Revoke every session issued through this remembered device.
            AuthSession.objects.filter(user_id=user_id, trusted_device_id=device_id).delete()
            TrustedDevice.objects.filter(id=device_id, user_id=user_id).delete()
