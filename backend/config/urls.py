
from django.contrib import admin
from django.conf import settings
from django.urls import path, include, re_path
from django.views.static import serve
from django.http import JsonResponse


def api_home(request):
    return JsonResponse({
        "success": True,
        "message": "Оюутны мэдээлэл солилцох системийн API ажиллаж байна.",
        "endpoints": {
            "login": "/api/v1/auth/login/",
            "register": "/api/v1/auth/register/",
            "verify_email": "/api/v1/auth/register/verify/",
            "posts": "/api/v1/posts/",
        }
    })


urlpatterns = [
    path("", api_home, name="api-home"),
    path("admin/", admin.site.urls),
    path("api/v1/auth/", include("login.urls")),
    path("api/v1/posts/", include("add_post.urls")),
    # Uploaded post images. Served by Django because the project has no
    # separate file host yet.
    re_path(
        r"^media/(?P<path>.*)$",
        serve,
        {"document_root": settings.MEDIA_ROOT},
    ),
]
