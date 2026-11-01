
import secrets
import logging

from django.conf import settings
from django.core.validators import validate_email
from django.core.exceptions import ValidationError
from django.contrib.auth.hashers import make_password, check_password
from django.db import DatabaseError, IntegrityError, transaction
from django.utils import timezone

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status

from .models import TblUser
from .email_delivery import send_verification_email

logger = logging.getLogger(__name__)


@api_view(["POST"])
@permission_classes([AllowAny])
def register_service(request):
    data = request.data

    st_code = str(data.get("student_code", data.get("st_code", ""))).strip().upper()
    lastname = str(data.get("last_name", data.get("user_lastname", ""))).strip()
    firstname = str(data.get("first_name", data.get("user_firstname", ""))).strip()
    email = str(data.get("email", "")).strip().lower()
    password = data.get("password", "")

    course_id = data.get("course", data.get("course_id"))
    phone_number = data.get("phone_number")
    password_confirm = data.get("password_confirm")

    if password_confirm is not None and password_confirm != password:
        return Response(
            {"success": False, "message": "Нууц үг таарахгүй байна."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    pro_index = str(data.get("pro_index", "")).strip() or None
    user_point = str(data.get("user_point", "")).strip() or None

    if not all([st_code, lastname, firstname, email, password]):
        return Response(
            {
                "success": False,
                "message": "Оюутны код, овог, нэр, имэйл, нууц үгээ бөглөнө үү.",
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    if not isinstance(password, str) or len(password) < 8:
        return Response(
            {
                "success": False,
                "message": "Нууц үг хамгийн багадаа 8 тэмдэгт байна.",
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        validate_email(email)
    except ValidationError:
        return Response(
            {
                "success": False,
                "message": "Имэйл хаяг буруу байна.",
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        course_id = (
            int(course_id)
            if course_id not in (None, "")
            else None
        )

        phone_number = (
            int(phone_number)
            if phone_number not in (None, "")
            else None
        )

    except (ValueError, TypeError):
        return Response(
            {
                "success": False,
                "message": "Курс эсвэл утасны дугаар буруу байна.",
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    brevo_configured = settings.BREVO_API_KEY and settings.BREVO_SENDER_EMAIL
    gmail_email_configured = all(
        (
            settings.GMAIL_EMAIL,
            settings.GOOGLE_CLIENT_ID,
            settings.GOOGLE_CLIENT_SECRET,
            settings.GOOGLE_REFRESH_TOKEN,
        )
    )
    resend_configured = settings.RESEND_API_KEY and settings.EMAIL_FROM
    if not brevo_configured and not gmail_email_configured and not resend_configured:
        return Response(
            {
                "success": False,
                "message": "Имэйл үйлчилгээ сервер дээр тохируулаагүй байна.",
            },
            status=status.HTTP_503_SERVICE_UNAVAILABLE,
        )

    try:
        if TblUser.objects.filter(st_code=st_code).exists():
            return Response(
                {
                    "success": False,
                    "message": "Оюутны код бүртгэлтэй байна.",
                },
                status=status.HTTP_409_CONFLICT,
            )

        if TblUser.objects.filter(email__iexact=email).exists():
            return Response(
                {
                    "success": False,
                    "message": "Энэ имэйл бүртгэлтэй байна.",
                },
                status=status.HTTP_409_CONFLICT,
            )

        code = f"{secrets.randbelow(1_000_000):06d}"

        request.session["pending_registration"] = {
            "st_code": st_code,
            "user_lastname": lastname,
            "user_firstname": firstname,
            "email": email,
            "password_hash": make_password(password),
            "course_id": course_id,
            "phone_number": phone_number,
            "pro_index": pro_index,
            "user_point": user_point,
            "code_hash": make_password(code),
            "expires_at": timezone.now().timestamp() + 600,
            "attempts": 0,
            "last_sent_at": timezone.now().timestamp(),
        }

        send_verification_email(
            subject="Имэйл баталгаажуулах код",
            message=(
                f"Сайн байна уу, {firstname}!\n\n"
                f"Таны баталгаажуулах код: {code}\n"
                "Код 10 минутын хугацаанд хүчинтэй.\n"
                "Хэрэв та хүсэлт гаргаагүй бол энэ имэйлийг үл тооно уу."
            ),
            recipient=email,
        )

        return Response(
            {
                "success": True,
                "message": "Баталгаажуулах код таны имэйл рүү илгээгдлээ.",
                "email": email,
                "expires_in": 600,
            },
            status=status.HTTP_200_OK,
        )

    except (IntegrityError, DatabaseError):
        request.session.pop("pending_registration", None)

        return Response(
            {
                "success": False,
                "message": "Өгөгдлийн сантай холбоотой алдаа гарлаа.",
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    except Exception:
        logger.exception("Registration email delivery failed")
        request.session.pop("pending_registration", None)

        return Response(
            {
                "success": False,
                "message": "Имэйл илгээж чадсангүй. Дахин оролдоно уу.",
            },
            status=status.HTTP_502_BAD_GATEWAY,
        )


@api_view(["POST"])
@permission_classes([AllowAny])
def verify_registration(request):
    code = str(request.data.get("code", "")).strip()
    email = str(request.data.get("email", "")).strip().lower()
    password = request.data.get("password")
    pending = request.session.get("pending_registration")

    if not pending:
        return Response(
            {
                "success": False,
                "message": "Бүртгэлийн хүсэлт олдсонгүй. Дахин бүртгүүлнэ үү.",
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    if email and email != pending["email"]:
        return Response(
            {"success": False, "message": "Бүртгэлийн имэйл таарахгүй байна."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if password is not None and not check_password(
        password, pending["password_hash"]
    ):
        return Response(
            {"success": False, "message": "Нууц үг таарахгүй байна."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if timezone.now().timestamp() > pending["expires_at"]:
        request.session.pop("pending_registration", None)

        return Response(
            {
                "success": False,
                "message": "Кодын хугацаа дууссан. Дахин бүртгүүлнэ үү.",
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    if pending["attempts"] >= 5:
        request.session.pop("pending_registration", None)

        return Response(
            {
                "success": False,
                "message": "Олон удаа буруу код оруулсан тул дахин бүртгүүлнэ үү.",
            },
            status=status.HTTP_429_TOO_MANY_REQUESTS,
        )

    pending["attempts"] += 1
    request.session["pending_registration"] = pending
    request.session.modified = True

    if not code or not check_password(code, pending["code_hash"]):
        return Response(
            {
                "success": False,
                "message": "Баталгаажуулах код буруу байна.",
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        with transaction.atomic():
            if TblUser.objects.filter(
                st_code=pending["st_code"]
            ).exists():
                request.session.pop("pending_registration", None)

                return Response(
                    {
                        "success": False,
                        "message": "Оюутны код бүртгэлтэй байна.",
                    },
                    status=status.HTTP_409_CONFLICT,
                )

            if TblUser.objects.filter(
                email__iexact=pending["email"]
            ).exists():
                request.session.pop("pending_registration", None)

                return Response(
                    {
                        "success": False,
                        "message": "Имэйл аль хэдийн бүртгэгдсэн байна.",
                    },
                    status=status.HTTP_409_CONFLICT,
                )

            user = TblUser.objects.create(
                st_code=pending["st_code"],
                user_lastname=pending["user_lastname"],
                user_firstname=pending["user_firstname"],
                email=pending["email"],
                password=pending["password_hash"],
                course_id=pending["course_id"],
                phone_number=pending["phone_number"],
                pro_index=pending["pro_index"],
                user_point=pending["user_point"],
            )

        request.session.pop("pending_registration", None)

        return Response(
            {
                "success": True,
                "message": "Имэйл баталгаажиж, бүртгэл амжилттай үүслээ.",
                "user": {
                    "st_code": user.st_code,
                    "email": user.email,
                    "firstname": user.user_firstname,
                    "lastname": user.user_lastname,
                },
            },
            status=status.HTTP_201_CREATED,
        )

    except IntegrityError:
        return Response(
            {
                "success": False,
                "message": "Оюутны код эсвэл имэйл давхардсан байна.",
            },
            status=status.HTTP_409_CONFLICT,
        )

    except DatabaseError:
        return Response(
            {
                "success": False,
                "message": "Өгөгдлийн сантай холбоотой алдаа гарлаа.",
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )


@api_view(["POST"])
@permission_classes([AllowAny])
def resend_verification(request):
    email = str(request.data.get("email", "")).strip().lower()
    pending = request.session.get("pending_registration")
    if not pending:
        return Response(
            {"success": False, "message": "Баталгаажуулах бүртгэл олдсонгүй."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if email != pending["email"]:
        return Response(
            {"success": False, "message": "Бүртгэлийн имэйл таарахгүй байна."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    now = timezone.now().timestamp()
    if now - pending.get("last_sent_at", 0) < 60:
        return Response(
            {"success": False, "message": "Дахин илгээхээс өмнө түр хүлээнэ үү."},
            status=status.HTTP_429_TOO_MANY_REQUESTS,
            headers={"Retry-After": "60"},
        )

    code = f"{secrets.randbelow(1_000_000):06d}"
    pending["code_hash"] = make_password(code)
    pending["expires_at"] = now + 600
    pending["last_sent_at"] = now
    pending["attempts"] = 0
    request.session["pending_registration"] = pending
    request.session.modified = True
    try:
        send_verification_email(
            subject="Имэйл баталгаажуулах код",
            message=f"Таны баталгаажуулах код: {code}\nКод 10 минут хүчинтэй.",
            recipient=email,
        )
    except Exception:
        logger.exception("Verification email resend failed")
        return Response(
            {"success": False, "message": "Имэйл илгээж чадсангүй."},
            status=status.HTTP_503_SERVICE_UNAVAILABLE,
        )
    return Response({"detail": "Баталгаажуулах код дахин илгээгдлээ."}, status=202)
