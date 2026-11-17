from rest_framework import serializers
from .models import Post


class PostSerializer(serializers.ModelSerializer):
    class Meta:
        model = Post
        fields = [
            'id',
            'title',
            'content',
            'image',
            'post_type',
            'price',
            'created_at',
        ]

    def validate(self, attrs):
        post_type = attrs.get('post_type')

        if post_type not in {'sell', 'rental'}:
            attrs['price'] = None

        return attrs
