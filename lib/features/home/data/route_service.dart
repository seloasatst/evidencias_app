import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../auth/data/token_storage.dart';
import 'route_models.dart';

class RouteService {
  final String baseUrl;
  final TokenStorage storage;
  final http.Client _client;
  final bool _disposeClient;
  static const Duration _requestTimeout = Duration(seconds: 30);
  static const Duration _uploadTimeout = Duration(seconds: 90);

  RouteService({
    required this.baseUrl, 
    required this.storage,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _disposeClient = client == null;

  void _log(String message) {
    debugPrint(message);
  }

  Future<http.Response> _getWithRetry(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    try {
      return await _client.get(
        uri,
        headers: headers,
      ).timeout(_requestTimeout);
    } catch (e) {
      debugPrint('--- ERROR EN PETICIÓN: $e ---');
      rethrow;
    }
  }

  Future<RoutePaginatedResponse> getPendingRoutes({
    required String userCode,
    required String userRole,
    String? startDate,
    int page = 1,
    int pageSize = 10,
    bool includeCount = false,
  }) async {
    final token = await storage.getToken();
    final queryParams = {
      'userRole': userRole,
      if (startDate != null) 'startDate': startDate,
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      'includeCount': includeCount.toString(),
    };

    final uri = Uri.parse('$baseUrl/evidencias/pendientes/$userCode').replace(
      queryParameters: queryParams,
    );
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      debugPrint('--- LLAMADA GUIAS (PAGINADA) ---');
      debugPrint('URL: $uri');

      final res = await _getWithRetry(uri, headers: headers);
      
      if (res.statusCode == 200) {
        // 🚀 OPTIMIZACIÓN: Procesamos el JSON en un Isolate para no bloquear el hilo principal
        return await compute(_parsePendingRoutesIsolate, res.bodyBytes);
      }
      
      debugPrint('--- ERROR SERVIDOR: Status ${res.statusCode} ---');
      debugPrint('Cuerpo: ${res.body}');
      return RoutePaginatedResponse(routes: [], totalCount: 0);
    } catch (e) {
      debugPrint('--- ERROR EN LLAMADA: $e ---');
      return RoutePaginatedResponse(routes: [], totalCount: 0);
    }
  }

  static RoutePaginatedResponse _parsePendingRoutesIsolate(Uint8List bodyBytes) {
    final decoded = jsonDecode(utf8.decode(bodyBytes, allowMalformed: true));
    List data;
    int total;

    if (decoded is List) {
      data = decoded;
      total = decoded.length;
    } else if (decoded is Map<String, dynamic>) {
      data = decoded['data'] ?? [];
      final rawTotal = decoded['totalCount'] ?? decoded['total'];
      total = (rawTotal is int && rawTotal > 0) ? rawTotal : data.length;
    } else {
      throw Exception('Formato de respuesta desconocido');
    }
    
    final routes = data.map((j) => RouteModel.fromJson(Map<String, dynamic>.from(j))).toList();
    return RoutePaginatedResponse(routes: routes, totalCount: total);
  }

  // NUEVA FUNCIÓN PARA ADMINISTRADORES (Basada en la lógica de Paquetería)
  Future<RoutePaginatedResponse> getAdminRoutes({
    required String userCode,
    String? startDate,
    int page = 1,
    int pageSize = 10,
  }) async {
    final token = await storage.getToken();
    
    final uri = Uri.parse('$baseUrl/evidencias/admin/$userCode').replace(
      queryParameters: {
        if (startDate != null) 'startDate': startDate,
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      },
    );

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      debugPrint('--- LLAMADA ADMIN (GUIDE0) ---');
      debugPrint('URL: $uri');
      final res = await _getWithRetry(uri, headers: headers);
      
      if (res.statusCode == 200) {
        // 🚀 OPTIMIZACIÓN: Procesamos el JSON en un Isolate
        return await compute(_parseAdminRoutesIsolate, res.bodyBytes);
      }
      return RoutePaginatedResponse(routes: [], totalCount: 0);
    } catch (e) {
      debugPrint('Error en getAdminRoutes: $e');
      return RoutePaginatedResponse(routes: [], totalCount: 0);
    }
  }

  static RoutePaginatedResponse _parseAdminRoutesIsolate(Uint8List bodyBytes) {
    final Map<String, dynamic> json = jsonDecode(utf8.decode(bodyBytes, allowMalformed: true));
    final List data = json['data'] ?? [];
    final rawTotal = json['totalCount'] ?? json['total'];
    final total = (rawTotal is int && rawTotal > 0) ? rawTotal : data.length;
    
    final routes = data.map((j) => RouteModel.fromJson(Map<String, dynamic>.from(j))).toList();
    return RoutePaginatedResponse(routes: routes, totalCount: total);
  }

