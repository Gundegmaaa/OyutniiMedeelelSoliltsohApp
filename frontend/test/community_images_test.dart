import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mtc_student_hub/models/post.dart';
import 'package:mtc_student_hub/screens/community_screen.dart';
import 'package:mtc_student_hub/theme.dart';

void main() {
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  Future<GlobalKey<CommunityScreenState>> openComposer(
    WidgetTester tester,
    Future<XFile?> Function() picker,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey<CommunityScreenState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: Scaffold(
          body: CommunityScreen(key: key, pickPostImage: picker),
        ),
      ),
    );
    await tester.tap(find.text('Хуваалцах'));
    await tester.pumpAndSettle();
    return key;
  }

  Future<void> pickImage(WidgetTester tester) async {
    final picker = find.byKey(const ValueKey('pick-post-image'));
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    // Image decoding uses the engine's real asynchronous codec queue.
    await tester.runAsync(() async {
      await tester.tap(picker);
      for (var attempt = 0; attempt < 100; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (tester.widget<OutlinedButton>(picker).onPressed != null) return;
      }
      fail('The gallery selection did not finish.');
    });
    await tester.pumpAndSettle();
  }

  Future<void> fillPost(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'Миний ном');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Цэвэрхэн ном зарна.',
    );
    await tester.enterText(find.byType(TextFormField).at(2), '15000');
  }

  Future<void> publish(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Нийтлэх'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Нийтлэх'));
    await tester.pumpAndSettle();
  }

  for (final category in [
    PostCategory.exchange,
    PostCategory.rental,
    PostCategory.question,
  ]) {
    testWidgets(
      '${category.name} publishes with the selected avatar and filters correctly',
      (tester) async {
        final stateKey = await openComposer(tester, () async => null);
        await tester.tap(find.byType(DropdownButtonFormField<PostCategory>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(category.label).last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(0), 'Шинэ зар');
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Дэлгэрэнгүй тайлбар',
        );
        if (category == PostCategory.rental) {
          await tester.enterText(find.byType(TextFormField).at(2), '50000');
        }
        final avatar = find.byKey(const ValueKey('avatar-home'));
        await tester.ensureVisible(avatar);
        await tester.tap(avatar);
        await publish(tester);
        final post = stateKey.currentState!.posts.first;
        expect(post.category, category);
        expect(post.avatar, PostAvatar.home);
        expect(post.imageBytes, isNull);
        expect(post.price, category == PostCategory.rental ? '50000₮' : isNull);
        final filter = find.widgetWithText(ChoiceChip, category.label);
        await tester.ensureVisible(filter);
        await tester.tap(filter);
        await tester.pumpAndSettle();
        expect(find.text('Шинэ зар'), findsOneWidget);
        expect(find.text('📚 Ном зарна'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Gallery photo previews, publishes, and opens a zoomable viewer',
    (tester) async {
      final stateKey = await openComposer(
        tester,
        () async => XFile.fromData(
          png,
          name: 'book.png',
          path: 'book.png',
          mimeType: 'image/png',
        ),
      );
      await fillPost(tester);
      await pickImage(tester);
      expect(find.byKey(const ValueKey('post-image-preview')), findsOneWidget);
      await publish(tester);
      expect(stateKey.currentState!.posts.first.imageBytes, orderedEquals(png));
      expect(stateKey.currentState!.posts.first.imageName, 'book.png');
      expect(stateKey.currentState!.posts.first.price, '15000₮');
      final photo = find.byKey(const ValueKey('post-image'));
      expect(photo, findsOneWidget);
      await tester.ensureVisible(photo);
      await tester.pumpAndSettle();
      await tester.tap(photo);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('post-image-viewer')), findsOneWidget);
      await tester.tap(find.byTooltip('Зургийг хаах'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('post-image-viewer')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cancelling replacement keeps the photo and fields; removing publishes text only',
    (tester) async {
      var calls = 0;
      final stateKey = await openComposer(tester, () async {
        calls++;
        return calls == 1 ? XFile.fromData(png, name: 'book.png') : null;
      });
      await fillPost(tester);
      await pickImage(tester);
      await pickImage(tester);
      expect(find.byKey(const ValueKey('post-image-preview')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(0))
            .controller!
            .text,
        'Миний ном',
      );
      final remove = find.byKey(const ValueKey('remove-post-image'));
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('post-image-preview')), findsNothing);
      await publish(tester);
      expect(stateKey.currentState!.posts.first.title, 'Миний ном');
      expect(stateKey.currentState!.posts.first.imageBytes, isNull);
      expect(stateKey.currentState!.posts.first.imageName, isNull);
    },
  );

  testWidgets('Invalid files are rejected while the draft is preserved', (
    tester,
  ) async {
    await openComposer(
      tester,
      () async => XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'not-a-photo.txt',
      ),
    );
    await fillPost(tester);
    await pickImage(tester);
    expect(
      find.text('Зургийг уншиж чадсангүй. JPG, PNG зэрэг зураг сонгоно уу.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('post-image-preview')), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(0))
          .controller!
          .text,
      'Миний ном',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Oversized images are rejected before preview', (tester) async {
    await openComposer(
      tester,
      () async =>
          XFile.fromData(Uint8List(8 * 1024 * 1024 + 1), name: 'large.png'),
    );
    await pickImage(tester);
    expect(
      find.text('8 MB-аас бага хэмжээтэй зураг сонгоно уу.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('post-image-preview')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Gallery permission errors show a friendly message and allow retry',
    (tester) async {
      await openComposer(
        tester,
        () async => throw PlatformException(code: 'photo_access_denied'),
      );
      await pickImage(tester);
      expect(
        find.textContaining('Зурагт хандах зөвшөөрөл хэрэгтэй.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('pick-post-image')),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Finishing a picker after dismissing the composer is safe', (
    tester,
  ) async {
    final pending = Completer<XFile?>();
    await openComposer(tester, () => pending.future);
    final picker = find.byKey(const ValueKey('pick-post-image'));
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pump();
    expect(tester.widget<OutlinedButton>(picker).onPressed, isNull);
    Navigator.of(tester.element(find.text('Шинэ нийтлэл'))).pop();
    await tester.pumpAndSettle();
    pending.complete(XFile.fromData(png, name: 'book.png'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
