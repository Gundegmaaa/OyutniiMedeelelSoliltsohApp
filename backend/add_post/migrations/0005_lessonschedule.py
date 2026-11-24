from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("add_post", "0004_calendarevent"),
    ]

    operations = [
        migrations.CreateModel(
            name="LessonSchedule",
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
                ("weekday", models.PositiveSmallIntegerField(db_index=True)),
                ("start_time", models.TimeField()),
                ("subject", models.CharField(max_length=255)),
                ("room", models.CharField(blank=True, max_length=64)),
            ],
            options={"ordering": ("weekday", "start_time", "subject")},
        ),
    ]
