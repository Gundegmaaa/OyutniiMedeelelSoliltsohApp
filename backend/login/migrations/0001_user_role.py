from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name="UserRole",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("st_code", models.CharField(max_length=50, unique=True)),
                (
                    "role",
                    models.CharField(
                        choices=[
                            ("student", "Оюутан"),
                            ("teacher", "Багш"),
                            ("admin", "Сургалтын алба"),
                        ],
                        default="student",
                        max_length=16,
                    ),
                ),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
            options={"db_table": "login_userrole"},
        ),
    ]
