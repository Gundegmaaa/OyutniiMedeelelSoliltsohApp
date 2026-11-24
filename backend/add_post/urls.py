from django.urls import path
from . import views

urlpatterns = [
    path('calendar/', views.calendar_events, name='calendar_events'),
    path('calendar/<int:event_id>/', views.calendar_event_detail, name='calendar_event_detail'),
    path('lessons/', views.lesson_schedules, name='lesson_schedules'),
    path('lessons/<int:lesson_id>/', views.lesson_schedule_detail, name='lesson_schedule_detail'),
    path('<int:post_id>/', views.post_detail, name='post_detail'),
    path('', views.add_post, name='add_post'),
    path('<int:post_id>/like/', views.toggle_like, name='toggle_like'),
    path('<int:post_id>/likes/', views.post_likes, name='post_likes'),
]
