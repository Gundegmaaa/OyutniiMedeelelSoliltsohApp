from django.contrib import admin
from django.urls import include, path

from accounts.views import api_home, health

urlpatterns = [
    path("", api_home, name="api-home"),
    path("health/", health, name="health"),
    path("admin/", admin.site.urls),
    path("api/v1/auth/", include("accounts.urls")),
]
