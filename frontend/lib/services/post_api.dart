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

class PostApi {
  PostApi({String? baseUrl, http.Client? client})
    : _baseUrl = (baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'https://oyutniimedeelelsoliltsohapp-1.onrender.com',
          )).replaceAll(RegExp(r'/+$'), ''),
      _client = client ?? createAuthHttpClient();

  final String _baseUrl;
  final http.Client _client;
  static const _timeout = Duration(seconds: 25);

  Uri get _uri => Uri.parse('$_baseUrl/api/v1/posts/');

  Future<List<Post>> listPosts() async {
    try {
      final response = await _client.get(
        _uri,
        headers: const {'Accept': 'application/json'},
      ).timeout(_timeout);
      if (response.statusCode != 200) {
        throw PostApiException(
          'Заруудыг татаж чадсангүй (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
      final items = jsonDecode(response.body) as List<dynamic>;
      return items
          .map((item) => _postFromJson(item as Map<String, dynamic>))
          .toList();
    } on TimeoutException {
      throw const PostApiException('Серверээс хариу ирсэнгүй.');
    } on http.ClientException {
      throw const PostApiException('Backend сервертэй холбогдож чадсангүй.');
    } on FormatException {
      throw const PostApiException('Backend буруу хариу буцаалаа.');
    }
  }

  Future<void> createPost(Post post) async {
    final request = http.MultipartRequest('POST', _uri)
      ..headers['Accept'] = 'application/json'
      ..fields['title'] = post.title
      ..fields['content'] = post.body
      ..fields['post_type'] = _postType(post.category);

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

    try {
      final streamed = await _client.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 201) {
        throw PostApiException(
          _errorMessage(response),
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw const PostApiException('Хүсэлт удаж байна. Дахин оролдоно уу.');
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

  Post _postFromJson(Map<String, dynamic> json) {
    final category = switch (json['post_type']) {
      'sell' => PostCategory.sale,
      'exchange' => PostCategory.exchange,
      'rental' => PostCategory.rental,
      'question' => PostCategory.question,
      'teacher' => PostCategory.teacher,
      _ => PostCategory.teacher,
    };
    final price = json['price']?.toString();
    return Post(
      author: 'Оюутан',
      subtitle: '',
      title: json['title'] as String? ?? '',
      body: json['content'] as String? ?? '',
      category: category,
      price: price == null ? null : '$price₮',
      time: 'Шинэ',
    );
  }

  String _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final message = body['message'];
      if (message is String && message.isNotEmpty) return message;
      final errors = body['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        return first is List && first.isNotEmpty
            ? first.first.toString()
            : first.toString();
      }
    } on FormatException {
      // Use the status-based message below for non-JSON error responses.
    }
    return 'Зар нэмэхэд алдаа гарлаа (${response.statusCode}).';
  }

  void close() => _client.close();
}
