from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("login", "0001_user_role"),
    ]

    operations = [
        migrations.CreateModel(
            name="TblUser",
            fields=[
                (
                    "st_code",
                    models.CharField(
                        db_column="st_code",
                        max_length=50,
                        primary_key=True,
                        serialize=False,
                    ),
                ),
                (
                    "user_lastname",
                    models.CharField(db_column="user_lastname", max_length=255),
                ),
                (
                    "user_firstname",
                    models.CharField(db_column="user_firstname", max_length=255),
                ),
                (
                    "course_id",
                    models.IntegerField(blank=True, db_column="course_id", null=True),
                ),
                ("email", models.CharField(db_column="email", max_length=255)),
                (
                    "phone_number",
                    models.IntegerField(blank=True, db_column="phone_number", null=True),
                ),
                (
                    "pro_index",
                    models.CharField(
                        blank=True, db_column="pro_index", max_length=255, null=True
                    ),
                ),
                (
                    "password",
                    models.CharField(
                        blank=True, db_column="password", max_length=255, null=True
                    ),
                ),
                (
                    "user_point",
                    models.CharField(
                        blank=True, db_column="user_point", max_length=255, null=True
                    ),
                ),
            ],
            options={"db_table": "tbl_user", "managed": False},
        ),
    ]
