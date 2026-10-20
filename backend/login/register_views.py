
from django.db import DatabaseError, IntegrityError, transaction
from django.contrib.auth.hashers import make_password

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
                "message": "Оюутны код, овог, нэр, имэйл, нууц үгээ бөглөнө үү."
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    if not isinstance(password, str) or len(password) < 8:
        return Response(
            {
                "success": False,
                "message": "Нууц үг хамгийн багадаа 8 тэмдэгт байна."
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        course_id = int(course_id) if course_id not in (None, "") else None
        phone_number = int(phone_number) if phone_number not in (None, "") else None
    except (ValueError, TypeError):
        return Response(
            {
                "success": False,
                "message": "Курс болон утасны дугаараа шалгана уу."
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        with transaction.atomic():
            if TblUser.objects.filter(st_code=st_code).exists():
                return Response(
                    {
                        "success": False,
                        "message": "Энэ оюутны код бүртгэлтэй байна."
                    },
                    status=status.HTTP_409_CONFLICT,
                )

            if TblUser.objects.filter(email__iexact=email).exists():
                return Response(
                    {
                        "success": False,
                        "message": "Энэ имэйл бүртгэлтэй байна."
                    },
                    status=status.HTTP_409_CONFLICT,
                )

            user = TblUser.objects.create(
                st_code=st_code,
                user_lastname=lastname,
                user_firstname=firstname,
                course_id=course_id,
                email=email,
                phone_number=phone_number,
                pro_index=pro_index,
                password=make_password(password),
                user_point=user_point,
            )

        return Response(
            {
                "success": True,
                "message": "Бүртгэл амжилттай үүслээ.",
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
                "message": "Энэ хэрэглэгчийн мэдээлэл бүртгэлтэй байна."
            },
            status=status.HTTP_409_CONFLICT,
        )

    except DatabaseError:
        return Response(
            {
                "success": False,
                "message": "Өгөгдлийн сантай холбогдоход алдаа гарлаа."
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )
