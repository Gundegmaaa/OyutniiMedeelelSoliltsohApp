
from rest_framework.decorators import (
    authentication_classes,
    api_view,
    parser_classes,
    permission_classes,
)
from rest_framework.permissions import AllowAny
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from rest_framework import status

from .models import Post
from .serializers import PostSerializer


@api_view(['GET', 'POST'])
@authentication_classes([])
@permission_classes([AllowAny])
@parser_classes([MultiPartParser, FormParser])
def add_post(request):
    if request.method == 'GET':
        posts = Post.objects.order_by('-created_at')
        return Response(PostSerializer(
            posts,
            many=True,
            context={'request': request},
        ).data)

    serializer = PostSerializer(data=request.data)

    if serializer.is_valid():
        post = serializer.save()

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
