from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.decorators import api_view, authentication_classes, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from .models import TblUser, UserRole, role_for_student
from .security import csrf_rejection


def _is_admin(request):
    admin_id = request.session.get("admin_user_id")
    if admin_id and get_user_model().objects.filter(
        pk=admin_id, is_active=True, is_superuser=True
    ).exists():
        return True
    st_code = request.session.get("st_code")
    return bool(st_code and role_for_student(st_code) == "admin")


@api_view(["GET"])
@authentication_classes([])
@permission_classes([AllowAny])
def users(request):
    if not _is_admin(request):
        return Response({"message": "Админы эрх шаардлагатай."}, status=403)
    role_map = dict(UserRole.objects.values_list("st_code", "role"))
    people = TblUser.objects.all().order_by("course_id", "user_lastname")
    return Response([
        {
            "student_code": user.st_code,
            "email": user.email,
            "name": f"{user.user_lastname or ''} {user.user_firstname or ''}".strip(),
            "course": user.course_id,
            "role": role_map.get(user.st_code, "student"),
        }
        for user in people
    ])


@api_view(["PATCH"])
@authentication_classes([])
@permission_classes([AllowAny])
def set_user_role(request, st_code):
    csrf_error = csrf_rejection(request)
    if csrf_error:
        return csrf_error
    if not _is_admin(request):
        return Response({"message": "Админы эрх шаардлагатай."}, status=403)
    role = request.data.get("role")
    allowed = {choice[0] for choice in UserRole.ROLE_CHOICES}
    if role not in allowed:
        return Response(
            {"message": "Оюутан, багш эсвэл сургалтын албаны эрх сонгоно уу."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if not TblUser.objects.filter(st_code=st_code).exists():
        return Response({"message": "Хэрэглэгч олдсонгүй."}, status=404)
    assignment, _ = UserRole.objects.get_or_create(st_code=st_code)
    assignment.role = role
    assignment.save(update_fields=["role", "updated_at"])
    return Response({"student_code": st_code, "role": role})
