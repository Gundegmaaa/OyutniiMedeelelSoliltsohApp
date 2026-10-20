from django.conf import settings
from django.contrib.auth import authenticate, login, logout
from django.db import IntegrityError, connection, transaction
from django.http import JsonResponse
from django.middleware.csrf import get_token
from django.shortcuts import render
from django.urls import reverse
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_protect
from django.views.decorators.http import require_GET
from rest_framework import status
from rest_framework.exceptions import Throttled, ValidationError
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from .exceptions import APIProblem
from .models import User
from .serializers import EmailSerializer, LoginSerializer, RegisterSerializer, UserSerializer, VerifyEmailSerializer
from .services import CooldownError, EmailDeliveryError, InvalidChallengeError, consume_challenge, issue_challenge
from .throttles import AuthEmailThrottle, AuthIPThrottle
from .verification import bind_pending_verification, clear_pending_verification, pending_verification_user

VERIFICATION_SENT = "Бүртгүүлэх боломжтой хаяг бол баталгаажуулах код мэйлээр илгээгдлээ."


def csrf_failure(request, reason=""):
    return JsonResponse({"error": {"code": "csrf_failed", "message": "CSRF токен буруу эсвэл байхгүй байна."}}, status=403)


@require_GET
def api_home(request):
    routes = [
        ("GET", "health", "Сервер болон өгөгдлийн сангийн төлөв"),
        ("GET", "accounts:csrf", "CSRF token авах"),
        ("POST", "accounts:register", "Бүртгүүлэх"),
        ("POST", "accounts:verify-email", "Мэйл баталгаажуулах"),
        ("POST", "accounts:resend-verification", "Баталгаажуулах код дахин авах"),
        ("POST", "accounts:login", "Нэвтрэх"),
        ("GET", "accounts:me", "Нэвтэрсэн хэрэглэгчийн мэдээлэл"),
        ("POST", "accounts:logout", "Системээс гарах"),
    ]
    endpoints = [
        {"method": method, "url": reverse(name), "description": description}
        for method, name, description in routes
    ]
    return render(request, "accounts/api_home.html", {"endpoints": endpoints})


@require_GET
def health(request):
    with connection.cursor() as cursor:
        cursor.execute("SELECT 1")
    return JsonResponse({"status": "ok"})


@method_decorator(csrf_protect, name="dispatch")
class ProtectedAPIView(APIView):
    """Require CSRF even for anonymous registration and login requests."""

    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response["Cache-Control"] = "no-store"
        return response


class PublicAuthAPIView(ProtectedAPIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [AuthIPThrottle, AuthEmailThrottle]


class CsrfView(ProtectedAPIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def get(self, request):
        return Response({"csrf_token": get_token(request)})


def send_verification(user):
    try:
        issue_challenge(user)
    except CooldownError as error:
        raise Throttled(wait=error.seconds, detail="Шинэ код авахын өмнө түр хүлээнэ үү.") from error
    except EmailDeliveryError as error:
        raise APIProblem(503, "email_delivery_failed", "Мэйл илгээж чадсангүй. Түр хүлээгээд дахин оролдоно уу.") from error


class RegisterView(PublicAuthAPIView):
    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        values = serializer.validated_data
        user = None
        try:
            with transaction.atomic():
                user = User.objects.filter(email=values["email"]).first()
                if user is None:
                    user = User.objects.create_user(
                        email=values["email"], display_name=values["display_name"],
                        first_name=values["first_name"], last_name=values["last_name"],
                        student_code=values["student_code"], course=values["course"],
                        password=values["password"],
                    )
                    send_verification(user)
        except IntegrityError:
            # Concurrent requests for the same address must not replace its password.
            user = User.objects.filter(email=values["email"]).first()
            if user is None:
                if User.objects.filter(student_code__iexact=values["student_code"]).exists():
                    raise ValidationError({"student_code": "Энэ оюутны код бүртгэлтэй байна."})
                raise
        # Only the account just registered can receive later verification codes.
        # Binding happens after the create/send transaction succeeds.
        bind_pending_verification(request, user)
        return Response({"detail": VERIFICATION_SENT, "email": values["email"]}, status=status.HTTP_202_ACCEPTED)


class VerifyEmailView(PublicAuthAPIView):
    def post(self, request):
        serializer = VerifyEmailSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        values = serializer.validated_data
        user = pending_verification_user(request, values["email"])
        try:
            consume_challenge(
                email=user.email, user_id=user.pk, code=values["code"], password=values["password"],
            )
        except InvalidChallengeError as error:
            raise APIProblem(400, "invalid_code", "Код буруу, хугацаа дууссан эсвэл ашиглагдсан байна.") from error
        clear_pending_verification(request)
        return Response({"detail": "Мэйл хаяг баталгаажлаа. Одоо нэвтэрч болно."})


class ResendVerificationView(PublicAuthAPIView):
    def post(self, request):
        serializer = EmailSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = pending_verification_user(request, serializer.validated_data["email"])
        try:
            send_verification(user)
        except InvalidChallengeError:
            # A parallel request may verify or deactivate this account
            # between the lookup and the service's locked recheck.
            clear_pending_verification(request)
        return Response({"detail": VERIFICATION_SENT}, status=status.HTTP_202_ACCEPTED)


class LoginView(PublicAuthAPIView):
    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        values = serializer.validated_data
        user = authenticate(request, email=values["email"], password=values["password"])
        if user is None:
            raise APIProblem(401, "invalid_credentials", "Мэйл эсвэл нууц үг буруу байна.")
        if not user.email_verified_at:
            bind_pending_verification(request, user)
            raise APIProblem(403, "email_not_verified", "Эхлээд мэйл хаягаа баталгаажуулна уу.")
        login(request, user)
        clear_pending_verification(request)
        request.session.set_expiry(settings.REMEMBER_ME_AGE if values["remember_me"] else 0)
        return Response({"user": UserSerializer(user).data, "csrf_token": get_token(request)})


class MeView(ProtectedAPIView):
    def get(self, request):
        return Response({"user": UserSerializer(request.user).data})


class LogoutView(ProtectedAPIView):
    def post(self, request):
        logout(request)
        return Response({"detail": "Системээс гарлаа."})
