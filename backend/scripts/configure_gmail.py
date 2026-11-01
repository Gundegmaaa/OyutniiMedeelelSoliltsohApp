"""Configure Gmail SMTP without putting credentials in shell history or output."""

from __future__ import annotations

import argparse
import getpass
import os
from pathlib import Path
import re
import smtplib
import ssl
import stat
import sys
import tempfile
import warnings


BACKEND_DIR = Path(__file__).resolve().parents[1]
ENV_PATH = BACKEND_DIR / ".env"
SMTP_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
ASSIGNMENT = re.compile(r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=")
EMAIL_PATTERN = re.compile(
    r"[A-Za-z0-9._%+\-]+@"
    r"[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?"
    r"(?:\.[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?)+"
)


def validate_credentials(email: str, password: str) -> tuple[str, str]:
    """Accept Gmail or Workspace addresses and a spaced 16-character app password."""
    if any(character in email + password for character in "\r\n"):
        raise ValueError("Email/App Password cannot contain line breaks.")
    email = email.strip()
    if (
        not EMAIL_PATTERN.fullmatch(email)
        or len(email) > 254
        or len(email.split("@", 1)[0]) > 64
        or email.startswith(".")
        or ".@" in email
        or ".." in email
    ):
        raise ValueError("Enter a valid Gmail or Google Workspace email address.")
    password = password.replace(" ", "")
    if not re.fullmatch(r"[A-Za-z0-9]{16}", password):
        raise ValueError("Use the 16-character Google App Password, not your account password.")
    return email, password


def smtp_login(email: str, password: str) -> None:
    """Check authentication over TLS. This function never sends a message."""
    with smtplib.SMTP("smtp.gmail.com", 587, timeout=15) as connection:
        connection.ehlo()
        connection.starttls(context=ssl.create_default_context())
        connection.ehlo()
        connection.login(email, password)


def split_comment(value: str) -> tuple[str, str]:
    """Split a dotenv value from a trailing comment, respecting quoted values."""
    quote = None
    escaped = False
    for index, character in enumerate(value):
        if escaped:
            escaped = False
        elif character == "\\" and quote == '"':
            escaped = True
        elif quote:
            if character == quote:
                quote = None
        elif character in "'\"":
            quote = character
        elif character == "#" and (index == 0 or value[index - 1].isspace()):
            return value[:index].rstrip(), value[index:]
    return value.rstrip(), ""


def read_env(path: Path) -> tuple[str, dict[str, str]]:
    """Read this CLI's simple SMTP values without importing Django or dotenv."""
    with path.open(encoding="utf-8", newline="") as source:
        original = source.read()
    values = {}
    for line in original.lstrip("\ufeff").splitlines():
        match = ASSIGNMENT.match(line)
        if match:
            value, _ = split_comment(line[match.end():].strip())
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
                value = value[1:-1]
            values[match.group(1)] = value
    return original, values


def write_configuration(path: Path, email: str, password: str) -> None:
    """Atomically replace SMTP assignments while preserving other settings/comments."""
    email, password = validate_credentials(email, password)
    if path.is_symlink():
        raise OSError("Refusing to replace a symlink.")
    original, _ = read_env(path)
    settings = {
        "EMAIL_BACKEND": SMTP_BACKEND,
        "EMAIL_HOST": "smtp.gmail.com",
        "EMAIL_PORT": "587",
        "EMAIL_USE_TLS": "true",
        "EMAIL_USE_SSL": "false",
        "EMAIL_HOST_USER": "twigy0926@gmail.com",
        "EMAIL_HOST_PASSWORD": "hqfqewdqbbqhwngx",
        "DEFAULT_FROM_EMAIL": f"Student News <{email}>",
    }
    newline = "\r\n" if "\r\n" in original else "\n"
    output = []
    replaced = set()
    bom = "\ufeff" if original.startswith("\ufeff") else ""
    for line in original.removeprefix("\ufeff").splitlines(keepends=True):
        match = ASSIGNMENT.match(line)
        if match and match.group(1) in settings:
            key = match.group(1)
            _, comment = split_comment(line[match.end():].rstrip("\r\n"))
            suffix = f"  {comment}" if comment else ""
            # All values are controlled constants or validated single-line input.
            output.append(f"{key}='{settings[key]}'{suffix}{newline}")
            replaced.add(key)
        else:
            output.append(line)
    if output and not output[-1].endswith(("\n", "\r")):
        output[-1] += newline
    for key, value in settings.items():
        if key not in replaced:
            output.append(f"{key}='{value}'{newline}")

    temporary_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", newline="", dir=path.parent,
            prefix=".gmail-", suffix=".tmp", delete=False,
        ) as destination:
            temporary_path = Path(destination.name)
            destination.write(bom + "".join(output))
            destination.flush()
            os.fsync(destination.fileno())
        os.chmod(temporary_path, stat.S_IMODE(path.stat().st_mode))
        os.replace(temporary_path, path)
        temporary_path = None
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check", action="store_true",
        help="Check the existing Gmail SMTP credentials without changing .env or sending email.",
    )
    args = parser.parse_args(argv)
    try:
        if not ENV_PATH.is_file():
            print("backend/.env is missing. Copy .env.example to .env first.")
            return 1
        if args.check:
            _, values = read_env(ENV_PATH)
            expected = {
                "EMAIL_BACKEND": SMTP_BACKEND, "EMAIL_HOST": "smtp.gmail.com",
                "EMAIL_PORT": "587", "EMAIL_USE_TLS": "true", "EMAIL_USE_SSL": "false",
            }
            if any(values.get(key, "").lower() != value.lower() for key, value in expected.items()):
                print("Gmail SMTP is not configured. Run this script without --check first.")
                return 1
            email, password = validate_credentials(
                values.get("EMAIL_HOST_USER", ""), values.get("EMAIL_HOST_PASSWORD", ""),
            )
        else:
            print("Gmail SMTP setup. Use a Google App Password after enabling 2-Step Verification.")
            print("App Password: https://myaccount.google.com/apppasswords")
            email = input("Gmail / Workspace email (blank to cancel): ")
            if not email.strip():
                print("Cancelled. .env was not changed.")
                return 0
            # Refuse getpass's echoing fallback so a secret is never shown in output.
            with warnings.catch_warnings():
                warnings.simplefilter("error", getpass.GetPassWarning)
                password = getpass.getpass("16-character App Password (hidden): ")
            email, password = validate_credentials(email, password)

        print("Checking smtp.gmail.com:587 using STARTTLS; no email will be sent...")
        smtp_login(email, password)
        if args.check:
            print("Gmail SMTP authentication succeeded. .env was not changed.")
        else:
            write_configuration(ENV_PATH, email, password)
            print("Gmail SMTP saved to backend/.env. Restart the Django server.")
        return 0
    except (EOFError, KeyboardInterrupt):
        print("\nCancelled. .env was not changed.")
    except getpass.GetPassWarning:
        print("A terminal that hides password input is required. Run from PowerShell. .env was not changed.")
    except ValueError as error:
        print(f"{error} .env was not changed.")
    except smtplib.SMTPAuthenticationError:
        print("Gmail rejected the login. Check the email, 2-Step Verification and App Password. .env was not changed.")
    except smtplib.SMTPException:
        print("Gmail SMTP authentication could not finish. Check the account and try again. .env was not changed.")
    except (OSError, UnicodeError):
        print("Connection or file access failed. Check internet, port 587 and backend/.env permissions, then retry. .env was not changed.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
