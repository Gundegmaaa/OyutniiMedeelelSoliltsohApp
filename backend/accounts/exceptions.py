from rest_framework.exceptions import APIException, ValidationError
from rest_framework.views import exception_handler


class APIProblem(APIException):
    def __init__(self, status_code, code, message):
        self.status_code = status_code
        super().__init__(detail=message, code=code)


def api_exception_handler(exc, context):
    response = exception_handler(exc, context)
    if response is None:
        return None
    if isinstance(exc, ValidationError):
        response.data = {"error": {
            "code": "validation_error",
            "message": "Оруулсан мэдээллээ шалгана уу.",
            "details": response.data,
        }}
    else:
        detail = getattr(exc, "detail", None)
        response.data = {"error": {
            "code": str(getattr(detail, "code", getattr(exc, "default_code", "request_failed"))),
            "message": str(response.data.get("detail", "Хүсэлтийг боловсруулах боломжгүй.")),
        }}
    return response
