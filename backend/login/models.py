
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