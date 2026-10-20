import uuid

from django.contrib.auth.models import AbstractUser
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.db.models.functions import Lower

from .managers import UserManager


class User(AbstractUser):
    class Role(models.TextChoices):
        STUDENT = "student", "Оюутан"
        TEACHER = "teacher", "Багш"
        ADMIN = "admin", "Админ"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    username = None
    email = models.EmailField(unique=True)
    display_name = models.CharField(max_length=301)
    student_code = models.CharField(max_length=32, null=True, blank=True)
    course = models.PositiveSmallIntegerField(
        null=True, blank=True, validators=[MinValueValidator(1), MaxValueValidator(6)],
    )
    role = models.CharField(max_length=16, choices=Role.choices, default=Role.STUDENT)
    email_verified_at = models.DateTimeField(null=True, blank=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["display_name"]
    objects = UserManager()

    class Meta:
        constraints = [
            models.UniqueConstraint(Lower("email"), name="accounts_user_email_ci_unique"),
            models.UniqueConstraint(Lower("student_code"), name="accounts_user_student_code_ci_unique"),
            models.CheckConstraint(
                condition=models.Q(course__isnull=True) | models.Q(course__gte=1, course__lte=6),
                name="accounts_user_course_range",
            ),
        ]

    def save(self, *args, **kwargs):
        self.email = type(self).objects.normalize_email(self.email)
        if self.student_code is not None:
            self.student_code = self.student_code.strip().upper() or None
        super().save(*args, **kwargs)

    def __str__(self):
        return self.email


class EmailChallenge(models.Model):
    class Purpose(models.TextChoices):
        VERIFY_EMAIL = "verify_email", "Имэйл баталгаажуулах"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="email_challenges")
    purpose = models.CharField(max_length=20, choices=Purpose.choices)
    code_digest = models.CharField(max_length=64)
    expires_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)
    max_attempts = models.PositiveSmallIntegerField(default=5)
    consumed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["user", "purpose", "-created_at"], name="acct_challenge_lookup_idx"),
        ]
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.purpose}: {self.id}"
