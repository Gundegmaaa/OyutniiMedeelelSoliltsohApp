from django.utils.crypto import salted_hmac
from rest_framework.throttling import SimpleRateThrottle


class AuthIPThrottle(SimpleRateThrottle):
    scope = "auth_ip"

    def get_cache_key(self, request, view):
        return self.cache_format % {"scope": self.scope, "ident": self.get_ident(request)}


class AuthEmailThrottle(SimpleRateThrottle):
    scope = "auth_email"

    def get_cache_key(self, request, view):
        data = request.data
        email = data.get("email") if isinstance(data, dict) else None
        if not isinstance(email, str):
            return None
        ident = salted_hmac("auth-email-throttle", email.strip().lower()).hexdigest()
        return self.cache_format % {"scope": self.scope, "ident": ident}
