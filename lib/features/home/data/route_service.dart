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
  static const Duration _requestTimeout = Duration(seconds: 120);

  RouteService({required this.baseUrl, required this.storage});

  void _log(String message) {
    debugPrint(message);
  }

  Future<http.Response> _getWithRetry(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    try {
      return await http.get(
        uri,
        headers: headers,
      ).timeout(_requestTimeout);
    } on TimeoutException catch (e) {
      debugPrint('--- ERROR: TIMEOUT DEL SERVIDOR (120s) ---');
      rethrow;
    } on SocketException catch (e) {
      debugPrint('--- ERROR DE CONEXIÓN: Servidor no alcanzable (${e.message}) ---');
      rethrow;
    } catch (e) {
      debugPrint('--- ERROR INESPERADO: $e ---');
      rethrow;
    }
  }

  Future<List<RouteModel>> getPendingRoutes({
    required String userCode,
    required String userRole,
    String? startDate,
  }) async {
    final token = await storage.getToken();
    final queryParams = {
      'userRole': userRole,
      if (startDate != null) 'startDate': startDate,
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
      debugPrint('--- INICIANDO PETICIÓN API ---');
      debugPrint('URL: $uri');

      final res = await _getWithRetry(uri, headers: headers);
      
      debugPrint('ESTADO: ${res.statusCode}');
      debugPrint('RESPUESTA: ${res.body}');
      debugPrint('-----------------------------');

      if (res.statusCode == 200) {
        final body = res.body.isNotEmpty ? jsonDecode(res.body) : [];
        final List jsonList = body is List
            ? body
            : (body is Map<String, dynamic> && body['data'] is List)
                ? body['data'] as List
                : [];
        return jsonList
            .map((j) => RouteModel.fromJson(Map<String, dynamic>.from(j)))
            .toList();
      }

      throw Exception('Error al cargar guías pendientes: ${res.statusCode}');
    } catch (e) {
      _log('Error de conexión al cargar guías pendientes: $e.');
      return [];
    }
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
        final Map<String, dynamic> json = jsonDecode(res.body);
        final List data = json['data'] ?? [];
        final total = json['totalCount'] ?? 0;
        
        final routes = data.map((j) => RouteModel.fromJson(Map<String, dynamic>.from(j))).toList();
        return RoutePaginatedResponse(routes: routes, totalCount: total);
      }
      return RoutePaginatedResponse(routes: [], totalCount: 0);
    } catch (e) {
      debugPrint('Error en getAdminRoutes: $e');
      return RoutePaginatedResponse(routes: [], totalCount: 0);
    }
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

        return jsonList
            .map((j) => OrderModel.fromJson({
                  ...Map<String, dynamic>.from(j),
                  if ((j as Map)['numGuia'] == null) 'numGuia': numGuia,
                }))
            .toList();
      }

      throw Exception('Error al cargar detalle de la guía: ${res.statusCode}');
    } catch (e) {
      _log('Error de conexión al cargar detalle de la guía: $e.');
      return [];
    }
  }

  Future<List<String>> getUnits() async {
    final token = await storage.getToken();
    final uri = Uri.parse('$baseUrl/unidades');

    try {
      final res = await http.get(
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
        await http.post(
          Uri.parse('https://rutas.seloasa.com.mx/seloasa/subida-imagen'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'ordenServicio': orderId,
            'imagen64': currentBase64,
          }),
        ).timeout(const Duration(seconds: 15));
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
      'personaRecibe': '',
      'folioConfirmacion': '',
      'quantity': quantityValue,
      'comments': observations,
      'fechaEntrega': timestamp,
      'userCode': userCode,
      'photos': photos,
    };

    final res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(_requestTimeout);

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

    final res = await http.post(
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
