
from django.urls import path
from .views import current_user, csrf_token, login_service, logout_service
from .register_views import register_service, resend_verification, verify_registration

urlpatterns = [
    path("csrf/", csrf_token, name="csrf"),
    path("me/", current_user, name="current_user"),
    path("logout/", logout_service, name="logout"),
    path("login/", login_service, name="login"),
    path("register/", register_service, name="register"),
    path("resend-verification/", resend_verification, name="resend_verification"),
    path(
        "register/verify/",
        verify_registration,
        name="verify_registration",
    ),
]
