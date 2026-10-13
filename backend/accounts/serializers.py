from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers

from .models import TrustedDevice, User


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ("id", "email", "full_name", "email_verified")
        read_only_fields = fields


class EmailSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=254)

    def validate_email(self, value):
        return User.objects.normalize_email(value)


class RegisterSerializer(EmailSerializer):
    password = serializers.CharField(write_only=True, trim_whitespace=False, max_length=128)
    full_name = serializers.CharField(max_length=150, required=False, allow_blank=True, default="")

    def validate(self, attrs):
        try:
            validate_password(attrs["password"], User(email=attrs["email"], full_name=attrs["full_name"]))
        except DjangoValidationError as exc:
            raise serializers.ValidationError({"password": exc.messages}) from None
        return attrs


class LoginSerializer(EmailSerializer):
    password = serializers.CharField(write_only=True, trim_whitespace=False, max_length=128)
    remember_device = serializers.BooleanField(required=False, default=False)
    device_name = serializers.CharField(max_length=100, required=False, allow_blank=True, default="")
    device_token = serializers.CharField(max_length=128, required=False, allow_blank=True, default="", write_only=True)


class ChallengeSerializer(serializers.Serializer):
    challenge_id = serializers.UUIDField()


class VerifySerializer(ChallengeSerializer):
    code = serializers.RegexField(r"\A[0-9]{6}\Z", min_length=6, max_length=6, trim_whitespace=False)


class LogoutSerializer(serializers.Serializer):
    forget_device = serializers.BooleanField(required=False, default=False)


class DeviceSerializer(serializers.ModelSerializer):
    class Meta:
        model = TrustedDevice
        fields = ("id", "name", "created_at", "expires_at", "last_used_at")
        read_only_fields = fields
