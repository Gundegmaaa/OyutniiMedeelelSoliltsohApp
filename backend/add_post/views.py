
from rest_framework.decorators import (
    api_view,
    parser_classes,
    permission_classes,
)
from rest_framework.permissions import AllowAny
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from rest_framework import status

from .serializers import PostSerializer


@api_view(['POST'])
@permission_classes([AllowAny])
@parser_classes([MultiPartParser, FormParser])
def add_post(request):
    serializer = PostSerializer(data=request.data)

    if serializer.is_valid():
        post = serializer.save()

        # Зөвхөн бараа зарах үед үнэ хадгална
        if post.post_type != 'sell':
            post.price = None
            post.save(update_fields=['price'])

        return Response(
            {
                'message': 'Пост амжилттай нэмэгдлээ.',
                'data': PostSerializer(
                    post,
                    context={'request': request}
                ).data
            },
            status=status.HTTP_201_CREATED
        )

    return Response(
        {
            'message': 'Мэдээлэл буруу байна.',
            'errors': serializer.errors
        },
        status=status.HTTP_400_BAD_REQUEST
    )
