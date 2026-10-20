import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_user.dart';
import 'http_client.dart';

class AuthApiException implements Exception {
  const AuthApiException({
    required this.message,
    required this.code,
    required this.statusCode,
    this.fieldErrors = const {},
    this.retryAfterSeconds,
  });

  final String message;
  final String code;
  final int statusCode;
  final Map<String, List<String>> fieldErrors;
  final int? retryAfterSeconds;

  @override
  String toString() => message;
}

class AuthApi {
  AuthApi({String? baseUrl, http.Client? client})
    : _baseUrl =
          (baseUrl ??
                  const String.fromEnvironment(
                    'API_BASE_URL',
                    defaultValue: 'http://localhost:8000',
                  ))
              .replaceAll(RegExp(r'/+$'), ''),
      _client = client ?? createAuthHttpClient();

  final String _baseUrl;
  final http.Client _client;
  String? _csrfToken;
  Future<void>? _csrfRefresh;
  static const _requestTimeout = Duration(seconds: 15);

  Future<AuthUser?> currentUser() async {
    try {
      return _user(await _request('GET', 'me'));
    } on AuthApiException catch (error) {
      if (error.statusCode == 401) return null;
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String studentCode,
    required String firstName,
    required String lastName,
    required int course,
    required String password,
    required String passwordConfirm,
  }) async {
    await _post('register', {
      'email': email.trim(),
      'student_code': studentCode.trim().toUpperCase(),
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'course': course,
      'password': password,
      'password_confirm': passwordConfirm,
    });
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
    required String password,
  }) async {
    await _post('verify-email', {
      'email': email.trim(),
      'code': code,
      'password': password,
    });
  }

  Future<void> resendVerification({required String email}) async {
    await _post('resend-verification', {'email': email.trim()});
  }

  Future<AuthUser> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async => _user(
    await _post('login', {
      'email': email.trim(),
      'password': password,
      'remember_me': rememberMe,
    }),
  );

  Future<void> logout() async {
    await _post('logout', {});
    _csrfToken = null;
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    if (_csrfToken == null) await _refreshCsrf();
    try {
      return await _request('POST', endpoint, body: body);
    } on AuthApiException catch (error) {
      // A different tab can rotate the shared cookie. Only this explicit CSRF
      // rejection is safe to retry: arbitrary failures may already have acted.
      if (error.statusCode != 403 || error.code != 'csrf_failed') rethrow;
      await _refreshCsrf();
      return _request('POST', endpoint, body: body);
    }
  }

  Future<void> _refreshCsrf() => _csrfRefresh ??= _loadCsrf().whenComplete(() {
    _csrfRefresh = null;
  });

  Future<void> _loadCsrf() async {
    final data = await _request('GET', 'csrf');
    final token = data['csrf_token'];
    if (token is! String || token.isEmpty) throw _invalidResponse();
    _csrfToken = token;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(
      method,
      Uri.parse('$_baseUrl/api/v1/auth/$endpoint/'),
    )..followRedirects = false;
    request.headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.headers['X-CSRFToken'] = _csrfToken!;
      request.body = jsonEncode(body);
    }
    late final http.Response response;
    try {
      response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(_requestTimeout);
    } on TimeoutException {
      throw const AuthApiException(
        message:
            'Серверийн хариу удаж байна. Backend ажиллаж байгаа эсэхийг шалгаад дахин оролдоно уу.',
        code: 'request_timeout',
        statusCode: 0,
      );
    } on http.ClientException {
      throw const AuthApiException(
        message:
            'Сервертэй холбогдож чадсангүй. Backend болон интернэт холболтоо шалгана уу.',
        code: 'connection_error',
        statusCode: 0,
      );
    }

    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) data = decoded;
    } on FormatException {
      // Error pages from a proxy or unavailable backend need not be JSON.
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _serverError(response, data);
    }
    if (data == null) throw _invalidResponse(response.statusCode);
    final token = data['csrf_token'];
    if (token is String && token.isNotEmpty) _csrfToken = token;
    return data;
  }

  AuthUser _user(Map<String, dynamic> data) {
    try {
      return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    } on TypeError {
      throw _invalidResponse();
    }
  }

  AuthApiException _serverError(
    http.Response response,
    Map<String, dynamic>? data,
  ) {
    final rawError = data?['error'];
    final error = rawError is Map<String, dynamic> ? rawError : null;
    final fieldErrors = <String, List<String>>{};
    final details = error?['details'];
    if (details is Map<String, dynamic>) {
      for (final entry in details.entries) {
        final value = entry.value;
        fieldErrors[entry.key] = value is List
            ? value.map((item) => item.toString()).toList()
            : [value.toString()];
      }
    }
    final seconds = int.tryParse(response.headers['retry-after'] ?? '');
    return AuthApiException(
      message: error?['message'] is String
          ? error!['message'] as String
          : 'Хүсэлт амжилтгүй боллоо. Түр хүлээгээд дахин оролдоно уу.',
      code: error?['code'] is String
          ? error!['code'] as String
          : 'request_failed',
      statusCode: response.statusCode,
      fieldErrors: fieldErrors,
      retryAfterSeconds: seconds != null && seconds >= 0 ? seconds : null,
    );
  }

  AuthApiException _invalidResponse([int statusCode = 200]) => AuthApiException(
    message:
        'Серверээс буруу хариу ирлээ. API хаяг болон backend-ээ шалгана уу.',
    code: 'invalid_response',
    statusCode: statusCode,
  );

  void close() => _client.close();
}
