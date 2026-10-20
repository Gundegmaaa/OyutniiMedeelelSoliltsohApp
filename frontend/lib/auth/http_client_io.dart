import 'dart:io';

import 'package:http/http.dart' as http;

http.Client createAuthHttpClient() => _CookieClient();

// Native sessions live in memory only. Browser persistence is handled by the
// browser's cookie store; this native client does not implement durable storage.
class _CookieClient extends http.BaseClient {
  final HttpClient _client = HttpClient();
  final Map<String, Map<String, Cookie>> _cookies = {};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      final outgoing = await _client.openUrl(request.method, request.url);
      outgoing.followRedirects = request.followRedirects;
      outgoing.maxRedirects = request.maxRedirects;
      outgoing.persistentConnection = request.persistentConnection;
      outgoing.contentLength = request.contentLength ?? -1;
      request.headers.forEach(outgoing.headers.set);
      final jar = _cookies[request.url.origin];
      final now = DateTime.now();
      jar?.removeWhere(
        (_, cookie) => cookie.expires != null && !cookie.expires!.isAfter(now),
      );
      for (final cookie in jar?.values ?? <Cookie>[]) {
        final path = cookie.path ?? '/';
        final matchesPath =
            request.url.path == path ||
            (request.url.path.startsWith(path) &&
                (path.endsWith('/') ||
                    request.url.path.substring(path.length).startsWith('/')));
        if (matchesPath && (!cookie.secure || request.url.scheme == 'https')) {
          outgoing.cookies.add(cookie);
        }
      }
      await outgoing.addStream(request.finalize());
      final incoming = await outgoing.close();
      final currentJar = _cookies.putIfAbsent(request.url.origin, () => {});
      for (final cookie in incoming.cookies) {
        final key = '${cookie.path ?? '/'}:${cookie.name}';
        if (cookie.maxAge != null) {
          cookie.expires = now.add(Duration(seconds: cookie.maxAge!));
        }
        if (cookie.expires != null && !cookie.expires!.isAfter(now)) {
          currentJar.remove(key);
        } else {
          currentJar[key] = cookie;
        }
      }
      final headers = <String, String>{};
      incoming.headers.forEach(
        (key, values) => headers[key] = values.join(','),
      );
      return http.StreamedResponse(
        incoming,
        incoming.statusCode,
        contentLength: incoming.contentLength < 0
            ? null
            : incoming.contentLength,
        request: request,
        headers: headers,
        isRedirect: incoming.isRedirect,
        persistentConnection: incoming.persistentConnection,
        reasonPhrase: incoming.reasonPhrase,
      );
    } on IOException {
      throw http.ClientException('Unable to connect to the API.', request.url);
    }
  }

  @override
  void close() {
    _cookies.clear();
    _client.close(force: true);
  }
}
