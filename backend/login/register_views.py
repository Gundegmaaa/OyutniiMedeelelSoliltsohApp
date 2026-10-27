
import secrets

from django.conf import settings
from django.core.mail import send_mail
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


@api_view(["POST"])
@permission_classes([AllowAny])
def register_service(request):
    data = request.data

    st_code = str(data.get("st_code", "")).strip()
    lastname = str(data.get("user_lastname", "")).strip()
    firstname = str(data.get("user_firstname", "")).strip()
    email = str(data.get("email", "")).strip().lower()
    password = data.get("password", "")

    course_id = data.get("course_id")
    phone_number = data.get("phone_number")

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

    if not settings.EMAIL_HOST_USER or not settings.EMAIL_HOST_PASSWORD:
        return Response(
            {
                "success": False,
                "message": "Gmail SMTP тохиргоо хийгдээгүй байна.",
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
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
        }

        send_mail(
            subject="Имэйл баталгаажуулах код",
            message=(
                f"Сайн байна уу, {firstname}!\n\n"
                f"Таны баталгаажуулах код: {code}\n"
                "Код 10 минутын хугацаанд хүчинтэй.\n"
                "Хэрэв та хүсэлт гаргаагүй бол энэ имэйлийг үл тооно уу."
            ),
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[email],
            fail_silently=False,
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
        request.session.pop("pending_registration", None)

        return Response(
            {
                "success": False,
                "message": "Имэйл илгээж чадсангүй. Gmail SMTP тохиргоогоо шалгана уу.",
            },
            status=status.HTTP_502_BAD_GATEWAY,
        )


@api_view(["POST"])
@permission_classes([AllowAny])
def verify_registration(request):
    code = str(request.data.get("code", "")).strip()
    pending = request.session.get("pending_registration")

    if not pending:
        return Response(
            {
                "success": False,
                "message": "Бүртгэлийн хүсэлт олдсонгүй. Дахин бүртгүүлнэ үү.",
            },
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