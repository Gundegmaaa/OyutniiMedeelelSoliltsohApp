from django.db import models


class Post(models.Model):
    POST_TYPES = [
        ('sell', 'Бараа зарах'),
        ('free', 'Үнэгүй өгөх'),
        ('info', 'Мэдээлэл хуваалцах'),
    ]

    title = models.CharField(max_length=255)
    content = models.TextField()
    image = models.ImageField(
        upload_to='posts/',
        blank=True,
        null=True
    )
    post_type = models.CharField(
        max_length=20,
        choices=POST_TYPES
    )
    price = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        blank=True,
        null=True
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title