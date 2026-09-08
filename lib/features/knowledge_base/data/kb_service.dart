import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/config/app_api_config.dart';
import '../../auth/data/token_storage.dart';
import 'models/kb_article.dart';
import 'models/kb_category.dart';
import 'models/kb_comment.dart';
import 'models/kb_tag.dart';

class KbArticlesResponse {
  final List<KbArticle> articles;
  final KbPagination? pagination;

  KbArticlesResponse({
    required this.articles,
    this.pagination,
  });
}

class KbService {
  final String baseUrl;
  final TokenStorage storage;
  final http.Client? _client;
  static const Duration _requestTimeout = Duration(seconds: 20);

  KbService({
    this.baseUrl = '',
    TokenStorage? storage,
    http.Client? client,
  })  : storage = storage ?? TokenStorage(),
        _client = client;

  http.Client get client => _client ?? http.Client();

  String get _activeBaseUrl {
    final root = baseUrl.isNotEmpty ? baseUrl : AppApiConfig.evidenciasBaseUrl;
    // Remove trailing slashes and ensure /kb endpoint suffix
    final cleanRoot = root.endsWith('/') ? root.substring(0, root.length - 1) : root;
    return '$cleanRoot/kb';
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// 1. Listar Categorías
  Future<List<KbCategory>> getCategories({bool tree = false}) async {
    final uri = Uri.parse('$_activeBaseUrl/categories?tree=${tree ? 1 : 0}');
    final headers = await _getHeaders();

    final response = await client.get(uri, headers: headers).timeout(_requestTimeout);
    final data = _decodeBody(response);

    if (data is Map<String, dynamic> && data['data'] is List) {
      return (data['data'] as List)
          .map((item) => KbCategory.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// 2. Listar Artículos (con Búsqueda, Filtros y Paginación)
  Future<KbArticlesResponse> getArticles({
    String? search,
    int? categoryId,
    String? tag,
    String? sort,
    int page = 1,
    int limit = 15,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (categoryId != null && categoryId > 0) {
      queryParams['category_id'] = categoryId.toString();
    }
    if (tag != null && tag.trim().isNotEmpty) {
      queryParams['tag'] = tag.trim();
    }
    if (sort != null && sort.trim().isNotEmpty) {
      queryParams['sort'] = sort.trim();
    }

    final uri = Uri.parse('$_activeBaseUrl/articles').replace(queryParameters: queryParams);
    final headers = await _getHeaders();

    final response = await client.get(uri, headers: headers).timeout(_requestTimeout);
    final data = _decodeBody(response);

    List<KbArticle> articles = [];
    KbPagination? pagination;

    if (data is Map<String, dynamic>) {
      if (data['data'] is List) {
        articles = (data['data'] as List)
            .map((item) => KbArticle.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      if (data['pagination'] is Map<String, dynamic>) {
        pagination = KbPagination.fromJson(data['pagination'] as Map<String, dynamic>);
      }
    }

    return KbArticlesResponse(articles: articles, pagination: pagination);
  }

  /// 3. Obtener Detalle de un Artículo
  Future<KbArticle> getArticleDetail(dynamic idOrSlug) async {
    final uri = Uri.parse('$_activeBaseUrl/articles/$idOrSlug');
    final headers = await _getHeaders();

    final response = await client.get(uri, headers: headers).timeout(_requestTimeout);
    final data = _decodeBody(response);

    if (data is Map<String, dynamic>) {
      final articleData = data['data'];
      if (articleData is Map<String, dynamic>) {
        if (articleData.containsKey('article') && articleData['article'] is Map<String, dynamic>) {
          final fullJson = Map<String, dynamic>.from(articleData['article'] as Map<String, dynamic>);
          if (articleData.containsKey('related')) {
            fullJson['related'] = articleData['related'];
          }
          if (articleData.containsKey('comments')) {
            fullJson['comments'] = articleData['comments'];
          }
          return KbArticle.fromJson(fullJson);
        } else {
          return KbArticle.fromJson(articleData);
        }
      }
    }
    throw Exception('No se pudo obtener la información del artículo.');
  }

  /// 4. Enviar Calificación de Utilidad (Feedback)
  Future<void> sendFeedback(
    int articleId, {
    required bool isHelpful,
    String? comment,
    String? userCode,
    String? userName,
  }) async {
    final uri = Uri.parse('$_activeBaseUrl/articles/$articleId/feedback');
    final headers = await _getHeaders();
    final body = jsonEncode({
      'is_helpful': isHelpful,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      if (userCode != null && userCode.isNotEmpty) 'user_code': userCode,
      if (userName != null && userName.isNotEmpty) 'user_name': userName,
    });

    final response = await client.post(uri, headers: headers, body: body).timeout(_requestTimeout);
    _checkSuccess(response, defaultError: 'Error al enviar retroalimentación.');
  }

  /// 5. Publicar un Comentario
  Future<KbComment> postComment(
    int articleId, {
    required String comment,
    required String userCode,
    String? userName,
  }) async {
    final uri = Uri.parse('$_activeBaseUrl/articles/$articleId/comments');
    final headers = await _getHeaders();
    final body = jsonEncode({
      'comment': comment.trim(),
      'user_code': userCode.trim(),
      if (userName != null && userName.isNotEmpty) 'user_name': userName.trim(),
    });

    final response = await client.post(uri, headers: headers, body: body).timeout(_requestTimeout);
    final data = _decodeBody(response);

    int newId = 0;
    if (data is Map<String, dynamic> && data['comment_id'] != null) {
      newId = KbArticle.parseInt(data['comment_id']);
    }

    return KbComment(
      id: newId,
      userName: (userName != null && userName.isNotEmpty) ? userName : 'Usuario',
      comment: comment.trim(),
      createdAt: DateTime.now().toIso8601String().replaceFirst('T', ' ').split('.').first,
    );
  }

  /// 6. Listar Etiquetas (Tags)
  Future<List<KbTag>> getTags() async {
    final uri = Uri.parse('$_activeBaseUrl/tags');
    final headers = await _getHeaders();

    final response = await client.get(uri, headers: headers).timeout(_requestTimeout);
    final data = _decodeBody(response);

    if (data is Map<String, dynamic> && data['data'] is List) {
      return (data['data'] as List)
          .map((item) => KbTag.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  dynamic _decodeBody(http.Response response) {
    final body = response.body.trim();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error del servidor (${response.statusCode}): $body');
    }
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['status'] == 'error') {
        throw Exception(decoded['message']?.toString() ?? 'Error en la petición.');
      }
      return decoded;
    } on FormatException {
      throw Exception('Respuesta no válida del servidor.');
    }
  }

  void _checkSuccess(http.Response response, {required String defaultError}) {
    final body = response.body.trim();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$defaultError (${response.statusCode}): $body');
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['status'] == 'error') {
        throw Exception(decoded['message']?.toString() ?? defaultError);
      }
    } catch (_) {}
  }
}
