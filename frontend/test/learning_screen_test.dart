import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtc_student_hub/models/learning.dart';
import 'package:mtc_student_hub/screens/learning_screen.dart';
import 'package:mtc_student_hub/theme.dart';

void main() {
  Future<LearningProgress> pumpLearning(
    WidgetTester tester, {
    Size size = const Size(375, 667),
    Brightness brightness = Brightness.light,
    LearningProgress? progress,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = progress ?? LearningProgress();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(brightness),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => LearningScreen(
              progress: state,
              onProgress: () => setState(() {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('Tapping outside the problem dialog does not close it', (
    tester,
  ) async {
    await pumpLearning(tester);
    await tester.ensureVisible(find.text('Эхлэх').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Эхлэх').first);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Заавар'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);

    await tester.tap(find.text('Гарах'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('Problem prompt and answer field fit on 375x667 with guide', (
    tester,
  ) async {
    await pumpLearning(tester, brightness: Brightness.dark);
    await tester.ensureVisible(find.text('Эхлэх').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Эхлэх').first);
    await tester.pumpAndSettle();
    // The guide must not push the answer field below the action row.
    final field = tester.getRect(find.byType(TextField));
    final actions = tester.getRect(find.text('Шалгах'));
    expect(field.bottom, lessThan(actions.top));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Заавар'));
    await tester.pumpAndSettle();
    expect(find.textContaining('торгуульгүй'), findsNothing);
  });

  testWidgets('Leader sheet lists the activities each person solved', (
    tester,
  ) async {
    await pumpLearning(tester, size: const Size(375, 1800));
    expect(
      find.text('Нэр дээр дарж бодсон бодлогуудыг харна уу.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('leader-1')));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('Бат-Эрдэнэ')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('1250 XP')),
      findsOneWidget,
    );
    Finder activityIcon(String id, IconData icon) => find.descendant(
      of: find.byKey(ValueKey('activity-$id')),
      matching: find.byIcon(icon),
    );
    final leader = demoLeaders.firstWhere((s) => s.rank == 1);
    for (final id in [
      'quiz-0',
      'problem-0-0',
      'problem-0-1',
      'problem-0-2',
      'quiz-1',
      'problem-1-0',
      'problem-1-1',
      'problem-1-2',
    ]) {
      expect(
        activityIcon(
          id,
          leader.completed.contains(id)
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
        ),
        findsOneWidget,
        reason: id,
      );
    }
    expect(
      find.descendant(
        of: sheet,
        matching: find.text(softwareProblems[2].prompt),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Own row shows empty state, then real solved problems', (
    tester,
  ) async {
    final progress = LearningProgress();
    await pumpLearning(tester, size: const Size(375, 1800), progress: progress);
    await tester.tap(find.byKey(const ValueKey('leader-me')));
    await tester.pumpAndSettle();
    expect(find.text('Одоогоор бодсон бодлого алга.'), findsOneWidget);
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();

    progress.award('problem-1-2', 60);
    await tester.tap(find.byKey(const ValueKey('leader-me')));
    await tester.pumpAndSettle();
    expect(find.text('Одоогоор бодсон бодлого алга.'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('activity-problem-1-2')),
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('activity-problem-0-0')),
        matching: find.byIcon(Icons.radio_button_unchecked_rounded),
      ),
      findsOneWidget,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('Hero keeps its height across programs (${brightness.name})', (
      tester,
    ) async {
      await pumpLearning(
        tester,
        size: const Size(375, 812),
        brightness: brightness,
      );
      final hero = find.byKey(const ValueKey('quiz-hero'));
      final softwareSize = tester.getSize(hero);
      final problemsTop = tester.getTopLeft(find.text('Бодлогоо сонгоорой')).dy;

      await tester.tap(find.text('Information System'));
      await tester.pumpAndSettle();
      expect(tester.getSize(hero), softwareSize);
      expect(
        tester.getTopLeft(find.text('Бодлогоо сонгоорой')).dy,
        problemsTop,
      );
      expect(find.text('Системийн шинжилгээ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
