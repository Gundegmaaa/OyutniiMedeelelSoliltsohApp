import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtc_student_hub/screens/home_screen.dart';
import 'package:mtc_student_hub/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Calendar changes month and shows the selected weekday lessons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: Scaffold(body: HomeScreen(today: DateTime(2026, 10, 20))),
      ),
    );
    await tester.pumpAndSettle();

    // October 20 is a Tuesday, so the initial lesson must be mathematics.
    expect(find.text('2026 он\n10 сар'), findsOneWidget);
    expect(find.text('Математик'), findsOneWidget);
    expect(find.text('Өнөөдрийн хичээл'), findsOneWidget);

    await tester.tap(find.byTooltip('Өмнөх сар'));
    await tester.pumpAndSettle();
    expect(find.text('2026 он\n9 сар'), findsOneWidget);
    await tester.tap(find.byTooltip('Дараах сар'));
    await tester.pumpAndSettle();
    expect(find.text('2026 он\n10 сар'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-2026-10-24')));
    await tester.pumpAndSettle();
    expect(find.text('10 сарын 24 • Бямба'), findsOneWidget);
    expect(find.text('Амралтын өдөр 🌿'), findsOneWidget);
    expect(find.text('Математик'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('calendar-2026-10-26')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Software Engineering'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('10 сарын 26 • Даваа'), findsOneWidget);
    expect(find.text('Database'), findsOneWidget);
    expect(find.text('Software Engineering'), findsOneWidget);
    expect(find.text('Өнөөдрийн хичээл'), findsNothing);

    await tester.tap(find.text('Өнөөдөр'));
    await tester.pumpAndSettle();
    expect(find.text('10 сарын 20 • Мягмар'), findsOneWidget);
    expect(find.text('Математик'), findsOneWidget);
    expect(find.text('Өнөөдрийн хичээл'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
