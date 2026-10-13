import uuid

from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models


class UserManager(BaseUserManager):
    use_in_migrations = True

    @classmethod
    def normalize_email(cls, email):
        return super().normalize_email(email).strip().lower()

    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError("An email address is required.")
        user = self.model(email=self.normalize_email(email), **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("email_verified", True)
        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superusers must have is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superusers must have is_superuser=True.")
        return self.create_user(email, password, **extra_fields)


class User(AbstractUser):
    username = None
    email = models.EmailField(unique=True)
    full_name = models.CharField(max_length=150, blank=True)
    email_verified = models.BooleanField(default=False)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []
    objects = UserManager()

    def save(self, *args, **kwargs):
        self.email = User.objects.normalize_email(self.email)
        return super().save(*args, **kwargs)

    def get_full_name(self):
        return self.full_name

    def get_short_name(self):
        return self.full_name.split()[0] if self.full_name.strip() else self.email

    def __str__(self):
        return self.email


class EmailChallenge(models.Model):
    class Purpose(models.TextChoices):
        REGISTER = "register", "Registration"
        LOGIN = "login", "Login"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    purpose = models.CharField(max_length=16, choices=Purpose.choices)
    email = models.EmailField()
    user = models.ForeignKey(
        User, on_delete=models.CASCADE, null=True, blank=True, related_name="email_challenges"
    )
    full_name = models.CharField(max_length=150, blank=True)
    password_hash = models.CharField(max_length=128, blank=True)
    code_hash = models.CharField(max_length=64)
    remember_device = models.BooleanField(default=False)
    device_name = models.CharField(max_length=100, blank=True)
    attempts = models.PositiveSmallIntegerField(default=0)
    sends = models.PositiveSmallIntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)
    last_sent_at = models.DateTimeField()
    expires_at = models.DateTimeField()
    consumed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=["email", "purpose", "consumed_at"], name="challenge_email_purpose_idx"),
            models.Index(fields=["expires_at"], name="challenge_expiry_idx"),
        ]

    def __str__(self):
        return f"{self.purpose}: {self.email}"


class TrustedDevice(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="trusted_devices")
    token_hash = models.CharField(max_length=64, unique=True)
    name = models.CharField(max_length=100, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(db_index=True)
    last_used_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"{self.user.email}: {self.name or 'Remembered device'}"


class AuthSession(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="auth_sessions")
    token_hash = models.CharField(max_length=64, unique=True)
    trusted_device = models.ForeignKey(
        TrustedDevice, on_delete=models.CASCADE, null=True, blank=True, related_name="sessions"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(db_index=True)
    last_seen_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"{self.user.email}: {self.id}"
