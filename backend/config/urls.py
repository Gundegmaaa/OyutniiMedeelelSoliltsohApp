
from django.urls import path
from .views import login_service
from .register_views import register_service, verify_registration

urlpatterns = [
    path("login/", login_service, name="login"),
    path("register/", register_service, name="register"),
    path(
        "register/verify/",
        verify_registration,
        name="verify_registration",
    ),
]