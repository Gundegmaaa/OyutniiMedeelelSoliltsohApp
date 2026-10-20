from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers

from .models import User


class StrictSerializer(serializers.Serializer):
    def to_internal_value(self, data):
        if isinstance(data, dict):
            unknown = set(data) - set(self.fields)
            if unknown:
                raise serializers.ValidationError({name: ["Зөвшөөрөгдөөгүй талбар."] for name in sorted(unknown)})
        return super().to_internal_value(data)


class EmailSerializer(StrictSerializer):
    email = serializers.EmailField(max_length=254)

    def validate_email(self, value):
        return User.objects.normalize_email(value)


class RegisterSerializer(EmailSerializer):
    student_code = serializers.CharField(max_length=32)
    first_name = serializers.CharField(max_length=150)
    last_name = serializers.CharField(max_length=150)
    course = serializers.IntegerField(min_value=1, max_value=6)
    password = serializers.CharField(max_length=128, trim_whitespace=False, write_only=True)
    password_confirm = serializers.CharField(max_length=128, trim_whitespace=False, write_only=True)

    def validate_student_code(self, value):
        value = value.strip().upper()
        if (
            len(value) > 32 or not value[0].isalnum()
            or any(not character.isalnum() and character not in "_-" for character in value)
        ):
            raise serializers.ValidationError(
                "Оюутны код үсэг эсвэл тоогоор эхэлж, үсэг, тоо, _ болон - тэмдэгт агуулсан байна."
            )
        return value

    def validate(self, attrs):
        if attrs["password"] != attrs["password_confirm"]:
            raise serializers.ValidationError({"password_confirm": "Нууц үг таарахгүй байна."})
        # Existing accounts keep their profile and password. A repeated signup
        # may resume verification, but cannot overwrite someone else's details.
        email_exists = User.objects.filter(email=attrs["email"]).exists()
        if not email_exists and User.objects.filter(student_code__iexact=attrs["student_code"]).exists():
            raise serializers.ValidationError({"student_code": "Энэ оюутны код бүртгэлтэй байна."})
        attrs["display_name"] = f'{attrs["last_name"]} {attrs["first_name"]}'
        user = User(
            email=attrs["email"], display_name=attrs["display_name"],
            first_name=attrs["first_name"], last_name=attrs["last_name"],
        )
        try:
            validate_password(attrs["password"], user=user)
        except DjangoValidationError as error:
            raise serializers.ValidationError({"password": error.messages}) from error
        return attrs


class VerifyEmailSerializer(EmailSerializer):
    code = serializers.RegexField(r"^[0-9]{6}$", min_length=6, max_length=6, trim_whitespace=False)
    password = serializers.CharField(max_length=128, trim_whitespace=False, write_only=True)

    def validate(self, attrs):
        # Mailbox ownership establishes the final password. This also handles an
        # address that somebody else registered before its real owner arrived.
        try:
            validate_password(attrs["password"], user=User(email=attrs["email"]))
        except DjangoValidationError as error:
            raise serializers.ValidationError({"password": error.messages}) from error
        return attrs


class LoginSerializer(EmailSerializer):
    password = serializers.CharField(max_length=128, trim_whitespace=False, write_only=True)
    remember_me = serializers.BooleanField(default=False)


class UserSerializer(serializers.ModelSerializer):
    email_verified = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id", "email", "display_name", "first_name", "last_name",
            "student_code", "course", "role", "email_verified",
        ]
        read_only_fields = fields

    def get_email_verified(self, obj):
        return obj.email_verified_at is not None
