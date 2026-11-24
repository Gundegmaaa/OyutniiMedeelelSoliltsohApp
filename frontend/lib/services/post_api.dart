import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/http_client.dart';
import '../models/post.dart';

class PostApiException implements Exception {
  const PostApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

typedef LikeState = ({bool liked, int count});

class PostApi {
  PostApi({String? baseUrl, http.Client? client})
    : _baseUrl =
          (baseUrl ??
                  const String.fromEnvironment(
                    'API_BASE_URL',
                    defaultValue:
                        'https://oyutniimedeelelsoliltsohapp-1.onrender.com',
                  ))
              .replaceAll(RegExp(r'/+$'), ''),
      _client = client ?? createAuthHttpClient();

  final String _baseUrl;
  final http.Client _client;
  String? _csrfToken;
  static const _timeout = Duration(seconds: 25);

  Uri get _uri => Uri.parse('$_baseUrl/api/v1/posts/');

  Future<List<Post>> listPosts() async {
    final response = await _send(
      () => _client.get(_uri, headers: const {'Accept': 'application/json'}),
    );
    if (response.statusCode != 200) {
      throw PostApiException(
        'Заруудыг татаж чадсангүй (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    try {
      final items = jsonDecode(response.body) as List<dynamic>;
      return items
          .map((item) => _postFromJson(item as Map<String, dynamic>))
          .toList();
    } on FormatException {
      throw const PostApiException('Backend буруу хариу буцаалаа.');
    }
  }

  /// Saves the post and returns its server id.
  Future<int?> createPost(Post post) async {
    await _ensureCsrf();
    final request = _postRequest('POST', post);

    final response = await _send(
      () async => http.Response.fromStream(await _client.send(request)),
      timeoutMessage: 'Хүсэлт удаж байна. Дахин оролдоно уу.',
    );
    if (response.statusCode != 201) {
      throw PostApiException(
        _errorMessage(response, 'Зар нэмэхэд алдаа гарлаа'),
        statusCode: response.statusCode,
      );
    }
    try {
      final body = jsonDecode(response.body);
      final data = body is Map ? body['data'] : null;
      return data is Map ? data['id'] as int? : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> updatePost(Post post) async {
    await _ensureCsrf();
    final id = post.id;
    if (id == null) throw const PostApiException('Энэ зар серверт хадгалагдаагүй байна.');
    final response = await _send(
      () async => http.Response.fromStream(
        await _client.send(_postRequest('PATCH', post, id: id)),
      ),
      timeoutMessage: 'Хүсэлт удаж байна. Дахин оролдоно уу.',
    );
    if (response.statusCode != 200) {
      throw PostApiException(
        _errorMessage(response, 'Зар засахад алдаа гарлаа'),
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> deletePost(int id) async {
    await _ensureCsrf();
    final response = await _send(
      () => _client.delete(
        Uri.parse('$_baseUrl/api/v1/posts/$id/'),
        headers: {'Accept': 'application/json', 'X-CSRFToken': _csrfToken!},
      ),
    );
    if (response.statusCode != 204) {
      throw PostApiException(
        _errorMessage(response, 'Зар устгахад алдаа гарлаа'),
        statusCode: response.statusCode,
      );
    }
  }

  http.MultipartRequest _postRequest(String method, Post post, {int? id}) {
    final uri = id == null ? _uri : Uri.parse('$_baseUrl/api/v1/posts/$id/');
    final request = http.MultipartRequest(method, uri)
      ..headers['Accept'] = 'application/json'
      ..headers['X-CSRFToken'] = _csrfToken!
      ..fields['title'] = post.title
      ..fields['content'] = post.body
      ..fields['post_type'] = _postType(post.category)
      ..fields['audience_courses'] = post.audienceCourses.join(',');

    final numericPrice = post.price?.replaceAll(RegExp(r'[^0-9.]'), '');
    if (numericPrice != null && numericPrice.isNotEmpty) {
      request.fields['price'] = numericPrice;
    }
    if (post.imageBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          post.imageBytes!,
          filename: post.imageName ?? 'post-image.jpg',
        ),
      );
    }

    return request;
  }

  /// Adds or removes the signed-in student's reaction.
  Future<LikeState> toggleLike(int postId) async {
    await _ensureCsrf();
    final response = await _send(
      () => _client.post(
        Uri.parse('$_baseUrl/api/v1/posts/$postId/like/'),
        headers: {'Accept': 'application/json', 'X-CSRFToken': _csrfToken!},
      ),
    );
    if (response.statusCode != 200) {
      throw PostApiException(
        _errorMessage(response, 'Таалагдсаныг хадгалж чадсангүй'),
        statusCode: response.statusCode,
      );
    }
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (liked: body['liked'] as bool, count: body['like_count'] as int);
    } on FormatException {
      throw const PostApiException('Backend буруу хариу буцаалаа.');
    }
  }

  Future<void> _ensureCsrf() async {
    if (_csrfToken != null) return;
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/v1/auth/csrf/'))
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw const PostApiException('CSRF баталгаажуулалтын мэдээлэл авч чадсангүй.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _csrfToken = data['csrf_token'] as String?;
      if (_csrfToken == null) {
        throw const PostApiException('CSRF баталгаажуулалтын мэдээлэл хоосон байна.');
      }
    } on TimeoutException {
      throw const PostApiException('Серверийн хариу удаж байна.');
    } on http.ClientException {
      throw const PostApiException('Backend сервертэй холбогдож чадсангүй.');
    }
  }

  /// Names of the students who reacted, newest first.
  Future<List<String>> listLikers(int postId) async {
    final response = await _send(
      () => _client.get(
        Uri.parse('$_baseUrl/api/v1/posts/$postId/likes/'),
        headers: const {'Accept': 'application/json'},
      ),
    );
    if (response.statusCode != 200) {
      throw PostApiException(
        _errorMessage(response, 'Жагсаалтыг татаж чадсангүй'),
        statusCode: response.statusCode,
      );
    }
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['people'] as List<dynamic>)
          .map((person) => _personLabel(person as Map<String, dynamic>))
          .toList();
    } on FormatException {
      throw const PostApiException('Backend буруу хариу буцаалаа.');
    }
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    String timeoutMessage = 'Серверээс хариу ирсэнгүй.',
  }) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw PostApiException(timeoutMessage);
    } on http.ClientException {
      throw const PostApiException('Backend сервертэй холбогдож чадсангүй.');
    }
  }

  String _postType(PostCategory category) => switch (category) {
    PostCategory.sale => 'sell',
    PostCategory.exchange => 'exchange',
    PostCategory.rental => 'rental',
    PostCategory.question => 'question',
    PostCategory.teacher => 'teacher',
  };

  String _personLabel(Map<String, dynamic> person) {
    final name = person['name'] as String? ?? 'Оюутан';
    final course = person['course'];
    return course == null ? name : '$name • $course-р курс';
  }

  Post _postFromJson(Map<String, dynamic> json) {
    final category = switch (json['post_type']) {
      'sell' => PostCategory.sale,
      'exchange' => PostCategory.exchange,
      'rental' => PostCategory.rental,
      'question' => PostCategory.question,
      'teacher' => PostCategory.teacher,
      _ => PostCategory.teacher,
    };
    final price = num.tryParse(json['price']?.toString() ?? '');
    final author = json['author'];
    final image = json['image'] as String?;
    return Post(
      id: json['id'] as int?,
      author: author is Map<String, dynamic> ? _personLabel(author) : 'Оюутан',
      subtitle: '',
      title: json['title'] as String? ?? '',
      body: json['content'] as String? ?? '',
      category: category,
      avatar: switch (category) {
        PostCategory.question => PostAvatar.chat,
        PostCategory.teacher => PostAvatar.person,
        _ => PostAvatar.gift,
      },
      price: price == null ? null : formatMoney(price),
      imageUrl: image == null || image.isEmpty ? null : image,
      likes: json['like_count'] as int? ?? 0,
      liked: json['liked'] as bool? ?? false,
      isMine: json['is_mine'] as bool? ?? false,
      audienceCourses: (json['audience_courses'] as List<dynamic>? ?? const [])
          .whereType<int>()
          .toList(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      time: 'Шинэ',
    );
  }

  String _errorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final message = body['message'];
        final errors = body['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          return first is List && first.isNotEmpty
              ? first.first.toString()
              : first.toString();
        }
        if (message is String && message.isNotEmpty) return message;
      }
    } on FormatException {
      // Use the status-based message below for non-JSON error responses.
    }
    return '$fallback (${response.statusCode}).';
  }

  void close() => _client.close();
}
