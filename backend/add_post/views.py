from django.db import IntegrityError
from django.db.models import Count
from django.contrib.auth import get_user_model
from datetime import date, time
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

from .models import CalendarEvent, LessonSchedule, Post, PostReaction
from .serializers import PostSerializer
from login.models import role_for_student
from login.security import csrf_rejection


def _session_user(request):
    st_code = request.session.get('st_code')
    if not st_code:
        return None
    return TblUser.objects.filter(st_code=st_code).first()


def _session_role(request):
    admin_id = request.session.get('admin_user_id')
    if admin_id and get_user_model().objects.filter(
        pk=admin_id, is_active=True, is_superuser=True
    ).exists():
        return 'admin'
    st_code = request.session.get('st_code')
    if not st_code or not TblUser.objects.filter(st_code=st_code).exists():
        return None
    return role_for_student(st_code)


def _calendar_payload(event):
    return {
        'id': str(event.pk),
        'title': event.title,
        'date': event.date.isoformat(),
        'type': event.event_type,
        'notes': event.notes,
        'minutes': event.minutes,
    }


def _calendar_values(data, partial=False):
    values = {}
    if not partial or 'title' in data:
        title = data.get('title')
        if not isinstance(title, str) or not title.strip():
            return None, 'Гарчиг оруулна уу.'
        values['title'] = title.strip()[:255]
    if not partial or 'date' in data:
        try:
            values['date'] = date.fromisoformat(data.get('date', ''))
        except (TypeError, ValueError):
            return None, 'Огноог YYYY-MM-DD хэлбэрээр оруулна уу.'
    if not partial or 'type' in data:
        event_type = data.get('type')
        allowed = {item[0] for item in CalendarEvent.EVENT_TYPES}
        if event_type not in allowed:
            return None, 'Хуваарийн төрлийг сонгоно уу.'
        values['event_type'] = event_type
    if not partial or 'notes' in data:
        notes = data.get('notes', '')
        if not isinstance(notes, str):
            return None, 'Тайлбар текст байх ёстой.'
        values['notes'] = notes
    if not partial or 'minutes' in data:
        minutes = data.get('minutes')
        if minutes in ('', None):
            values['minutes'] = None
        elif isinstance(minutes, int) and 0 <= minutes <= 1439:
            values['minutes'] = minutes
        else:
            return None, 'Цаг 0-1439 минутын хооронд байна.'
    return values, None


@api_view(['GET', 'POST'])
@authentication_classes([])
@permission_classes([AllowAny])
@parser_classes([JSONParser])
def calendar_events(request):
    if request.method == 'GET':
        return Response([_calendar_payload(event) for event in CalendarEvent.objects.all()])
    csrf_error = csrf_rejection(request)
    if csrf_error:
        return csrf_error
    if _session_role(request) not in {'teacher', 'admin'}:
        return Response({'message': 'Хуваарь засах эрх шаардлагатай.'}, status=403)
    values, error = _calendar_values(request.data)
    if error:
        return Response({'message': error}, status=400)
    values['created_by'] = request.session.get('st_code', 'admin')
    event = CalendarEvent.objects.create(**values)
    return Response(_calendar_payload(event), status=201)


@api_view(['PATCH', 'PUT', 'DELETE'])
@authentication_classes([])
@permission_classes([AllowAny])
@parser_classes([JSONParser])
def calendar_event_detail(request, event_id):
    csrf_error = csrf_rejection(request)
    if csrf_error:
        return csrf_error
    if _session_role(request) not in {'teacher', 'admin'}:
        return Response({'message': 'Хуваарь засах эрх шаардлагатай.'}, status=403)
    event = CalendarEvent.objects.filter(pk=event_id).first()
    if event is None:
        return Response({'message': 'Хуваарь олдсонгүй.'}, status=404)
    if request.method == 'DELETE':
        event.delete()
        return Response(status=204)
    values, error = _calendar_values(request.data, partial=request.method == 'PATCH')
    if error:
        return Response({'message': error}, status=400)
    for key, value in values.items():
        setattr(event, key, value)
    event.save()
    return Response(_calendar_payload(event))


def _lesson_payload(lesson):
    return {
        'id': lesson.pk,
        'weekday': lesson.weekday,
        'time': lesson.start_time.strftime('%H:%M'),
        'subject': lesson.subject,
        'room': lesson.room,
    }


def _lesson_values(data, partial=False):
    values = {}
    if not partial or 'weekday' in data:
        weekday = data.get('weekday')
        if not isinstance(weekday, int) or weekday < 0 or weekday > 6:
            return None, 'Гарагийн утга 0-6 байна.'
        values['weekday'] = weekday
    if not partial or 'time' in data:
        try:
            values['start_time'] = time.fromisoformat(data.get('time', ''))
        except (TypeError, ValueError):
            return None, 'Цагийг HH:MM хэлбэрээр оруулна уу.'
    if not partial or 'subject' in data:
        subject = data.get('subject')
        if not isinstance(subject, str) or not subject.strip():
            return None, 'Хичээлийн нэр оруулна уу.'
        values['subject'] = subject.strip()[:255]
    if not partial or 'room' in data:
        room = data.get('room', '')
        if not isinstance(room, str):
            return None, 'Өрөөний дугаар текст байна.'
        values['room'] = room.strip()[:64]
    return values, None


