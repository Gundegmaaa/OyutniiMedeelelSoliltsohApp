import math
import secrets
from datetime import timedelta

from django.conf import settings
from django.core.mail import send_mail
from django.db import transaction
from django.utils import timezone
from django.utils.crypto import constant_time_compare, salted_hmac

from .models import EmailChallenge, User


class CooldownError(Exception):
    def __init__(self, seconds):
        self.seconds = max(1, math.ceil(seconds))
        self.wait = self.seconds
        super().__init__(f"Please wait {self.seconds} seconds before requesting another code.")


class EmailDeliveryError(Exception):
    pass


class InvalidChallengeError(Exception):
    def __init__(self):
        super().__init__("The verification code is invalid or expired.")


def _code_digest(challenge, code):
    # Bind the stored digest to this challenge; a database leak reveals no codes.
    return salted_hmac(
        "accounts.email_challenge",
        f"{challenge.id}:{challenge.purpose}:{code}",
        secret=settings.SECRET_KEY,
        algorithm="sha256",
    ).hexdigest()


def issue_challenge(user, purpose=EmailChallenge.Purpose.VERIFY_EMAIL):
    """Create and email a code atomically, without returning the plaintext code."""
    if purpose not in EmailChallenge.Purpose.values:
        raise ValueError("Unknown email challenge purpose.")

    with transaction.atomic():
        locked_user = User.objects.select_for_update().filter(pk=user.pk).first()
        if (
            not locked_user or not locked_user.is_active
            or locked_user.email_verified_at is not None
            or locked_user.email != user.email
        ):
            raise InvalidChallengeError()
        now = timezone.now()
        previous = EmailChallenge.objects.filter(user=locked_user, purpose=purpose).first()
        cooldown = getattr(settings, "EMAIL_RESEND_COOLDOWN_SECONDS", 60)
        if previous:
            remaining = cooldown - (now - previous.created_at).total_seconds()
            if remaining > 0:
                raise CooldownError(remaining)

        EmailChallenge.objects.filter(
            user=locked_user, purpose=purpose, consumed_at__isnull=True,
        ).update(consumed_at=now)
        lifetime = getattr(settings, "EMAIL_CODE_TTL_SECONDS", 600)
        challenge = EmailChallenge(
            user=locked_user,
            purpose=purpose,
            expires_at=now + timedelta(seconds=lifetime),
            max_attempts=getattr(settings, "EMAIL_CODE_MAX_ATTEMPTS", 5),
        )
        code = f"{secrets.randbelow(1_000_000):06d}"
        challenge.code_digest = _code_digest(challenge, code)
        challenge.save()
        subject = "Имэйл баталгаажуулах код"
        message = (
            f"Таны баталгаажуулах код: {code}\n\n"
            f"Энэ код {math.ceil(lifetime / 60)} минутын хугацаанд хүчинтэй. "
            "Кодоо бусдад дамжуулж болохгүй.\n"
            "Хэрэв та энэ хүсэлтийг гаргаагүй бол уг имэйлийг үл тооно уу."
        )
        try:
            sent = send_mail(
                subject, message, settings.DEFAULT_FROM_EMAIL,
                [locked_user.email], fail_silently=False,
            )
            if sent != 1:
                raise EmailDeliveryError("The verification email could not be sent.")
        except EmailDeliveryError:
            raise
        except Exception as error:
            raise EmailDeliveryError("The verification email could not be sent.") from error
        return challenge


def _locked_challenge(email, user_id=None):
    # All code issue/consume paths lock the user before the challenge to avoid
    # deadlocks and serialize verification, reissue, and concurrent submissions.
    if not isinstance(email, str) or not email.strip():
        return None, None
    normalized = User.objects.normalize_email(email)
    users = User.objects.select_for_update().filter(email=normalized)
    if user_id is not None:
        users = users.filter(pk=user_id)
    user = users.first()
    if not user:
        return None, None
    challenge = EmailChallenge.objects.select_for_update().filter(
        user=user, purpose=EmailChallenge.Purpose.VERIFY_EMAIL,
    ).first()
    return user, challenge


def consume_challenge(*, code, email, password, purpose=EmailChallenge.Purpose.VERIFY_EMAIL, user_id=None):
    """Verify once and finalize the mailbox owner's validated password atomically.

    Failed attempts commit even though the caller gets an error. The password is
    set only after a valid email code, so verifying a preregistered address cannot
    activate credentials previously chosen by someone else.
    """
    if purpose not in EmailChallenge.Purpose.values:
        raise InvalidChallengeError()

    accepted = None
    with transaction.atomic():
        user, challenge = _locked_challenge(email, user_id=user_id)
        now = timezone.now()
        valid = (
            user is not None
            and user.is_active
            and user.email_verified_at is None
            and challenge is not None
            and challenge.consumed_at is None
            and challenge.expires_at > now
            and challenge.attempts < challenge.max_attempts
        )
        if valid:
            well_formed = (
                isinstance(code, str) and len(code) == 6 and code.isascii() and code.isdecimal()
            )
            matches = constant_time_compare(challenge.code_digest, _code_digest(challenge, code))
            if not well_formed or not matches:
                challenge.attempts += 1
                challenge.save(update_fields=["attempts"])
            else:
                challenge.consumed_at = now
                challenge.save(update_fields=["consumed_at"])
                user.email_verified_at = now
                user.set_password(password)
                user.save(update_fields=["email_verified_at", "password"])
                challenge.user = user
                accepted = challenge

    if accepted is None:
        raise InvalidChallengeError()
    return accepted
