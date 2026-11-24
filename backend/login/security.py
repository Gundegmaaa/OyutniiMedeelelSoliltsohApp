from django.middleware.csrf import CsrfViewMiddleware
from rest_framework.response import Response


def csrf_rejection(request):
    """Enforce Django's CSRF check on session-backed DRF mutation routes."""
    middleware = CsrfViewMiddleware(lambda _request: None)
    rejected = middleware.process_view(
        request._request,
        lambda _request: None,
        (),
        {},
    )
    if rejected is None:
        return None
    return Response(
        {"message": "Хүсэлтийн CSRF баталгаажуулалт амжилтгүй."},
        status=403,
    )
