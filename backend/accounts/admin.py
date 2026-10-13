from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.contrib.auth.forms import UserChangeForm, UserCreationForm

from .models import AuthSession, EmailChallenge, TrustedDevice, User


class AccountCreationForm(UserCreationForm):
    class Meta(UserCreationForm.Meta):
        model = User
        fields = ("email", "full_name")


class AccountChangeForm(UserChangeForm):
    class Meta(UserChangeForm.Meta):
        model = User
        fields = "__all__"


@admin.register(User)
class AccountAdmin(UserAdmin):
    add_form = AccountCreationForm
    form = AccountChangeForm
    list_display = ("email", "full_name", "email_verified", "is_active", "is_staff")
    list_filter = ("email_verified", "is_active", "is_staff", "is_superuser")
    ordering = ("email",)
    search_fields = ("email", "full_name")
    fieldsets = (
        (None, {"fields": ("email", "password")}),
        ("Profile", {"fields": ("full_name", "email_verified")}),
        ("Permissions", {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")}),
        ("Dates", {"fields": ("last_login", "date_joined")}),
    )
    add_fieldsets = (
        (None, {"classes": ("wide",), "fields": ("email", "full_name", "password1", "password2")}),
    )


class ReadOnlyCredentialAdmin(admin.ModelAdmin):
    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False


@admin.register(EmailChallenge)
class EmailChallengeAdmin(ReadOnlyCredentialAdmin):
    list_display = ("email", "purpose", "attempts", "sends", "expires_at", "consumed_at")
    list_filter = ("purpose",)
    search_fields = ("email",)
    exclude = ("code_hash", "password_hash")


@admin.register(AuthSession)
class AuthSessionAdmin(ReadOnlyCredentialAdmin):
    list_display = ("user", "created_at", "expires_at", "last_seen_at")
    search_fields = ("user__email",)
    exclude = ("token_hash",)


@admin.register(TrustedDevice)
class TrustedDeviceAdmin(ReadOnlyCredentialAdmin):
    list_display = ("user", "name", "created_at", "expires_at", "last_used_at")
    search_fields = ("user__email", "name")
    exclude = ("token_hash",)
