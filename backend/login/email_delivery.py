import json
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from django.conf import settings


def send_verification_email(*, recipient, subject, message):
    if not settings.RESEND_API_KEY or not settings.EMAIL_FROM:
        raise RuntimeError("Resend email settings are missing.")

    payload = json.dumps(
        {
            "from": settings.EMAIL_FROM,
            "to": [recipient],
            "subject": subject,
            "text": message,
        }
    ).encode("utf-8")
    request = Request(
        "https://api.resend.com/emails",
        data=payload,
        headers={
            "Authorization": f"Bearer {settings.RESEND_API_KEY}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urlopen(request, timeout=settings.EMAIL_TIMEOUT) as response:
            if response.status >= 400:
                raise RuntimeError(
                    f"Resend rejected the email with status {response.status}."
                )
    except HTTPError as error:
        error_body = error.read().decode("utf-8", errors="replace")
        try:
            error_data = json.loads(error_body)
        except json.JSONDecodeError:
            error_data = {}
        detail = error_data.get("message") or error_data.get("name")
        raise RuntimeError(
            f"Resend rejected the email with status {error.code}: "
            f"{detail or 'No error details returned.'}"
        ) from error
    except (TimeoutError, URLError, OSError) as error:
        raise RuntimeError("Could not reach Resend email API.") from error
