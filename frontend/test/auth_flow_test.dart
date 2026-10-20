import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mtc_student_hub/auth/auth_api.dart';
import 'package:mtc_student_hub/main.dart';

const user = {
  'id': 'student-1',
  'email': 'bold@example.com',
  'display_name': 'Болд',
  'first_name': 'Болд',
  'last_name': 'Бат',
  'student_code': 'IS24001',
  'course': 2,
  'role': 'student',
  'email_verified': true,
};

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  Future<void> start(
    WidgetTester tester,
    MockClient client, {
    Size size = const Size(430, 932),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = AuthApi(client: client);
    addTearDown(api.close);
    await tester.pumpWidget(StudentHubApp(authApi: api));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String value) async {
    final field = find.byKey(ValueKey(key));
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Password login passes remember choice and logout returns to auth screen',
    (tester) async {
      Map<String, dynamic>? credentials;
      var loggedOut = false;
      await start(
        tester,
        MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/csrf/')) {
            return jsonResponse({'csrf_token': 'token'});
          }
          if (path.endsWith('/login/')) {
            credentials = jsonDecode(request.body) as Map<String, dynamic>;
            return jsonResponse({'user': user, 'csrf_token': 'rotated'});
          }
          if (path.endsWith('/logout/')) {
            loggedOut = true;
            expect(request.headers['X-CSRFToken'], 'rotated');
            return jsonResponse({'detail': 'Системээс гарлаа.'});
          }
          return jsonResponse({
            'error': {'code': 'not_authenticated', 'message': 'Нэвтэрнэ үү.'},
          }, 401);
        }),
      );
      await enter(tester, 'auth_email', 'bold@example.com');
      await enter(tester, 'auth_password', 'Campus!River936');
      await tap(tester, 'auth_remember');
      await tap(tester, 'auth_submit');
      expect(credentials?['remember_me'], true);
      expect(find.text('Сайн байна уу, Болд 👋'), findsOneWidget);
      await tester.tap(find.text('Профайл'));
      await tester.pumpAndSettle();
      expect(find.text('bold@example.com'), findsOneWidget);
      expect(find.text('Оюутны код: IS24001'), findsOneWidget);
      expect(find.text('2-р курс'), findsOneWidget);
      await tap(tester, 'profile_logout');
      expect(loggedOut, true);
      expect(find.byKey(const ValueKey('auth_email')), findsOneWidget);
      expect(find.text('Сайн байна уу, Болд 👋'), findsNothing);
    },
  );

  testWidgets(
    'Registration verifies the mailed code with chosen password before login',
    (tester) async {
      Map<String, dynamic>? registration;
      Map<String, dynamic>? verification;
      await start(
        tester,
        MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/csrf/')) {
            return jsonResponse({'csrf_token': 'token'});
          }
          if (path.endsWith('/register/')) {
            registration = jsonDecode(request.body) as Map<String, dynamic>;
            return jsonResponse({'detail': 'Код илгээгдлээ.'}, 202);
          }
          if (path.endsWith('/verify-email/')) {
            verification = jsonDecode(request.body) as Map<String, dynamic>;
            return jsonResponse({'detail': 'Мэйл баталгаажлаа.'});
          }
          return jsonResponse({
            'error': {'code': 'not_authenticated', 'message': 'Нэвтэрнэ үү.'},
          }, 401);
        }),
      );
      await tap(tester, 'auth_to_register');
      await enter(tester, 'auth_student_code', 'IS24001');
      await enter(tester, 'auth_first_name', 'Болд');
      await enter(tester, 'auth_last_name', 'Бат');
      await tap(tester, 'auth_course');
      await tester.tap(find.text('2-р курс').last);
      await tester.pumpAndSettle();
      await enter(tester, 'auth_email', 'bold@example.com');
      await enter(tester, 'auth_password', 'Campus!River936');
      await enter(tester, 'auth_password_confirm', 'Campus!River936');
      await tap(tester, 'auth_submit');
      expect(registration?['student_code'], 'IS24001');
      expect(registration?['first_name'], 'Болд');
      expect(registration?['last_name'], 'Бат');
      expect(registration?['course'], 2);
      expect(registration?.containsKey('display_name'), isFalse);
      expect(registration?['password_confirm'], 'Campus!River936');
      expect(find.byKey(const ValueKey('auth_code')), findsOneWidget);
      expect(find.byKey(const ValueKey('auth_email')), findsNothing);
      expect(
        find.byKey(const ValueKey('auth_verification_email')),
        findsOneWidget,
      );
      await enter(tester, 'auth_code', '012345');
      await tap(tester, 'auth_submit');
      expect(verification?['code'], '012345');
      expect(verification?['password'], 'Campus!River936');
      expect(verification?['email'], 'bold@example.com');
      expect(find.byKey(const ValueKey('auth_code')), findsNothing);
      final password = tester.widget<TextFormField>(
        find.byKey(const ValueKey('auth_password')),
      );
      expect(password.controller?.text, isEmpty);
    },
  );

  testWidgets(
    'Unverified login resumes a fixed recipient and resend cannot edit it',
    (tester) async {
      Map<String, dynamic>? resend;
      await start(
        tester,
        MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/csrf/')) {
            return jsonResponse({'csrf_token': 'token'});
          }
          if (path.endsWith('/login/')) {
            return jsonResponse({
              'error': {
                'code': 'email_not_verified',
                'message': 'Эхлээд баталгаажуулна уу.',
              },
            }, 403);
          }
          if (path.endsWith('/resend-verification/')) {
            resend = jsonDecode(request.body) as Map<String, dynamic>;
            return jsonResponse({'detail': 'Код илгээгдлээ.'}, 202);
          }
          return jsonResponse({
            'error': {'code': 'not_authenticated', 'message': 'Нэвтэрнэ үү.'},
          }, 401);
        }),
      );
      await enter(tester, 'auth_email', 'BOLD@example.com');
      await enter(tester, 'auth_password', 'Campus!River936');
      await tap(tester, 'auth_submit');
      expect(find.byKey(const ValueKey('auth_email')), findsNothing);
      final recipient = tester.widget<Text>(
        find.byKey(const ValueKey('auth_verification_email')),
      );
      expect(recipient.data, 'bold@example.com');
      await tap(tester, 'auth_resend');
      expect(resend, {'email': 'bold@example.com'});
      expect(find.byKey(const ValueKey('auth_email')), findsNothing);
    },
  );

  testWidgets(
    'Expired verification context returns to login and clears the password',
    (tester) async {
      await start(
        tester,
        MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/csrf/')) {
            return jsonResponse({'csrf_token': 'token'});
          }
          if (path.endsWith('/login/')) {
            return jsonResponse({
              'error': {
                'code': 'email_not_verified',
                'message': 'Эхлээд баталгаажуулна уу.',
              },
            }, 403);
          }
          if (path.endsWith('/verify-email/')) {
            return jsonResponse({
              'error': {
                'code': 'verification_required',
                'message': 'Дахин эхлүүлнэ үү.',
              },
            }, 400);
          }
          return jsonResponse({
            'error': {'code': 'not_authenticated', 'message': 'Нэвтэрнэ үү.'},
          }, 401);
        }),
      );
      await enter(tester, 'auth_email', 'bold@example.com');
      await enter(tester, 'auth_password', 'Campus!River936');
      await tap(tester, 'auth_submit');
      await enter(tester, 'auth_code', '012345');
      await tap(tester, 'auth_submit');
      expect(find.byKey(const ValueKey('auth_code')), findsNothing);
      expect(find.byKey(const ValueKey('auth_email')), findsOneWidget);
      final password = tester.widget<TextFormField>(
        find.byKey(const ValueKey('auth_password')),
      );
      expect(password.controller?.text, isEmpty);
      expect(
        find.textContaining('баталгаажуулалтаа үргэлжлүүлнэ үү.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Course must be chosen before submitting a student registration',
    (tester) async {
      var registrationSent = false;
      await start(
        tester,
        MockClient((request) async {
          if (request.url.path.endsWith('/register/')) {
            registrationSent = true;
          }
          return jsonResponse({
            'error': {'code': 'not_authenticated', 'message': 'Нэвтэрнэ үү.'},
          }, 401);
        }),
      );
      await tap(tester, 'auth_to_register');
      await enter(tester, 'auth_student_code', 'IS24001');
      await enter(tester, 'auth_first_name', 'Болд');
      await enter(tester, 'auth_last_name', 'Бат');
      await enter(tester, 'auth_email', 'bold@example.com');
      await enter(tester, 'auth_password', 'Campus!River936');
      await enter(tester, 'auth_password_confirm', 'Campus!River936');
      await tap(tester, 'auth_submit');
      expect(registrationSent, false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Restored session opens the hub with the server user', (
    tester,
  ) async {
    await start(
      tester,
      MockClient((request) async => jsonResponse({'user': user})),
    );
    expect(find.text('Сайн байна уу, Болд 👋'), findsOneWidget);
    expect(find.byKey(const ValueKey('auth_email')), findsNothing);
  });

  testWidgets('Login server errors remain visible without opening the hub', (
    tester,
  ) async {
    await start(
      tester,
      MockClient((request) async {
        if (request.url.path.endsWith('/csrf/')) {
          return jsonResponse({'csrf_token': 'token'});
        }
        return jsonResponse({
          'error': {
            'code': 'invalid_credentials',
            'message': 'Мэйл эсвэл нууц үг буруу байна.',
          },
        }, 401);
      }),
    );
    await enter(tester, 'auth_email', 'bold@example.com');
    await enter(tester, 'auth_password', 'Campus!River936');
    await tap(tester, 'auth_submit');
    expect(find.textContaining('нууц үг буруу байна.'), findsOneWidget);
    expect(find.text('Сайн байна уу, Болд 👋'), findsNothing);
  });

  testWidgets('Auth forms fit a narrow screen and support dark mode', (
    tester,
  ) async {
    await start(
      tester,
      MockClient(
        (request) async => jsonResponse({
          'error': {'code': 'not_authenticated', 'message': 'Нэвтэрнэ үү.'},
        }, 401),
      ),
      size: const Size(320, 640),
    );
    await tester.tap(find.byTooltip('Харанхуй горим'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
    expect(find.byKey(const ValueKey('auth_to_verify')), findsNothing);
    for (final key in ['auth_to_register', 'auth_to_login']) {
      await tap(tester, key);
      expect(tester.takeException(), isNull);
    }
  });
}
