from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import EmailChallenge, User


@admin.register(User)
class EmailUserAdmin(UserAdmin):
    ordering = ("email",)
    list_display = ("email", "student_code", "display_name", "course", "role", "email_verified_at", "is_active", "is_staff")
    list_filter = ("course", "role", "is_active", "is_staff", "is_superuser")
    search_fields = ("email", "student_code", "display_name", "first_name", "last_name")
    readonly_fields = ("id", "last_login", "date_joined")
    fieldsets = (
        (None, {"fields": ("id", "email", "password")}),
        ("Profile", {"fields": ("display_name", "first_name", "last_name", "student_code", "course", "role")}),
        ("Verification", {"fields": ("email_verified_at",)}),
        (
            "Permissions",
            {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")},
        ),
        ("Dates", {"fields": ("last_login", "date_joined")}),
    )
    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": ("email", "display_name", "first_name", "last_name", "student_code", "course", "password1", "password2", "role"),
            },
        ),
    )


@admin.register(EmailChallenge)
class EmailChallengeAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "purpose", "expires_at", "attempts", "consumed_at")
    list_filter = ("purpose",)
    search_fields = ("user__email",)
    readonly_fields = (
        "id", "user", "purpose", "expires_at", "attempts", "max_attempts",
        "consumed_at", "created_at",
    )
    fields = readonly_fields

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
