import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_event.dart';

abstract interface class CalendarEventStore {
  Future<List<CalendarEvent>> load();

  Future<void> save(List<CalendarEvent> events);
}

class SharedPreferencesCalendarEventStore implements CalendarEventStore {
  static const storageKey = 'mtc_calendar_events_v1';

  @override
  Future<List<CalendarEvent>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.get(storageKey);
    if (saved == null) return [];
    if (saved is! String) {
      throw const FormatException(
        'Saved calendar events must be a JSON string',
      );
    }
    final decoded = jsonDecode(saved);
    if (decoded is! List) {
      throw const FormatException('Saved calendar events must be a JSON list');
    }
    return decoded.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException(
          'Each saved calendar event must be an object',
        );
      }
      return CalendarEvent.fromJson(item);
    }).toList();
  }

  @override
  Future<void> save(List<CalendarEvent> events) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      storageKey,
      jsonEncode(events.map((event) => event.toJson()).toList()),
    );
    if (!saved) {
      throw StateError('Could not save calendar events');
    }
  }
}
