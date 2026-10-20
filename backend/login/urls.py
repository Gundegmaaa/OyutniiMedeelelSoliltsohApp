from django.urls import path
from .views import login_service
from .register_views import register_service

urlpatterns = [
    path("login/", login_service, name="login"),
    path("register/", register_service, name="register"),
]