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
        price = attrs.get('price')

        if post_type == 'sell' and price is None:
            raise serializers.ValidationError({
                'price': 'Бараа зарах үед үнэ оруулна уу.'
            })

        if post_type != 'sell':
            attrs['price'] = None

        return attrs