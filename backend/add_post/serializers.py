from rest_framework import serializers
from .models import Post

MIN_COURSE = 1
MAX_COURSE = 6


class PostSerializer(serializers.ModelSerializer):
    # Accepts "1,2,4" (multipart form field); empty means everyone.
    audience_courses = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=32,
    )

    class Meta:
        model = Post
        fields = [
            'id',
            'title',
            'content',
            'image',
            'post_type',
            'price',
            'audience_courses',
            'created_at',
        ]

    def validate_audience_courses(self, value):
        courses = set()
        for item in value.split(','):
            item = item.strip()
            if not item:
                continue
            if not item.isdigit() or not (
                MIN_COURSE <= int(item) <= MAX_COURSE
            ):
                raise serializers.ValidationError(
                    'Курс 1–6 хооронд байна.'
                )
            courses.add(int(item))
        return ','.join(str(course) for course in sorted(courses))

    def validate(self, attrs):
        post_type = attrs.get('post_type')

        if post_type not in {'sell', 'rental'}:
            attrs['price'] = None

        return attrs
