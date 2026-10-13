from rest_framework.views import exception_handler as drf_exception_handler


def exception_handler(exc, context):
    response = drf_exception_handler(exc, context)
    if response is not None:
        detail = response.data
        if isinstance(detail, dict) and "detail" in detail:
            message = str(detail["detail"])
            code = getattr(detail["detail"], "code", "request_error")
            response.data = {"error": code, "message": message}
        else:
            response.data = {
                "error": "validation_error",
                "message": "Request fields are invalid.",
                "fields": detail,
            }
    return response
