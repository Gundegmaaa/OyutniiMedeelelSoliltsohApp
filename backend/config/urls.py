
from django.contrib import admin
from django.urls import path

from login.views import login_service
from login.register_views import (
    register_service,
    verify_registration,
)

urlpatterns = [
    path("admin/", admin.site.urls),

    path(
        "api/v1/auth/login/",
        login_service,
        name="login",
    ),

    path(
        "api/v1/auth/register/",
        register_service,
        name="register",
    ),

    path(
        "api/v1/auth/verify-email/",
        verify_registration,
        name="verify-email",
    ),
]