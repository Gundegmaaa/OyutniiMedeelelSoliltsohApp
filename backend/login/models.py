
from django.db import models


class TblUser(models.Model):
    st_code = models.CharField(
        max_length=50,
        primary_key=True,
        db_column="st_code",
    )

    user_lastname = models.CharField(
        max_length=255,
        db_column="user_lastname",
    )

    user_firstname = models.CharField(
        max_length=255,
        db_column="user_firstname",
    )

    course_id = models.IntegerField(
        db_column="course_id",
        null=True,
        blank=True,
    )

    email = models.CharField(
        max_length=255,
        db_column="email",
    )

    phone_number = models.IntegerField(
        db_column="phone_number",
        null=True,
        blank=True,
    )

    pro_index = models.CharField(
        max_length=255,
        db_column="pro_index",
        null=True,
        blank=True,
    )

    password = models.CharField(
        max_length=255,
        db_column="password",
        null=True,
        blank=True,
    )

    user_point = models.CharField(
        max_length=255,
        db_column="user_point",
        null=True,
        blank=True,
    )

    class Meta:
        managed = False
        db_table = "tbl_user"

    def __str__(self):
        return self.email


class UserRole(models.Model):
    ROLE_CHOICES = [
        ("student", "Оюутан"),
        ("teacher", "Багш"),
        ("admin", "Сургалтын алба"),
    ]

    st_code = models.CharField(max_length=50, unique=True)
    role = models.CharField(
        max_length=16,
        choices=ROLE_CHOICES,
        default="student",
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "login_userrole"

    def __str__(self):
        return f"{self.st_code}: {self.role}"


def role_for_student(st_code):
    return UserRole.objects.filter(st_code=st_code).values_list(
        "role", flat=True
    ).first() or "student"
