from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("add_post", "0003_post_author_audience_reactions"),
    ]

    operations = [
        migrations.CreateModel(
            name="CalendarEvent",
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
                ("title", models.CharField(max_length=255)),
                ("date", models.DateField(db_index=True)),
                (
                    "event_type",
                    models.CharField(
                        choices=[
                            ("exam", "Шалгалт"),
                            ("assignment", "Бие даалт"),
                            ("seminar", "Семинар"),
                            ("other", "Бусад"),
                        ],
                        max_length=16,
                    ),
                ),
                ("notes", models.TextField(blank=True)),
                (
                    "minutes",
                    models.PositiveSmallIntegerField(blank=True, null=True),
                ),
                ("created_by", models.CharField(blank=True, max_length=64)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
            options={"ordering": ("date", "minutes", "title")},
        ),
    ]