@api_view(['GET', 'POST'])
@authentication_classes([])
@permission_classes([AllowAny])
@parser_classes([JSONParser])
def lesson_schedules(request):
    if request.method == 'GET':
        return Response([_lesson_payload(lesson) for lesson in LessonSchedule.objects.all()])
    csrf_error = csrf_rejection(request)
    if csrf_error:
        return csrf_error
    if _session_role(request) not in {'teacher', 'admin'}:
        return Response({'message': 'Хуваарь засах эрх шаардлагатай.'}, status=403)
    values, error = _lesson_values(request.data)
    if error:
        return Response({'message': error}, status=400)
    lesson = LessonSchedule.objects.create(**values)
    return Response(_lesson_payload(lesson), status=201)


@api_view(['PATCH', 'PUT', 'DELETE'])
@authentication_classes([])
@permission_classes([AllowAny])
@parser_classes([JSONParser])
def lesson_schedule_detail(request, lesson_id):
    csrf_error = csrf_rejection(request)
    if csrf_error:
        return csrf_error
    if _session_role(request) not in {'teacher', 'admin'}:
        return Response({'message': 'Хуваарь засах эрх шаардлагатай.'}, status=403)
    lesson = LessonSchedule.objects.filter(pk=lesson_id).first()
    if lesson is None:
        return Response({'message': 'Хичээлийн хуваарь олдсонгүй.'}, status=404)
    if request.method == 'DELETE':
        lesson.delete()
        return Response(status=204)
    values, error = _lesson_values(request.data, partial=request.method == 'PATCH')
    if error:
        return Response({'message': error}, status=400)
    for key, value in values.items():
        setattr(lesson, key, value)
    lesson.save()
    return Response(_lesson_payload(lesson))


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
    author = _person(authors.get(post.author_code))
    if author is None and post.author_code.startswith('admin:'):
        author = {'name': 'Сургалтын алба', 'first_name': 'Сургалтын алба', 'course': None}
    data['author'] = author
    data['is_mine'] = bool(viewer and post.author_code == viewer.st_code)
    data['like_count'] = like_count
    data['liked'] = post.id in liked_ids
    return data


def _visible_to(post, viewer, role=None):
    if role in {'teacher', 'admin'}:
        return True
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
        role = _session_role(request)
        posts = [
            post
            for post in Post.objects.annotate(
                like_count=Count('reactions')
            ).order_by('-created_at')
            if _visible_to(post, viewer, role)
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

    csrf_error = csrf_rejection(request)
    if csrf_error:
        return csrf_error
    role = _session_role(request)
    if role is None:
        return Response({'message': 'Нэвтрэх шаардлагатай.'}, status=401)
    if role not in {'teacher', 'admin'} and request.data.get('post_type') == 'teacher':
        return Response({'message': 'Зөвхөн багш, сургалтын алба зарлал нийтэлнэ.'}, status=403)

    serializer = PostSerializer(data=request.data)

    if serializer.is_valid():
        author_code = request.session.get('st_code')
        if not author_code:
            author_code = f"admin:{request.session.get('admin_user_id')}"
        post = serializer.save(
            author_code=author_code
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


@api_view(['PATCH', 'PUT', 'DELETE'])
@authentication_classes([])
@permission_classes([AllowAny])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def post_detail(request, post_id):
    csrf_error = csrf_rejection(request)
    if csrf_error:
        return csrf_error
    role = _session_role(request)
    post = Post.objects.filter(pk=post_id).first()
    if post is None:
        return Response({'message': 'Зар олдсонгүй.'}, status=404)
    st_code = request.session.get('st_code')
    actor_code = st_code or (
        f"admin:{request.session.get('admin_user_id')}"
        if request.session.get('admin_user_id') else None
    )
    if role is None:
        return Response({'message': 'Нэвтрэх шаардлагатай.'}, status=401)
    if role not in {'teacher', 'admin'} and post.author_code != actor_code:
        return Response({'message': 'Энэ зарыг өөрчлөх эрхгүй.'}, status=403)
    if (
        role not in {'teacher', 'admin'}
        and request.data.get('post_type', post.post_type) == 'teacher'
    ):
        return Response({'message': 'Багшийн зарлалыг засах эрхгүй.'}, status=403)
    if request.method == 'DELETE':
        post.delete()
        return Response(status=204)

    serializer = PostSerializer(
        post,
        data=request.data,
        partial=request.method == 'PATCH',
        context={'request': request},
    )
    if not serializer.is_valid():
        return Response(
            {'message': 'Зарын мэдээлэл буруу байна.', 'errors': serializer.errors},
            status=400,
        )
    serializer.save()
    return Response({'message': 'Зар шинэчлэгдлээ.', 'data': serializer.data})


@api_view(['POST'])
@authentication_classes([])
@permission_classes([AllowAny])
@parser_classes([JSONParser, FormParser])
def toggle_like(request, post_id):
    """Adds the signed-in student's reaction, or removes it if present."""
    csrf_error = csrf_rejection(request)
    if csrf_error:
        return csrf_error
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
