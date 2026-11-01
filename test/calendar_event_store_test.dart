import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtc_student_hub/models/calendar_event.dart';
import 'package:mtc_student_hub/services/calendar_event_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('round trip keeps a calendar date and optional local time', () {
    final exam = CalendarEvent(
      id: 'exam-1',
      title: 'Математикийн шалгалт',
      date: DateTime.utc(2026, 10, 20, 23, 59),
      type: CalendarEventType.exam,
      notes: '204 тоот',
      minutes: 9 * 60 + 30,
    );

    final json = exam.toJson();
    expect(json['date'], '2026-10-20');
    final restored = CalendarEvent.fromJson(json);
    expect(restored.date, DateTime(2026, 10, 20));
    expect(restored.date.isUtc, isFalse);
    expect(restored.type, CalendarEventType.exam);
    expect(restored.title, exam.title);
    expect(restored.notes, '204 тоот');
    expect(restored.minutes, 570);

    final allDay = CalendarEvent.fromJson({
      'id': 'assignment-1',
      'title': 'Бие даалт өгөх',
      'date': '2026-10-21',
      'type': 'assignment',
    });
    expect(allDay.minutes, isNull);
    expect(allDay.notes, isEmpty);
    expect(allDay.type, CalendarEventType.assignment);
  });

  test('rejects invalid dates, types, and local times in saved events', () {
    final valid = <String, dynamic>{
      'id': 'event-1',
      'title': 'Семинар',
      'date': '2026-10-20',
      'type': 'seminar',
      'notes': '',
      'minutes': 0,
    };
    final invalidFields = <Map<String, dynamic>>[
      {'id': ''},
      {'title': 12},
      {'date': '2026-02-30'},
      {'date': '2026-10-20T23:00:00Z'},
      {'date': '0000-01-01'},
      {'type': 'unknown'},
      {'notes': 123},
      {'minutes': -1},
      {'minutes': 1440},
      {'minutes': 30.5},
    ];
    for (final fields in invalidFields) {
      expect(
        () => CalendarEvent.fromJson({...valid, ...fields}),
        throwsFormatException,
        reason: 'Must reject $fields',
      );
    }
  });

  test('save and reload retain events, edits and deletions', () async {
    final store = SharedPreferencesCalendarEventStore();
    expect(await store.load(), isEmpty);
    final exam = CalendarEvent(
      id: 'exam-1',
      title: 'Шалгалт',
      date: DateTime(2026, 10, 20),
      type: CalendarEventType.exam,
    );
    final seminar = CalendarEvent(
      id: 'seminar-1',
      title: 'Семинар тавих',
      date: DateTime(2026, 10, 22),
      type: CalendarEventType.seminar,
      minutes: 1439,
    );
    await store.save([exam, seminar]);

    // A new store instance represents re-opening the calendar.
    final reloaded = await SharedPreferencesCalendarEventStore().load();
    expect(reloaded.map((event) => event.toJson()), [
      exam.toJson(),
      seminar.toJson(),
    ]);

    final updatedExam = CalendarEvent(
      id: exam.id,
      title: 'Шинэчилсэн шалгалт',
      date: DateTime(2026, 10, 23),
      type: CalendarEventType.exam,
      minutes: 600,
    );
    await store.save([updatedExam]);
    final afterRemoval = await store.load();
    expect(afterRemoval, hasLength(1));
    expect(afterRemoval.single.toJson(), updatedExam.toJson());

    await store.save([]);
    expect(await SharedPreferencesCalendarEventStore().load(), isEmpty);
  });

  test(
    'corrupt storage throws and preserves the original saved data',
    () async {
      final invalidValues = <Object>[
        42,
        '{broken',
        '{}',
        '[false]',
        jsonEncode([
          {
            'id': 'bad',
            'title': 'Invalid date',
            'date': '2026-02-30',
            'type': 'exam',
          },
        ]),
      ];
      for (final invalid in invalidValues) {
        SharedPreferences.setMockInitialValues({
          SharedPreferencesCalendarEventStore.storageKey: invalid,
        });
        await expectLater(
          SharedPreferencesCalendarEventStore().load(),
          throwsFormatException,
        );
        final preferences = await SharedPreferences.getInstance();
        expect(
          preferences.get(SharedPreferencesCalendarEventStore.storageKey),
          invalid,
        );
      }
    },
  );
}
