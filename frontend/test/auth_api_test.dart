import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mtc_student_hub/auth/auth_api.dart';

const _user = {
  'id': 'a3ee7572-90b6-411f-a67b-890c1991c127',
  'email': 'student@example.com',
  'display_name': 'Болд',
  'first_name': 'Болд',
  'last_name': 'Бат',
  'student_code': 'IS24001',
  'course': 2,
  'role': 'student',
  'email_verified': true,
};

http.Response _json(
  Object data, [
  int status = 200,
  Map<String, String>? headers,
]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
);

http.Response _error(String code, int status, {String message = 'Алдаа'}) =>
    _json({
      'error': {'code': code, 'message': message},
    }, status);

void main() {
  test(
    'registration bootstraps CSRF and sends only the registration fields',
    () async {
      final requests = <http.Request>[];
      final api = AuthApi(
        baseUrl: 'http://localhost:8000/',
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/csrf/')) {
            expect(request.method, 'GET');
            return _json({'csrf_token': 'initial-csrf'});
          }
          return _json({'detail': 'Код илгээгдлээ'}, 202);
        }),
      );
      addTearDown(api.close);

      await api.register(
        email: ' student@example.com ',
        studentCode: ' is24001 ',
        firstName: ' Болд ',
        lastName: ' Бат ',
        course: 2,
        password: ' River!Secret936 ',
        passwordConfirm: ' River!Secret936 ',
      );

      expect(requests.map((r) => r.url.path), [
        '/api/v1/auth/csrf/',
        '/api/v1/auth/register/',
      ]);
      expect(requests.last.method, 'POST');
      expect(requests.last.followRedirects, isFalse);
      expect(requests.last.headers['X-CSRFToken'], 'initial-csrf');
      expect(jsonDecode(requests.last.body), {
        'email': 'student@example.com',
        'student_code': 'IS24001',
        'first_name': 'Болд',
        'last_name': 'Бат',
        'course': 2,
        'password': ' River!Secret936 ',
        'password_confirm': ' River!Secret936 ',
      });
    },
  );

  test(
    'verification preserves leading zero and supplies the chosen password',
    () async {
      final api = AuthApi(
        client: MockClient((request) async {
          if (request.method == 'GET') return _json({'csrf_token': 'csrf'});
          expect(request.url.path, '/api/v1/auth/verify-email/');
          expect(jsonDecode(request.body), {
            'email': 'student@example.com',
            'code': '012345',
            'password': 'Mailbox!Owner936',
          });
          return _json({'detail': 'Баталгаажлаа'});
        }),
      );
      addTearDown(api.close);

      await api.verifyEmail(
        email: 'student@example.com',
        code: '012345',
        password: 'Mailbox!Owner936',
      );
    },
  );

  for (final rememberMe in [true, false]) {
    test(
      'login sends remember_me=$rememberMe and parses the authenticated user',
      () async {
        final api = AuthApi(
          client: MockClient((request) async {
            if (request.method == 'GET') return _json({'csrf_token': 'csrf'});
            expect(request.url.path, '/api/v1/auth/login/');
            expect(jsonDecode(request.body), {
              'email': 'student@example.com',
              'password': 'River!Secret936',
              'remember_me': rememberMe,
            });
            return _json({'user': _user, 'csrf_token': 'rotated'});
          }),
        );
        addTearDown(api.close);

        final user = await api.login(
          email: 'student@example.com',
          password: 'River!Secret936',
          rememberMe: rememberMe,
        );
        expect(user.id, _user['id']);
        expect(user.email, 'student@example.com');
        expect(user.displayName, 'Болд');
        expect(user.role, 'student');
        expect(user.emailVerified, isTrue);
        expect(user.firstName, 'Болд');
        expect(user.lastName, 'Бат');
        expect(user.studentCode, 'IS24001');
        expect(user.course, 2);
      },
    );
  }

  test(
    'logout uses the token rotated by login and clears it for the next call',
    () async {
      var csrfRequests = 0;
      final api = AuthApi(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/csrf/')) {
            csrfRequests++;
            return _json({'csrf_token': 'csrf-$csrfRequests'});
          }
          if (request.url.path.endsWith('/login/')) {
            return _json({'user': _user, 'csrf_token': 'rotated-csrf'});
          }
          if (request.url.path.endsWith('/logout/')) {
            expect(request.headers['X-CSRFToken'], 'rotated-csrf');
            expect(jsonDecode(request.body), isEmpty);
            return _json({'detail': 'Гарлаа'});
          }
          expect(request.headers['X-CSRFToken'], 'csrf-2');
          return _json({'detail': 'Илгээгдлээ'}, 202);
        }),
      );
      addTearDown(api.close);

      await api.login(
        email: 'student@example.com',
        password: 'secret',
        rememberMe: true,
      );
      await api.logout();
      await api.resendVerification(email: 'student@example.com');
      expect(csrfRequests, 2);
    },
  );

  test(
    'a CSRF rejection refreshes once and retries with unchanged body',
    () async {
      var csrfRequests = 0;
      final posts = <http.Request>[];
      final api = AuthApi(
        client: MockClient((request) async {
          if (request.method == 'GET') {
            csrfRequests++;
            return _json({'csrf_token': 'csrf-$csrfRequests'});
          }
          posts.add(request);
          if (posts.length == 1) return _error('csrf_failed', 403);
          return _json({'detail': 'Илгээгдлээ'}, 202);
        }),
      );
      addTearDown(api.close);

      await api.resendVerification(email: 'student@example.com');
      expect(csrfRequests, 2);
      expect(posts.length, 2);
      expect(posts.first.headers['X-CSRFToken'], 'csrf-1');
      expect(posts.last.headers['X-CSRFToken'], 'csrf-2');
      expect(posts.first.body, posts.last.body);
    },
  );

  test('repeated CSRF failures stop after a single retry', () async {
    var posts = 0;
    var csrfRequests = 0;
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          csrfRequests++;
          return _json({'csrf_token': 'csrf-$csrfRequests'});
        }
        posts++;
        return _error('csrf_failed', 403);
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.resendVerification(email: 'student@example.com'),
      throwsA(
        isA<AuthApiException>().having((e) => e.code, 'code', 'csrf_failed'),
      ),
    );
    expect(posts, 2);
    expect(csrfRequests, 2);
  });

  test(
    'an unverified login is surfaced without retrying or refreshing CSRF',
    () async {
      final paths = <String>[];
      final api = AuthApi(
        client: MockClient((request) async {
          paths.add(request.url.path);
          if (request.method == 'GET') return _json({'csrf_token': 'csrf'});
          return _error('email_not_verified', 403);
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.login(
          email: 'student@example.com',
          password: 'secret',
          rememberMe: false,
        ),
        throwsA(
          isA<AuthApiException>().having(
            (e) => e.code,
            'code',
            'email_not_verified',
          ),
        ),
      );
      expect(paths, ['/api/v1/auth/csrf/', '/api/v1/auth/login/']);
    },
  );

  test(
    'page refresh loads the current user without bootstrapping CSRF',
    () async {
      var requests = 0;
      final api = AuthApi(
        client: MockClient((request) async {
          requests++;
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/auth/me/');
          return _json({'user': _user});
        }),
      );
      addTearDown(api.close);

      expect((await api.currentUser())?.displayName, 'Болд');
      expect(requests, 1);
    },
  );

  test('only HTTP 401 from currentUser means an anonymous session', () async {
    for (final status in [401, 403, 503]) {
      final api = AuthApi(
        client: MockClient((_) async => _error('request_failed', status)),
      );
      addTearDown(api.close);
      if (status == 401) {
        expect(await api.currentUser(), isNull);
      } else {
        await expectLater(
          api.currentUser(),
          throwsA(
            isA<AuthApiException>().having(
              (e) => e.statusCode,
              'status',
              status,
            ),
          ),
        );
      }
    }
  });

  test(
    'SMTP failure is propagated once without automatic registration retry',
    () async {
      var posts = 0;
      final api = AuthApi(
        client: MockClient((request) async {
          if (request.method == 'GET') return _json({'csrf_token': 'csrf'});
          posts++;
          return _error(
            'email_delivery_failed',
            503,
            message: 'Мэйл илгээж чадсангүй.',
          );
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.register(
          email: 'student@example.com',
          studentCode: 'IS24001',
          firstName: 'Болд',
          lastName: 'Бат',
          course: 2,
          password: 'secret',
          passwordConfirm: 'secret',
        ),
        throwsA(
          isA<AuthApiException>()
              .having((e) => e.statusCode, 'status', 503)
              .having((e) => e.code, 'code', 'email_delivery_failed')
              .having((e) => e.message, 'message', 'Мэйл илгээж чадсангүй.'),
        ),
      );
      expect(posts, 1);
    },
  );

  test('validation fields and Retry-After are available to forms', () async {
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.method == 'GET') return _json({'csrf_token': 'csrf'});
        return _json(
          {
            'error': {
              'code': 'validation_error',
              'message': 'Оруулсан мэдээллээ шалгана уу.',
              'details': {
                'email': ['Мэйл буруу.'],
                'password_confirm': 'Нууц үг таарахгүй байна.',
              },
            },
          },
          400,
          {'retry-after': '60'},
        );
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.resendVerification(email: 'bad'),
      throwsA(
        isA<AuthApiException>()
            .having((e) => e.fieldErrors, 'field errors', {
              'email': ['Мэйл буруу.'],
              'password_confirm': ['Нууц үг таарахгүй байна.'],
            })
            .having((e) => e.retryAfterSeconds, 'retry seconds', 60),
      ),
    );
  });

  test('CSRF bootstrap failure never sends the unsafe request', () async {
    var requests = 0;
    final api = AuthApi(
      client: MockClient((request) async {
        requests++;
        expect(request.method, 'GET');
        return _error('unavailable', 503);
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.resendVerification(email: 'student@example.com'),
      throwsA(
        isA<AuthApiException>().having((e) => e.statusCode, 'status', 503),
      ),
    );
    expect(requests, 1);
  });

  test(
    'connection and timeout errors get actionable messages without retry',
    () async {
      for (final error in [
        http.ClientException('offline'),
        TimeoutException('slow'),
      ]) {
        var requests = 0;
        final api = AuthApi(
          client: MockClient((_) async {
            requests++;
            throw error;
          }),
        );
        addTearDown(api.close);
        await expectLater(
          api.currentUser(),
          throwsA(
            isA<AuthApiException>()
                .having((e) => e.statusCode, 'status', 0)
                .having(
                  (e) => e.message,
                  'actionable message',
                  contains('шалга'),
                ),
          ),
        );
        expect(requests, 1);
      }
    },
  );

  test(
    'invalid JSON and incomplete users are not treated as logged out',
    () async {
      for (final response in [
        http.Response('<html>Proxy page</html>', 200),
        _json({
          'user': {'email': 'student@example.com'},
        }),
      ]) {
        final api = AuthApi(client: MockClient((_) async => response));
        addTearDown(api.close);
        await expectLater(
          api.currentUser(),
          throwsA(
            isA<AuthApiException>().having(
              (e) => e.code,
              'code',
              'invalid_response',
            ),
          ),
        );
      }
    },
  );
}
