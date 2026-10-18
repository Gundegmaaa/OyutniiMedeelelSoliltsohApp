import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtc_student_hub/main.dart';
import 'package:mtc_student_hub/models/learning.dart';

void main() {
  Future<void> openApp(
    WidgetTester tester, {
    Size size = const Size(430, 932),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const StudentHubApp());
    await tester.pumpAndSettle();
  }

  testWidgets('Three pages and profile open through bottom navigation', (
    tester,
  ) async {
    await openApp(tester);
    expect(find.text('Сайн байна уу, Гүндэгмаа 👋'), findsOneWidget);
    await tester.tap(find.text('Community').last);
    await tester.pumpAndSettle();
    expect(find.text('Оюутнуудын орчин'), findsOneWidget);
    await tester.tap(find.text('Сургалт').last);
    await tester.pumpAndSettle();
    expect(find.text('Суралцах'), findsOneWidget);
    await tester.tap(find.text('Профайл'));
    await tester.pumpAndSettle();
    expect(find.text('Гүндэгмаа'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Community filters and publishes a new question', (tester) async {
    await openApp(tester);
    await tester.tap(find.text('Community').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Асуулт').first);
    await tester.pumpAndSettle();
    expect(find.text('💬 OOP хичээлийн зөвлөгөө хэрэгтэй'), findsOneWidget);
    expect(find.text('📚 Ном зарна'), findsNothing);
    await tester.tap(find.byTooltip('Нийтлэл нэмэх'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate((widget) => widget is DropdownButtonFormField),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Асуулт').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Flutter зөвлөгөө',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'StatefulWidget хэрхэн ашиглах вэ?',
    );
    await tester.tap(find.text('Нийтлэх'));
    await tester.pumpAndSettle();
    expect(find.text('Flutter зөвлөгөө'), findsOneWidget);
    await tester.tap(find.text('Нүүр'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Community').last);
    await tester.pumpAndSettle();
    expect(find.text('Flutter зөвлөгөө'), findsOneWidget);
  });

  testWidgets('Likes can be toggled and comments can be sent', (tester) async {
    await openApp(tester);
    await tester.tap(find.text('Community').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Таалагдлаа').first);
    await tester.pumpAndSettle();
    expect(find.text('9'), findsOneWidget);
    await tester.tap(find.byTooltip('Таалагдсаныг болих').first);
    await tester.pumpAndSettle();
    expect(find.text('8'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '4').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ном байгаа юу?');
    await tester.tap(find.byTooltip('Илгээх'));
    await tester.pumpAndSettle();
    expect(find.text('Гүндэгмаа: Ном байгаа юу?'), findsOneWidget);
  });

  testWidgets('Quiz completes and adds earned XP', (tester) async {
    await openApp(tester);
    await tester.tap(find.text('Сургалт').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ЭХЛҮҮЛЭХ'));
    await tester.pumpAndSettle();
    for (final answer in [
      'Өгөгдөл ба үйлдлийг нэгтгэж, дотоод төлөвт хандахыг хязгаарлана',
      'Өгөгдөл унших',
      'HTML',
    ]) {
      await tester.tap(find.text(answer));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Шалгах'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Дараах'));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('3 асуултаас 3 зөв'), findsOneWidget);
    await tester.tap(find.text('Дуусгах'));
    await tester.pumpAndSettle();
    expect(find.text('880 XP'), findsOneWidget);
  });

  testWidgets('Problem rejects wrong answer and accepts correct answer', (
    tester,
  ) async {
    await openApp(tester);
    await tester.tap(find.text('Сургалт').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Эхлэх').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '54');
    await tester.tap(find.text('Шалгах'));
    await tester.pumpAndSettle();
    expect(find.text('Хариу буруу байна. Дахин оролдоорой.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '55');
    await tester.tap(find.text('Шалгах'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дуусгах'));
    await tester.pumpAndSettle();
    expect(find.text('840 XP'), findsOneWidget);
  });

  testWidgets('Small screen and dark mode render without overflow', (
    tester,
  ) async {
    await openApp(tester, size: const Size(320, 640));
    await tester.tap(find.byTooltip('Харанхуй горим'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
    for (final label in ['Community', 'Сургалт', 'Нүүр']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  test('Activity rewards are granted only once and ranks follow XP', () {
    final progress = LearningProgress();
    expect(progress.award('quiz-0', 60), 60);
    expect(progress.award('quiz-0', 60), 0);
    expect(progress.xp, 880);
    expect(progress.rank, 12);
    progress.award('other', 500);
    expect(progress.rank, 1);
  });
}
