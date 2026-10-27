
from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse


def api_home(request):
    return JsonResponse({
        "success": True,
        "message": "Оюутны мэдээлэл солилцох системийн API ажиллаж байна.",
        "endpoints": {
            "login": "/api/v1/auth/login/",
            "register": "/api/v1/auth/register/",
            "verify_email": "/api/v1/auth/register/verify/",
        }
    })


urlpatterns = [
    path("", api_home, name="api-home"),
    path("admin/", admin.site.urls),
    path("api/v1/auth/", include("login.urls")),
]
