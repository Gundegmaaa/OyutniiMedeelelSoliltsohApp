import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/http_client.dart';
import '../auth/api_base_url.dart';
import '../models/calendar_event.dart';
import 'calendar_event_store.dart';

class CalendarEventApiStore implements CalendarEventStore {
  CalendarEventApiStore({String? baseUrl, http.Client? client})
    : _baseUrl = (baseUrl ?? apiBaseUrl).replaceAll(RegExp(r'/+$'), ''),
      _client = client ?? createAuthHttpClient();

  final String _baseUrl;
  final http.Client _client;
  String? _csrfToken;
  Map<String, CalendarEvent> _saved = {};

  Uri _uri([String? id]) => Uri.parse(
    '$_baseUrl/api/v1/posts/calendar/${id == null ? '' : '$id/'}',
  );

  @override
  Future<List<CalendarEvent>> load() async {
    final response = await _request('GET', _uri());
    if (response.statusCode != 200) {
      throw StateError(_message(response, 'Хуваарийг уншиж чадсангүй.'));
    }
    final items = jsonDecode(response.body) as List<dynamic>;
    final events = items.map((item) {
      final json = Map<String, dynamic>.from(item as Map);
      json['id'] = json['id'].toString();
      return CalendarEvent.fromJson(json);
    }).toList();
    _saved = {for (final event in events) event.id: event};
    return events;
  }

  @override
  Future<void> save(List<CalendarEvent> events) async {
    final nextIds = events.map((event) => event.id).toSet();
    for (final previous in _saved.values) {
      if (!nextIds.contains(previous.id)) {
        final response = await _request('DELETE', _uri(previous.id));
        if (response.statusCode != 204) {
          throw StateError(_message(response, 'Хуваарь устгаж чадсангүй.'));
        }
      }
    }

    final next = <String, CalendarEvent>{};
    for (final event in events) {
      final previous = _saved[event.id];
      final body = event.toJson()..remove('id');
      if (previous == null) {
        final response = await _request('POST', _uri(), body: body);
        if (response.statusCode != 201) {
          throw StateError(_message(response, 'Хуваарь хадгалж чадсангүй.'));
        }
        final created = jsonDecode(response.body) as Map<String, dynamic>;
        event.id = created['id'].toString();
      } else if (jsonEncode(previous.toJson()) != jsonEncode(event.toJson())) {
        final response = await _request(
          'PATCH',
          _uri(event.id),
          body: body,
        );
        if (response.statusCode != 200) {
          throw StateError(_message(response, 'Хуваарь шинэчилж чадсангүй.'));
        }
      }
      next[event.id] = event;
    }
    _saved = next;
  }

  Future<http.Response> _request(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
  }) async {
    try {
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
      throw StateError('Серверийн хариу удаж байна.');
    } on http.ClientException {
      throw StateError('Сервертэй холбогдож чадсангүй.');
    }
  }

  Future<void> _ensureCsrf() async {
    if (_csrfToken != null) return;
    final response = await _client.get(Uri.parse('$_baseUrl/api/v1/auth/csrf/'));
    if (response.statusCode != 200) {
      throw StateError('CSRF баталгаажуулалтын мэдээлэл авч чадсангүй.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _csrfToken = data['csrf_token'] as String?;
    if (_csrfToken == null) {
      throw StateError('CSRF баталгаажуулалтын мэдээлэл хоосон байна.');
    }
  }

  String _message(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
    } on FormatException {
      // Fall back to the status-bearing message.
    }
    return '$fallback (${response.statusCode})';
  }
}