  Future<List<OrderModel>> getRouteDetail(String numGuia) async {
    final token = await storage.getToken();
    final uri = Uri.parse('$baseUrl/evidencias/detalle/$numGuia');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final res = await _getWithRetry(uri, headers: headers);

      if (res.statusCode == 200) {
        final body = res.body.isNotEmpty ? jsonDecode(res.body) : [];
        final List jsonList = body is List
            ? body
            : (body is Map<String, dynamic> && body['data'] is List)
                ? body['data'] as List
                : [];

        debugPrint('--- DETALLE ÉXITO: ${jsonList.length} órdenes ---');
        return jsonList
            .map((j) => OrderModel.fromJson({
                  ...Map<String, dynamic>.from(j),
                  if ((j as Map)['numGuia'] == null) 'numGuia': numGuia,
                }))
            .toList();
      }

      debugPrint('--- ERROR DETALLE: Status ${res.statusCode} ---');
      debugPrint('Cuerpo: ${res.body}');
      throw Exception('Error al cargar detalle de la guía: ${res.statusCode}');
    } catch (e) {
      debugPrint('--- ERROR EN DETALLE: $e ---');
      return [];
    }
  }

  Future<List<String>> getUnits() async {
    final token = await storage.getToken();
    final uri = Uri.parse('$baseUrl/unidades');

    try {
      final res = await _client.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final List jsonList = jsonDecode(res.body);
        return jsonList.map((j) => j.toString()).toList();
      }
      return [];
    } catch (e) {
      _log('Error al cargar unidades: $e');
      return [];
    }
  }

  Future<bool> sendEvidence({
    required String routeId,
    required String orderId,
    required String userCode,
    required String os,
    required String result,
    required String quantity,
    required String observations,
    required String timestamp,
    String? photoPath,
    String? photoBase64,
    Uint8List? photoBytes,
    String? photoFileName,
  }) async {
    final token = await storage.getToken();
    final uri = Uri.parse('$baseUrl/evidencias/upload');
    final baseUri = Uri.parse(baseUrl);
    final uploadUri = Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.port,
      path: '/seloasa/subida-imagen',
    );
    final quantityValue = int.tryParse(
          RegExp(r'\d+').firstMatch(quantity)?.group(0) ?? '',
        ) ??
        0;

    final photos = <Map<String, dynamic>>[];
    String? currentBase64;
    String? currentFileName;

    if (photoBytes != null && photoBytes.isNotEmpty) {
      currentBase64 = base64Encode(photoBytes);
      currentFileName = (photoFileName != null && photoFileName.isNotEmpty)
          ? photoFileName
          : 'evidencia.jpg';
    } else if (photoBase64 != null && photoBase64.isNotEmpty) {
      currentBase64 = photoBase64;
      currentFileName = (photoFileName != null && photoFileName.isNotEmpty)
          ? photoFileName
          : 'evidencia.jpg';
    } else if (photoPath != null && photoPath.isNotEmpty) {
      final file = File(photoPath);
      final bytes = await file.readAsBytes();
      currentBase64 = base64Encode(bytes);
      currentFileName = photoPath.split(Platform.pathSeparator).last;
    }

    if (currentBase64 != null) {
      try {
        await _client.post(
          uploadUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'ordenServicio': orderId,
            'imagen64': currentBase64,
          }),
        ).timeout(const Duration(seconds: 30));
      } catch (e) {
        _log('Error al subir evidencia al portal: $e');
      }

      photos.add({
        'fileName': currentFileName ?? 'evidencia.jpg',
        'base64': currentBase64,
      });
    }

    final payload = {
      'routeId': routeId,
      'orderId': orderId,
      'status': result,
      'quantity': quantityValue,
      'comments': observations,
      'fechaEntrega': timestamp,
      'userCode': userCode,
    };

    final mainRequest = _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    ).timeout(_uploadTimeout);

    // 🚀 OPTIMIZACIÓN: Ejecutamos la subida al portal en paralelo si existe imagen
    Future<void>? portalRequest;
    if (currentBase64 != null) {
      portalRequest = _client.post(
        uploadUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ordenServicio': orderId,
          'imagen64': currentBase64,
        }),
      ).timeout(const Duration(seconds: 30)).then((_) => null).catchError((e) {
        _log('Error al subir evidencia al portal: $e');
      });
    }

    final res = await mainRequest;
    if (portalRequest != null) {
      // No esperamos al portal para responder al usuario, 
      // pero dejamos que termine en segundo plano o lo esperamos al final si es necesario.
      // Por ahora, priorizamos la respuesta de la API principal.
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = res.body.trim();
      if (body.isNotEmpty) {
        dynamic decoded;
        try {
          decoded = jsonDecode(body);
        } on FormatException {
          decoded = null;
        }

        if (decoded is Map<String, dynamic>) {
          final successValue = decoded['success'];
          if (successValue is bool && successValue == false) {
            throw Exception(
              decoded['message']?.toString() ?? 'El servidor rechazó la evidencia.',
            );
          }
        }
      }
      return true;
    }

    final body = res.body.trim();
    throw Exception(
      body.isEmpty
          ? 'Error al enviar evidencia (${res.statusCode}).'
          : 'Error al enviar evidencia (${res.statusCode}): $body',
    );
  }

  Future<bool> sendChecklist({
    required String routeId,
    required String unit,
    required String type,
    required Map<String, dynamic> data,
    required String observations,
  }) async {
    final token = await storage.getToken();
    final uri = Uri.parse('$baseUrl/api/seloasa/checklist/guardar');

    final res = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'routeId': routeId,
        'unit': unit,
        'type': type,
        'data': data,
        'observations': observations,
      }),
    );

    return res.statusCode == 200;
  }
}
