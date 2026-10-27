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
  AuthApi({
    String? baseUrl,
    http.Client? client,
  })  : _baseUrl = (baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'https://oyutniimedeelelsoliltsohapp-1.onrender.com',
            ))
            .replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? createAuthHttpClient();

  final String _baseUrl;
  final http.Client _client;
  String? _csrfToken;

  static const _requestTimeout = Duration(seconds: 20);

  Future<AuthUser?> currentUser() async {
    try {
      return _user(await _request('GET', 'me'));
    } on AuthApiException catch (error) {
      if (error.statusCode == 401) return null;
      rethrow;
    }
  }

  Future<void> logout() async {
    await _request('POST', 'logout', body: const {});
    _csrfToken = null;
  }

  Future<void> resendVerification({required String email}) async {
    await _request(
      'POST',
      'resend-verification',
      body: {'email': email.trim()},
    );
  }

  /// Бүртгэл
  Future<void> register({
    required String email,
    required String studentCode,
    required String firstName,
    required String lastName,
    required int course,
    required String password,
    required String passwordConfirm,
  }) async {
    await _request(
      'POST',
      'register',
      body: {
        'email': email.trim(),
        'st_code': studentCode.trim().toUpperCase(),
        'user_firstname': firstName.trim(),
        'user_lastname': lastName.trim(),
        'course_id': course,
        'password': password,
        'password_confirm': passwordConfirm,
      },
    );
  }

  /// Имэйл баталгаажуулах
  Future<void> verifyEmail({
    required String email,
    required String code,
    required String password,
  }) async {
    await _request(
      'POST',
      'register/verify',
      body: {
        'email': email.trim(),
        'code': code.trim(),
        'password': password,
      },
    );
  }

  /// Нэвтрэх
  Future<AuthUser> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final data = await _request(
      'POST',
      'login',
      body: {
        'email': email.trim(),
        'password': password,
        'remember_me': rememberMe,
      },
    );

    return _user(data);
  }

  /// API хүсэлт илгээх
  Future<Map<String, dynamic>> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    if (method != 'GET' && endpoint != 'csrf' && _csrfToken == null) {
      final csrf = await _request('GET', 'csrf');
      _csrfToken = csrf['csrf_token'] as String?;
      if (_csrfToken == null || _csrfToken!.isEmpty) {
        throw _invalidResponse();
      }
    }

    final uri = Uri.parse(
      '$_baseUrl/api/v1/auth/$endpoint/',
    );

    final request = http.Request(method, uri)
      ..followRedirects = false;

    request.headers['Accept'] = 'application/json';
    if (method != 'GET' && _csrfToken != null) {
      request.headers['X-CSRFToken'] = _csrfToken!;
    }

    if (body != null) {
      request.headers['Content-Type'] =
          'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    late final http.Response response;

    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(_requestTimeout),
      );
    } on TimeoutException {
      throw const AuthApiException(
        message: 'Серверийн хариу удаж байна. Дахин оролдоно уу.',
        code: 'request_timeout',
        statusCode: 0,
      );
    } on http.ClientException {
      throw const AuthApiException(
        message:
            'Сервертэй холбогдож чадсангүй. Backend хаяг болон интернэтээ шалгана уу.',
        code: 'connection_error',
        statusCode: 0,
      );
    }

    Map<String, dynamic>? data;

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } on FormatException {
      // Сервер JSON бус хариу өгсөн байж болно.
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw _serverError(response, data);
    }

    if (data == null) {
      throw _invalidResponse(response.statusCode);
    }

    final rotatedToken = data['csrf_token'];
    if (rotatedToken is String && rotatedToken.isNotEmpty) {
      _csrfToken = rotatedToken;
    }

    return data;
  }

  /// Серверийн хэрэглэгчийн мэдээллийг AuthUser болгох
  AuthUser _user(Map<String, dynamic> data) {
    try {
      final userData = data['user'];

      if (userData is! Map<String, dynamic>) {
        throw _invalidResponse();
      }

      return AuthUser.fromJson(userData);
    } on TypeError {
      throw _invalidResponse();
    }
  }

  /// Backend-ийн алдааны хариуг боловсруулах
  AuthApiException _serverError(
    http.Response response,
    Map<String, dynamic>? data,
  ) {
    final rawError = data?['error'];

    final error = rawError is Map<String, dynamic>
        ? rawError
        : null;

    final message = error?['message'] ??
        data?['message'] ??
        'Хүсэлт амжилтгүй боллоо.';

    final code = error?['code'] ?? 'request_failed';

    final details = error?['details'];
    final fieldErrors = <String, List<String>>{};

    if (details is Map<String, dynamic>) {
      for (final entry in details.entries) {
        final value = entry.value;

        fieldErrors[entry.key] = value is List
            ? value.map((item) => item.toString()).toList()
            : [value.toString()];
      }
    }

    return AuthApiException(
      message: message.toString(),
      code: code.toString(),
      statusCode: response.statusCode,
      fieldErrors: fieldErrors,
      retryAfterSeconds: int.tryParse(
        response.headers['retry-after'] ?? '',
      ),
    );
  }

  AuthApiException _invalidResponse([
    int statusCode = 200,
  ]) {
    return AuthApiException(
      message:
          'Серверээс буруу хариу ирлээ. API болон backend-ээ шалгана уу.',
      code: 'invalid_response',
      statusCode: statusCode,
    );
  }

  void close() {
    _client.close();
  }
}
