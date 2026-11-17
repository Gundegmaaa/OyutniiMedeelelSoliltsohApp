from django.db import IntegrityError
from django.db.models import Count
from rest_framework.decorators import (
    authentication_classes,
    api_view,
    parser_classes,
    permission_classes,
)
from rest_framework.permissions import AllowAny
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.response import Response
from rest_framework import status

from login.models import TblUser

from .models import Post, PostReaction
from .serializers import PostSerializer


def _session_user(request):
    st_code = request.session.get('st_code')
    if not st_code:
        return None
    return TblUser.objects.filter(st_code=st_code).first()


def _person(user):
    if user is None:
        return None
    name = f'{user.user_lastname or ""} {user.user_firstname or ""}'.strip()
    return {
        'name': name or 'Оюутан',
        'first_name': user.user_firstname or '',
        'course': user.course_id,
    }


def _post_payload(post, request, viewer, authors, liked_ids, like_count):
    data = PostSerializer(post, context={'request': request}).data
    data['audience_courses'] = post.audience_list
    data['author'] = _person(authors.get(post.author_code))
    data['is_mine'] = bool(viewer and post.author_code == viewer.st_code)
    data['like_count'] = like_count
    data['liked'] = post.id in liked_ids
    return data


def _visible_to(post, viewer):
    audience = post.audience_list
    if not audience:
        return True
    if viewer is None:
        return False
    if post.author_code == viewer.st_code:
        return True
    return viewer.course_id in audience


def _visible_post_or_error(request, post_id):
    """Returns (viewer, post, None) or (None, None, error response)."""
    viewer = _session_user(request)
    if viewer is None:
        return None, None, Response(
            {'message': 'Нэвтрэх шаардлагатай.'},
            status=status.HTTP_401_UNAUTHORIZED,
        )
    post = Post.objects.filter(pk=post_id).first()
    if post is None or not _visible_to(post, viewer):
        return None, None, Response(
            {'message': 'Зар олдсонгүй.'},
            status=status.HTTP_404_NOT_FOUND,
        )
    return viewer, post, None


@api_view(['GET', 'POST'])
@authentication_classes([])
@permission_classes([AllowAny])
@parser_classes([MultiPartParser, FormParser])
def add_post(request):
    viewer = _session_user(request)

    if request.method == 'GET':
        posts = [
            post
            for post in Post.objects.annotate(
                like_count=Count('reactions')
            ).order_by('-created_at')
            if _visible_to(post, viewer)
        ]
        authors = {
            user.st_code: user
            for user in TblUser.objects.filter(
                st_code__in={p.author_code for p in posts if p.author_code}
            )
        }
        liked_ids = set()
        if viewer is not None:
            liked_ids = set(
                PostReaction.objects.filter(
                    st_code=viewer.st_code,
                    post__in=posts,
                ).values_list('post_id', flat=True)
            )
        return Response([
            _post_payload(
                post, request, viewer, authors, liked_ids, post.like_count
            )
            for post in posts
        ])

    serializer = PostSerializer(data=request.data)

    if serializer.is_valid():
        post = serializer.save(
            author_code=viewer.st_code if viewer else ''
        )
        authors = {viewer.st_code: viewer} if viewer else {}

        return Response(
            {
                'message': 'Пост амжилттай нэмэгдлээ.',
                'data': _post_payload(
                    post, request, viewer, authors, set(), 0
                ),
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


@api_view(['POST'])
@authentication_classes([])
@permission_classes([AllowAny])
@parser_classes([JSONParser, FormParser])
def toggle_like(request, post_id):
    """Adds the signed-in student's reaction, or removes it if present."""
    viewer, post, error = _visible_post_or_error(request, post_id)
    if error is not None:
        return error
    deleted, _ = PostReaction.objects.filter(
        post=post, st_code=viewer.st_code
    ).delete()
    liked = not deleted
    if liked:
        try:
            PostReaction.objects.create(post=post, st_code=viewer.st_code)
        except IntegrityError:
            pass  # A parallel request already recorded the reaction.
    return Response({
        'liked': liked,
        'like_count': post.reactions.count(),
    })


@api_view(['GET'])
@authentication_classes([])
@permission_classes([AllowAny])
def post_likes(request, post_id):
    """Lists who reacted to a post, newest first."""
    viewer, post, error = _visible_post_or_error(request, post_id)
    if error is not None:
        return error
    codes = list(
        post.reactions.order_by('-created_at').values_list(
            'st_code', flat=True
        )
    )
    users = {
        user.st_code: user
        for user in TblUser.objects.filter(st_code__in=codes)
    }
    return Response({
        'like_count': len(codes),
        'people': [
            _person(users[code]) for code in codes if code in users
        ],
    })
