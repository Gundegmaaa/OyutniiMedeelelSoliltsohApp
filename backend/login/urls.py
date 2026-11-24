
from django.urls import path
from .views import current_user, csrf_token, login_service, logout_service
from .register_views import register_service, resend_verification, verify_registration
from .admin_views import set_user_role, users

urlpatterns = [
    path("csrf/", csrf_token, name="csrf"),
    path("me/", current_user, name="current_user"),
    path("logout/", logout_service, name="logout"),
    path("admin/users/", users, name="admin-users"),
    path("admin/users/<str:st_code>/role/", set_user_role, name="admin-user-role"),
    path("login/", login_service, name="login"),
    path("register/", register_service, name="register"),
    path("resend-verification/", resend_verification, name="resend_verification"),
    path(
        "register/verify/",
        verify_registration,
        name="verify_registration",
    ),
]
