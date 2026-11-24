import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/http_client.dart';
import '../models/lesson_schedule.dart';

class LessonScheduleApiException implements Exception {
  const LessonScheduleApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LessonScheduleApi {
  LessonScheduleApi({String? baseUrl, http.Client? client})
    : _baseUrl = (baseUrl ?? const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'https://oyutniimedeelelsoltohapp-1.onrender.com',
          )).replaceAll(RegExp(r'/+$'), ''),
      _client = client ?? createAuthHttpClient();

  final String _baseUrl;
  final http.Client _client;
  String? _csrfToken;

  Uri get _uri => Uri.parse('$_baseUrl/api/v1/posts/lessons/');

  Future<List<LessonSchedule>> list() async {
    final response = await _send('GET', _uri);
    if (response.statusCode != 200) throw _error(response, 'Хуваарь уншиж чадсангүй.');
    return (jsonDecode(response.body) as List<dynamic>)
        .map((item) => LessonSchedule.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<LessonSchedule> create(LessonSchedule lesson) async {
    final response = await _send('POST', _uri, lesson.toJson());
    if (response.statusCode != 201) throw _error(response, 'Хуваарь нэмэж чадсангүй.');
    return LessonSchedule.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<LessonSchedule> update(LessonSchedule lesson) async {
    final response = await _send('PATCH', _uriFor(lesson.id), lesson.toJson());
    if (response.statusCode != 200) throw _error(response, 'Хуваарь засаж чадсангүй.');
    return LessonSchedule.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    final response = await _send('DELETE', _uriFor(id));
    if (response.statusCode != 204) throw _error(response, 'Хуваарь устгаж чадсангүй.');
  }

  Uri _uriFor(String id) => Uri.parse('${_uri.toString()}$id/');

  Future<http.Response> _send(
    String method,
    Uri uri, [
    Map<String, Object?>? body,
  ]) async {
    try {
      if (method != 'GET') await _ensureCsrf();
      final request = http.Request(method, uri)
        ..headers['Accept'] = 'application/json';
      if (method != 'GET') request.headers['X-CSRFToken'] = _csrfToken!;
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      return await http.Response.fromStream(await _client.send(request))
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const LessonScheduleApiException('Серверийн хариу удаж байна.');
    } on http.ClientException {
      throw const LessonScheduleApiException('Сервертэй холбогдож чадсангүй.');
    }
  }

  Future<void> _ensureCsrf() async {
    if (_csrfToken != null) return;
    final response = await _client.get(Uri.parse('$_baseUrl/api/v1/auth/csrf/'));
    if (response.statusCode != 200) {
      throw const LessonScheduleApiException('CSRF баталгаажуулалт амжилтгүй.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _csrfToken = data['csrf_token'] as String?;
    if (_csrfToken == null) {
      throw const LessonScheduleApiException('CSRF токен ирсэнгүй.');
    }
  }

  LessonScheduleApiException _error(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['message'] is String) {
        return LessonScheduleApiException(data['message'] as String);
      }
    } on FormatException {
      // Use the status fallback.
    }
    return LessonScheduleApiException('$fallback (${response.statusCode})');
  }
}
