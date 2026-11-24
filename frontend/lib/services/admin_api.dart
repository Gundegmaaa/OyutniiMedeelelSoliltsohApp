import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/http_client.dart';
import '../auth/api_base_url.dart';

class ManagedUser {
  const ManagedUser({
    required this.studentCode,
    required this.name,
    required this.email,
    required this.role,
    this.course,
  });

  final String studentCode;
  final String name;
  final String email;
  final String role;
  final int? course;

  factory ManagedUser.fromJson(Map<String, dynamic> json) => ManagedUser(
    studentCode: json['student_code'] as String,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'student',
    course: json['course'] as int?,
  );
}

class AdminApiException implements Exception {
  const AdminApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AdminApi {
  AdminApi({String? baseUrl, http.Client? client})
    : _baseUrl = (baseUrl ?? apiBaseUrl).replaceAll(RegExp(r'/+$'), ''),
      _client = client ?? createAuthHttpClient();

  final String _baseUrl;
  final http.Client _client;
  String? _csrfToken;

  Future<List<ManagedUser>> listUsers() async {
    final response = await _send('GET', 'users');
    if (response.statusCode != 200) throw _error(response);
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) => ManagedUser.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> setRole(String studentCode, String role) async {
    final response = await _send(
      'PATCH',
      'users/${Uri.encodeComponent(studentCode)}/role',
      {'role': role},
    );
    if (response.statusCode != 200) throw _error(response);
  }

  Future<http.Response> _send(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/auth/admin/$path/');
      if (method != 'GET') await _ensureCsrf();
      final request = http.Request(method, uri)
        ..headers['Accept'] = 'application/json';
      if (method != 'GET' && _csrfToken != null) {
        request.headers['X-CSRFToken'] = _csrfToken!;
      }
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      return await http.Response.fromStream(await _client.send(request))
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const AdminApiException('Серверийн хариу удаж байна.');
    } on http.ClientException {
      throw const AdminApiException('Сервертэй холбогдож чадсангүй.');
    }
  }

  Future<void> _ensureCsrf() async {
    if (_csrfToken != null) return;
    final response = await _client.get(Uri.parse('$_baseUrl/api/v1/auth/csrf/'));
    if (response.statusCode != 200) {
      throw const AdminApiException('CSRF баталгаажуулалтын мэдээлэл авч чадсангүй.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _csrfToken = data['csrf_token'] as String?;
    if (_csrfToken == null) {
      throw const AdminApiException('CSRF баталгаажуулалтын мэдээлэл хоосон байна.');
    }
  }

  AdminApiException _error(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] is String) {
        return AdminApiException(body['message'] as String);
      }
    } on FormatException {
      // Use the generic response below.
    }
    return AdminApiException('Хэрэглэгчийн эрхийг өөрчилж чадсангүй (${response.statusCode}).');
  }
}
