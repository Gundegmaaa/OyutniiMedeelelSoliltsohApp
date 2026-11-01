enum CalendarEventType {
  exam('Шалгалт'),
  assignment('Бие даалт'),
  seminar('Семинар'),
  other('Бусад');

  const CalendarEventType(this.label);

  final String label;
}

/// A calendar date and optional local time, independent of time zones.
class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.title,
    required DateTime date,
    required this.type,
    this.notes = '',
    this.minutes,
  }) : date = DateTime(date.year, date.month, date.day) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Must not be empty');
    }
    if (date.year < 1 || date.year > 9999) {
      throw ArgumentError.value(
        date,
        'date',
        'Year must be between 1 and 9999',
      );
    }
    if (minutes != null && (minutes! < 0 || minutes! > 1439)) {
      throw ArgumentError.value(
        minutes,
        'minutes',
        'Must be between 0 and 1439',
      );
    }
  }

  final String id;
  final String title;
  final DateTime date;
  final CalendarEventType type;
  final String notes;

  /// Minutes after midnight; null means an all-day event.
  final int? minutes;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'date':
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
    'type': type.name,
    'notes': notes,
    'minutes': minutes,
  };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final dateText = json['date'];
    final typeName = json['type'];
    final notes = json['notes'] ?? '';
    final minutes = json['minutes'];

    if (id is! String || id.trim().isEmpty) {
      throw const FormatException(
        'Calendar event id must be a nonempty string',
      );
    }
    if (title is! String || title.trim().isEmpty) {
      throw const FormatException(
        'Calendar event title must be a nonempty string',
      );
    }
    if (dateText is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateText)) {
      throw const FormatException('Calendar event date must use YYYY-MM-DD');
    }
    final year = int.parse(dateText.substring(0, 4));
    final month = int.parse(dateText.substring(5, 7));
    final day = int.parse(dateText.substring(8, 10));
    final date = DateTime(year, month, day);
    if (year < 1 ||
        date.year != year ||
        date.month != month ||
        date.day != day) {
      throw const FormatException('Calendar event date is invalid');
    }
    final matchingTypes = CalendarEventType.values.where(
      (type) => type.name == typeName,
    );
    if (matchingTypes.isEmpty) {
      throw const FormatException('Calendar event type is invalid');
    }
    if (notes is! String) {
      throw const FormatException('Calendar event notes must be a string');
    }
    if (minutes != null && (minutes is! int || minutes < 0 || minutes > 1439)) {
      throw const FormatException(
        'Calendar event minutes must be an integer between 0 and 1439',
      );
    }

    return CalendarEvent(
      id: id,
      title: title,
      date: date,
      type: matchingTypes.single,
      notes: notes,
      minutes: minutes as int?,
    );
  }
}
