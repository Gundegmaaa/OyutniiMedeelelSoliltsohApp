from django.urls import path

from . import views

app_name = "accounts"
urlpatterns = [
    path("register/", views.RegisterView.as_view(), name="register"),
    path("register/verify/", views.RegisterVerifyView.as_view(), name="register-verify"),
    path("login/", views.LoginView.as_view(), name="login"),
    path("login/verify/", views.LoginVerifyView.as_view(), name="login-verify"),
    path("resend-code/", views.ResendCodeView.as_view(), name="resend-code"),
    path("me/", views.MeView.as_view(), name="me"),
    path("logout/", views.LogoutView.as_view(), name="logout"),
    path("devices/", views.DevicesView.as_view(), name="devices"),
    path("devices/<uuid:device_id>/", views.DeviceDetailView.as_view(), name="device-detail"),
]
