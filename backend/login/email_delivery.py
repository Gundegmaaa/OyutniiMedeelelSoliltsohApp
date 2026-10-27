import json
from base64 import urlsafe_b64encode
from email.message import EmailMessage
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from django.conf import settings


def send_verification_email(*, recipient, subject, message):
    if all(
        (
            settings.GMAIL_EMAIL,
            settings.GOOGLE_CLIENT_ID,
            settings.GOOGLE_CLIENT_SECRET,
            settings.GOOGLE_REFRESH_TOKEN,
        )
    ):
        _send_with_gmail_api(recipient, subject, message)
        return

    if settings.RESEND_API_KEY and settings.EMAIL_FROM:
        _send_with_resend(recipient, subject, message)
        return

    raise RuntimeError("Email delivery credentials are missing.")


def _send_with_gmail_api(recipient, subject, message):
    token_request = Request(
        "https://oauth2.googleapis.com/token",
        data=urlencode(
            {
                "client_id": settings.GOOGLE_CLIENT_ID,
                "client_secret": settings.GOOGLE_CLIENT_SECRET,
                "refresh_token": settings.GOOGLE_REFRESH_TOKEN,
                "grant_type": "refresh_token",
            }
        ).encode("ascii"),
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    with urlopen(token_request, timeout=settings.EMAIL_TIMEOUT) as response:
        access_token = json.loads(response.read())["access_token"]

    email = EmailMessage()
    email["From"] = settings.GMAIL_EMAIL
    email["To"] = recipient
    email["Subject"] = subject
    email.set_content(message)
    payload = json.dumps(
        {"raw": urlsafe_b64encode(email.as_bytes()).decode("ascii")}
    ).encode("utf-8")
    request = Request(
        "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
        data=payload,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urlopen(request, timeout=settings.EMAIL_TIMEOUT) as response:
        if response.status >= 400:
            raise RuntimeError(
                f"Gmail API rejected the email with status {response.status}."
            )


def _send_with_resend(recipient, subject, message):

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
