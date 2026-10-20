
from django.db import DatabaseError
from django.contrib.auth.hashers import check_password, make_password

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status

from .models import TblUser


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

        # Амжилттай нэвтэрсэн хариу
        return Response(
            {
                "success": True,
                "message": "Амжилттай нэвтэрлээ.",
                "user": {
                    "st_code": user.st_code,
                    "email": user.email,
                    "firstname": user.user_firstname,
                    "lastname": user.user_lastname,
                    "course_id": user.course_id,
                    "phone_number": user.phone_number,
                    "pro_index": user.pro_index,
                },
            },
            status=status.HTTP_200_OK,
        )

    except DatabaseError:
        return Response(
            {
                "success": False,
                "message": "Өгөгдлийн сантай холбогдоход алдаа гарлаа."
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )
