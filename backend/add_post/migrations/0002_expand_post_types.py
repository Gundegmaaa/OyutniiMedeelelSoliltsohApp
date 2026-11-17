from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('add_post', '0001_initial'),
    ]

    operations = [
        migrations.AlterField(
            model_name='post',
            name='post_type',
            field=models.CharField(
                choices=[
                    ('sell', 'Бараа зарах'),
                    ('exchange', 'Солилцох'),
                    ('rental', 'Түрээслүүлэх'),
                    ('free', 'Үнэгүй өгөх'),
                    ('info', 'Мэдээлэл хуваалцах'),
                    ('question', 'Асуулт'),
                    ('teacher', 'Багш'),
                ],
                max_length=20,
            ),
        ),
    ]
