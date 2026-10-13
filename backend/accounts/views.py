import math

from django.conf import settings
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from . import services
from .models import AuthSession, EmailChallenge, TrustedDevice, User
from .serializers import (
    ChallengeSerializer, DeviceSerializer, LoginSerializer, LogoutSerializer,
    RegisterSerializer, UserSerializer, VerifySerializer,
)
from .throttles import AuthEmailThrottle, AuthIPThrottle


def seconds_until(value):
    return max(0, math.ceil((value - timezone.now()).total_seconds()))


def challenge_response(challenge):
    elapsed = (timezone.now() - challenge.last_sent_at).total_seconds()
    return Response({
        "verification_required": True,
        "challenge_id": str(challenge.id),
        "purpose": challenge.purpose,
        "expires_in": seconds_until(challenge.expires_at),
        "resend_after": max(0, math.ceil(settings.AUTH_CODE_RESEND_SECONDS - elapsed)),
        "message": "Баталгаажуулах код мэйл хаяг руу илгээгдлээ.",
    }, status=202)


def token_response(result):
    data = {
        "token": result["token"],
        "token_type": "Bearer",
        "expires_in": seconds_until(result["session"].expires_at),
        "user": UserSerializer(result["user"]).data,
    }
    device = result.get("trusted_device")
    if device:
        data.update(device_id=str(device.id), device_expires_in=seconds_until(device.expires_at))
    if result.get("device_token"):
        data["device_token"] = result["device_token"]
    return Response(data)


class AuthAPIView(APIView):
    """Auth responses contain credentials and must not be cached."""
    def handle_exception(self, exc):
        if isinstance(exc, services.APIError):
            data = {"error": exc.code, "message": exc.message}
            headers = {}
            if exc.retry_after is not None:
                data["retry_after"] = exc.retry_after
                headers["Retry-After"] = str(exc.retry_after)
            return Response(data, status=exc.status, headers=headers)
        return super().handle_exception(exc)

    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response["Cache-Control"] = "no-store"
        return response


class PublicAuthAPIView(AuthAPIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_classes = [AuthIPThrottle, AuthEmailThrottle]


class RegisterView(PublicAuthAPIView):
    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return challenge_response(services.register(**serializer.validated_data))


class LoginView(PublicAuthAPIView):
    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        result = services.start_login(**serializer.validated_data)
        return token_response(result) if result["authenticated"] else challenge_response(result["challenge"])


class VerifyView(PublicAuthAPIView):
    purpose = None

    def post(self, request):
        serializer = VerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return token_response(services.verify(expected_purpose=self.purpose, **serializer.validated_data))


class RegisterVerifyView(VerifyView):
    purpose = EmailChallenge.Purpose.REGISTER


class LoginVerifyView(VerifyView):
    purpose = EmailChallenge.Purpose.LOGIN


class ResendCodeView(PublicAuthAPIView):
    def post(self, request):
        serializer = ChallengeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return challenge_response(services.resend(**serializer.validated_data))


class MeView(AuthAPIView):
    def get(self, request):
        return Response(UserSerializer(request.user).data)


class LogoutView(AuthAPIView):
    def post(self, request):
        serializer = LogoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        services.revoke_session(request.auth, **serializer.validated_data)
        return Response(status=204)


class DevicesView(AuthAPIView):
    def get(self, request):
        devices = request.user.trusted_devices.filter(expires_at__gt=timezone.now()).order_by("-created_at")
        return Response(DeviceSerializer(devices, many=True).data)


class DeviceDetailView(AuthAPIView):
    def delete(self, request, device_id):
        with transaction.atomic():
            User.objects.select_for_update().get(pk=request.user.pk)
            device = get_object_or_404(TrustedDevice.objects.select_for_update(), id=device_id, user=request.user)
            AuthSession.objects.filter(user=request.user, trusted_device=device).delete()
            device.delete()
        return Response(status=204)


class HealthView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        return Response({"status": "ok"})
