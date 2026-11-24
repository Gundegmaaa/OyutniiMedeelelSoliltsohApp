class LessonSchedule {
  const LessonSchedule({
    required this.id,
    required this.weekday,
    required this.time,
    required this.subject,
    required this.room,
  });

  final String id;
  final int weekday;
  final String time;
  final String subject;
  final String room;

  factory LessonSchedule.fromJson(Map<String, dynamic> json) => LessonSchedule(
    id: json['id'].toString(),
    weekday: json['weekday'] as int,
    time: json['time'] as String,
    subject: json['subject'] as String,
    room: json['room'] as String? ?? '',
  );

  Map<String, Object?> toJson() => {
    'weekday': weekday,
    'time': time,
    'subject': subject,
    'room': room,
  };
}
