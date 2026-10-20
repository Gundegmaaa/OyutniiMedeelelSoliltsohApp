from rest_framework.authentication import SessionAuthentication
from rest_framework.exceptions import AuthenticationFailed


class VerifiedSessionAuthentication(SessionAuthentication):
    def authenticate_header(self, request):
        return "Session"

    def authenticate(self, request):
        result = super().authenticate(request)
        if result and not result[0].email_verified_at:
            raise AuthenticationFailed("Мэйл хаягаа баталгаажуулна уу.", code="email_not_verified")
        return result
