from django.urls import path
from . import views

urlpatterns = [
    path('', views.add_post, name='add_post'),
    path('<int:post_id>/like/', views.toggle_like, name='toggle_like'),
    path('<int:post_id>/likes/', views.post_likes, name='post_likes'),
]
