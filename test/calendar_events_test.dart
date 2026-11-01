import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtc_student_hub/models/calendar_event.dart';
import 'package:mtc_student_hub/screens/home_screen.dart';
import 'package:mtc_student_hub/services/calendar_event_store.dart';
import 'package:mtc_student_hub/theme.dart';
import 'package:mtc_student_hub/widgets/calendar_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _today = DateTime(2026, 10, 20);

Future<void> _openHome(
  WidgetTester tester, {
  CalendarEventStore? store,
  Size size = const Size(430, 1100),
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(brightness),
      home: Scaffold(
        body: HomeScreen(key: UniqueKey(), today: _today, eventStore: store),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _revealHome(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scrollable = find
        .descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(finder, 250, scrollable: scrollable);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapHome(WidgetTester tester, Finder finder) async {
  await _revealHome(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

Future<void> _addEvent(
  WidgetTester tester, {
  required String title,
  required CalendarEventType type,
  String notes = '',
}) async {
  await _tapHome(tester, find.byKey(const ValueKey('add-calendar-event')));
  await _tap(tester, find.widgetWithText(ChoiceChip, type.label));
  await _enter(tester, 'event-title', title);
  if (notes.isNotEmpty) await _enter(tester, 'event-notes', notes);
  await _tap(tester, find.byKey(const ValueKey('save-calendar-event')));
}

class _FailingStore implements CalendarEventStore {
  _FailingStore([List<CalendarEvent> initial = const []])
    : events = List.of(initial);

  List<CalendarEvent> events;
  bool failLoad = false;
  bool failSave = false;
  int loadCalls = 0;
  int saveCalls = 0;

  @override
  Future<List<CalendarEvent>> load() async {
    loadCalls++;
    if (failLoad) throw StateError('Load failed');
    return List.of(events);
  }

  @override
  Future<void> save(List<CalendarEvent> updated) async {
    saveCalls++;
    if (failSave) throw StateError('Save failed');
    events = List.of(updated);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('All four type icons fit on a selected date at 320 pixels', (
    tester,
  ) async {
    final store = _FailingStore([
      for (final type in CalendarEventType.values)
        CalendarEvent(
          id: type.name,
          title: type.label,
          date: _today,
          type: type,
        ),
    ]);
    await _openHome(tester, store: store, size: const Size(320, 1100));
    final day = find.byKey(const ValueKey('calendar-2026-10-20'));
    await _revealHome(tester, day);
    for (final type in CalendarEventType.values) {
      final marker = find.byKey(
        ValueKey('event-marker-2026-10-20-${type.name}'),
      );
      expect(find.descendant(of: day, matching: marker), findsOneWidget);
      final icon = tester.widget<Icon>(
        find.descendant(of: marker, matching: find.byType(Icon)),
      );
      expect(icon.icon, calendarEventIcon(type));
      expect(icon.color, calendarEventColor(type));
    }
    expect(tester.takeException(), isNull);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets(
    'Different event types share a date, show markers, and survive reload',
    (tester) async {
      await _openHome(tester);
      await _addEvent(
        tester,
        title: 'Математикийн шалгалт',
        type: CalendarEventType.exam,
        notes: '301 тоот, тооны машин авчрах',
      );
      await _addEvent(
        tester,
        title: 'Бие даалтаа илгээх',
        type: CalendarEventType.assignment,
      );
      await _addEvent(
        tester,
        title: 'Төслийн семинар',
        type: CalendarEventType.seminar,
      );

      final saved = await SharedPreferencesCalendarEventStore().load();
      expect(saved, hasLength(3));
      expect(
        saved.map((event) => event.type),
        containsAll([
          CalendarEventType.exam,
          CalendarEventType.assignment,
          CalendarEventType.seminar,
        ]),
      );
      expect(saved.every((event) => event.date == _today), isTrue);
      expect(
        saved
            .singleWhere((event) => event.type == CalendarEventType.exam)
            .notes,
        '301 тоот, тооны машин авчрах',
      );
      await _revealHome(
        tester,
        find.byKey(const ValueKey('calendar-2026-10-20')),
      );
      for (final type in [
        CalendarEventType.exam,
        CalendarEventType.assignment,
        CalendarEventType.seminar,
      ]) {
        expect(
          find.byKey(ValueKey('event-marker-2026-10-20-${type.name}')),
          findsOneWidget,
        );
      }

      await _tapHome(tester, find.byKey(const ValueKey('calendar-2026-10-21')));
      await _revealHome(tester, find.byKey(const ValueKey('important-dates')));
      expect(find.byKey(const ValueKey('no-calendar-events')), findsOneWidget);
      expect(find.text('Математикийн шалгалт'), findsNothing);
      await _tapHome(tester, find.byKey(const ValueKey('calendar-2026-10-20')));
      await _revealHome(
        tester,
        find.byKey(ValueKey('event-card-${saved.first.id}')),
      );
      expect(find.text('Математикийн шалгалт'), findsOneWidget);

      await _openHome(tester);
      await _revealHome(
        tester,
        find.byKey(ValueKey('event-card-${saved.first.id}')),
      );
      for (final event in saved) {
        expect(find.byKey(ValueKey('event-card-${event.id}')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Edit moves a dated event; deleting requires confirmation', (
    tester,
  ) async {
    final store = SharedPreferencesCalendarEventStore();
    await store.save([
      CalendarEvent(
        id: 'exam-1',
        title: 'Хуучин шалгалт',
        date: _today,
        type: CalendarEventType.exam,
        minutes: 570,
      ),
    ]);
    await _openHome(tester);
    await _tapHome(tester, find.byKey(const ValueKey('edit-event-exam-1')));
    await _enter(tester, 'event-title', 'Шилжсэн шалгалт');
    await _tap(tester, find.byKey(const ValueKey('event-date')));
    final picker = find.byType(DatePickerDialog);
    await _tap(
      tester,
      find.descendant(of: picker, matching: find.byIcon(Icons.edit_outlined)),
    );
    final dateText = MaterialLocalizations.of(
      tester.element(picker),
    ).formatCompactDate(DateTime(2026, 10, 22));
    await tester.enterText(
      find.descendant(of: picker, matching: find.byType(TextFormField)),
      dateText,
    );
    await _tap(
      tester,
      find.descendant(of: picker, matching: find.text('Сонгох')),
    );
    await _tap(tester, find.byTooltip('Цагийг арилгах'));
    await _tap(tester, find.byKey(const ValueKey('save-calendar-event')));
    final moved = (await store.load()).single;
    expect(moved.id, 'exam-1');
    expect(moved.title, 'Шилжсэн шалгалт');
    expect(moved.date, DateTime(2026, 10, 22));
    expect(moved.minutes, isNull);
    await _revealHome(
      tester,
      find.byKey(const ValueKey('calendar-2026-10-22')),
    );
    expect(
      find.byKey(const ValueKey('event-marker-2026-10-20-exam')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('event-marker-2026-10-22-exam')),
      findsOneWidget,
    );

    await _tapHome(tester, find.byKey(const ValueKey('delete-event-exam-1')));
    await _tap(tester, find.widgetWithText(TextButton, 'Болих'));
    expect(await store.load(), hasLength(1));
    await _tapHome(tester, find.byKey(const ValueKey('delete-event-exam-1')));
    await _tap(tester, find.byKey(const ValueKey('confirm-delete-event')));
    expect(await store.load(), isEmpty);
    expect(find.byKey(const ValueKey('event-card-exam-1')), findsNothing);
    await _revealHome(
      tester,
      find.byKey(const ValueKey('calendar-2026-10-22')),
    );
    expect(
      find.byKey(const ValueKey('event-marker-2026-10-22-exam')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed save keeps the editor draft and supports retry', (
    tester,
  ) async {
    final store = _FailingStore()..failSave = true;
    await _openHome(tester, store: store);
    await _addEvent(
      tester,
      title: 'Утгаа алдахгүй бие даалт',
      type: CalendarEventType.assignment,
      notes: 'PDF хэлбэрээр илгээх',
    );
    expect(store.events, isEmpty);
    expect(store.saveCalls, 1);
    expect(find.text('Хадгалж чадсангүй. Дахин оролдоно уу.'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('event-title')))
          .controller!
          .text,
      'Утгаа алдахгүй бие даалт',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('event-notes')))
          .controller!
          .text,
      'PDF хэлбэрээр илгээх',
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Бие даалт'))
          .selected,
      isTrue,
    );
    store.failSave = false;
    await _tap(tester, find.byKey(const ValueKey('save-calendar-event')));
    expect(store.events, hasLength(1));
    expect(store.saveCalls, 2);
    expect(find.byKey(const ValueKey('event-title')), findsNothing);
    await _revealHome(
      tester,
      find.byKey(ValueKey('event-card-${store.events.single.id}')),
    );
    expect(find.text('Утгаа алдахгүй бие даалт'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Load failure protects saved events and provides retry', (
    tester,
  ) async {
    final store = _FailingStore([
      CalendarEvent(
        id: 'retained',
        title: 'Хадгалсан семинар',
        date: _today,
        type: CalendarEventType.seminar,
      ),
    ])..failLoad = true;
    await _openHome(tester, store: store);
    await _revealHome(
      tester,
      find.byKey(const ValueKey('retry-calendar-events')),
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('add-calendar-event')))
          .onPressed,
      isNull,
    );
    expect(store.events, hasLength(1));
    expect(store.saveCalls, 0);
    store.failLoad = false;
    await _tapHome(tester, find.byKey(const ValueKey('retry-calendar-events')));
    expect(store.loadCalls, 2);
    expect(find.byKey(const ValueKey('event-card-retained')), findsOneWidget);
    expect(find.text('Хадгалсан семинар'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('add-calendar-event')))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'An empty title is rejected and cancelling does not create an event',
    (tester) async {
      await _openHome(tester);
      await _tapHome(tester, find.byKey(const ValueKey('add-calendar-event')));
      await _enter(tester, 'event-title', '   ');
      await _tap(tester, find.byKey(const ValueKey('save-calendar-event')));
      expect(find.text('Гарчиг оруулна уу.'), findsOneWidget);
      expect(await SharedPreferencesCalendarEventStore().load(), isEmpty);
      await _enter(tester, 'event-title', 'Хадгалахгүй тэмдэглэл');
      await _tap(tester, find.byTooltip('Хаах'));
      expect(await SharedPreferencesCalendarEventStore().load(), isEmpty);
      expect(find.text('Хадгалахгүй тэмдэглэл'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'The dark editor works at 320 pixels and saves an optional time',
    (tester) async {
      await _openHome(
        tester,
        size: const Size(320, 740),
        brightness: Brightness.dark,
      );
      await _tapHome(tester, find.byKey(const ValueKey('add-calendar-event')));
      await _tap(tester, find.widgetWithText(ChoiceChip, 'Семинар'));
      await _enter(tester, 'event-title', 'Өглөөний семинар');
      await _tap(tester, find.byKey(const ValueKey('event-time')));
      await _tap(
        tester,
        find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.text('Сонгох'),
        ),
      );
      await _enter(
        tester,
        'event-notes',
        'Танилцуулга болон зөөврийн компьютер',
      );
      await _tap(tester, find.byKey(const ValueKey('save-calendar-event')));
      final saved = (await SharedPreferencesCalendarEventStore().load()).single;
      expect(saved.type, CalendarEventType.seminar);
      expect(saved.minutes, 540);
      await _revealHome(tester, find.byKey(ValueKey('event-card-${saved.id}')));
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('Өглөөний семинар'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
