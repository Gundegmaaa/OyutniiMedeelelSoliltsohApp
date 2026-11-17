from django.db import models


class Post(models.Model):
    POST_TYPES = [
        ('sell', 'Бараа зарах'),
        ('exchange', 'Солилцох'),
        ('rental', 'Түрээслүүлэх'),
        ('free', 'Үнэгүй өгөх'),
        ('info', 'Мэдээлэл хуваалцах'),
        ('question', 'Асуулт'),
        ('teacher', 'Багш'),
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
    # tbl_user.st_code of the author; empty for posts made before authors
    # were recorded. db_default keeps older deployments able to insert rows.
    author_code = models.CharField(
        max_length=50,
        blank=True,
        db_default='',
        db_index=True,
    )
    # Comma-separated course numbers that may see the post; empty = everyone.
    audience_courses = models.CharField(
        max_length=32,
        blank=True,
        db_default='',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title

    @property
    def audience_list(self):
        return [
            int(item)
            for item in self.audience_courses.split(',')
            if item.strip().isdigit()
        ]


class PostReaction(models.Model):
    post = models.ForeignKey(
        Post,
        on_delete=models.CASCADE,
        related_name='reactions',
    )
    st_code = models.CharField(max_length=50, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['post', 'st_code'],
                name='unique_post_reaction',
            ),
        ]

    def __str__(self):
        return f'{self.st_code} -> {self.post_id}'
