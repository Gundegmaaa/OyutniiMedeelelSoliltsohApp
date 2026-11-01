
import logging

from django.middleware.csrf import get_token
from django.db import DatabaseError
from django.contrib.auth.hashers import check_password, make_password
from django.views.decorators.csrf import ensure_csrf_cookie

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status

from .models import TblUser

logger = logging.getLogger(__name__)


def _user_payload(user):
    first_name = user.user_firstname or ""
    last_name = user.user_lastname or ""
    return {
        "id": str(user.st_code),
        "email": user.email,
        "display_name": f"{last_name} {first_name}".strip() or user.email,
        "first_name": first_name,
        "last_name": last_name,
        "student_code": user.st_code,
        "course": user.course_id,
        "role": "student",
        "email_verified": True,
    }


@ensure_csrf_cookie
@api_view(["GET"])
@permission_classes([AllowAny])
def csrf_token(request):
    return Response({"csrf_token": get_token(request)})


@api_view(["GET"])
@permission_classes([AllowAny])
def current_user(request):
    st_code = request.session.get("st_code")
    if not st_code:
        return Response(
            {"success": False, "message": "Нэвтрэх шаардлагатай."},
            status=status.HTTP_401_UNAUTHORIZED,
        )
    try:
        user = TblUser.objects.filter(st_code=st_code).first()
    except DatabaseError:
        logger.exception("Current user database error")
        return Response(
            {"success": False, "message": "Өгөгдлийн сантай холбогдоход алдаа гарлаа."},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )
    if user is None:
        request.session.flush()
        return Response(
            {"success": False, "message": "Нэвтрэх шаардлагатай."},
            status=status.HTTP_401_UNAUTHORIZED,
        )
    return Response({"user": _user_payload(user)})


@api_view(["POST"])
@permission_classes([AllowAny])
def logout_service(request):
    request.session.flush()
    return Response({"detail": "Системээс гарлаа."})


@api_view(["POST"])
@permission_classes([AllowAny])
def login_service(request):
    # Хүсэлтээс имэйл, нууц үг авах
    email = request.data.get("email", "")
    password = request.data.get("password", "")

    # Оролтын утгууд шалгах
    if not isinstance(email, str) or not isinstance(password, str):
        return Response(
            {
                "success": False,
                "message": "Имэйл болон нууц үгээ зөв оруулна уу."
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    email = email.strip().lower()

    if not email or not password:
        return Response(
            {
                "success": False,
                "message": "Имэйл болон нууц үгээ оруулна уу."
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        # Одоо байгаа tbl_user хүснэгтээс хэрэглэгч хайх
        user = TblUser.objects.filter(
            email__iexact=email
        ).first()

        if user is None or not user.password:
            return Response(
                {
                    "success": False,
                    "message": "Имэйл эсвэл нууц үг буруу байна."
                },
                status=status.HTTP_401_UNAUTHORIZED,
            )

        # Шинэ бүртгэлийн hash нууц үгийг шалгах
        valid_password = check_password(
            password,
            user.password
        )

        # Хуучин хэрэглэгчийн нууц үг энгийн текст байвал
        # зөв таарсан үед hash хэлбэрт шилжүүлэх
        if not valid_password and user.password == password:
            user.password = make_password(password)
            user.save(update_fields=["password"])
            valid_password = True

        if not valid_password:
            return Response(
                {
                    "success": False,
                    "message": "Имэйл эсвэл нууц үг буруу байна."
                },
                status=status.HTTP_401_UNAUTHORIZED,
            )

        request.session["st_code"] = user.st_code
        remember_me = request.data.get("remember_me", False)
        request.session.set_expiry(
            30 * 24 * 60 * 60 if remember_me is True else 0
        )

        return Response(
            {
                "success": True,
                "message": "Амжилттай нэвтэрлээ.",
                "user": _user_payload(user),
                "csrf_token": get_token(request),
            },
            status=status.HTTP_200_OK,
        )

    except DatabaseError:
        logger.exception("Login database error")
        return Response(
            {
                "success": False,
                "message": "Өгөгдлийн сантай холбогдоход алдаа гарлаа.",
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )
