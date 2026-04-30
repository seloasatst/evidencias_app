import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../auth/data/token_storage.dart';
import 'route_models.dart';

class RouteService {
  final String baseUrl;
  final TokenStorage storage;
  static const Duration _requestTimeout = Duration(seconds: 30);

  RouteService({required this.baseUrl, required this.storage});

  Future<http.Response> _getWithRetry(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    try {
      return await http.get(
        uri,
        headers: headers,
      ).timeout(_requestTimeout);
    } on TimeoutException catch (_) {
      return await http.get(
        uri,
        headers: headers,
      ).timeout(_requestTimeout);
    } on SocketException catch (_) {
      return await http.get(
        uri,
        headers: headers,
      ).timeout(_requestTimeout);
    }
  }

  Future<List<RouteModel>> getPendingRoutes({
    required String userCode,
    required String userRole,
  }) async {
    final token = await storage.getToken();
    final uri = Uri.parse('$baseUrl/evidencias/pendientes/$userCode').replace(
      queryParameters: {'userRole': userRole},
    );
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
            .map((j) => RouteModel.fromJson(Map<String, dynamic>.from(j)))
            .toList();
      }

      throw Exception('Error al cargar guias pendientes: ${res.statusCode}');
    } catch (e) {
      print('Error de conexion al cargar guias pendientes: $e.');
      return [];
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

      throw Exception('Error al cargar detalle de la guia: ${res.statusCode}');
    } catch (e) {
      print('Error de conexion al cargar detalle de la guia: $e.');
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
      print('Error al cargar unidades: $e');
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
    if (photoBytes != null && photoBytes.isNotEmpty) {
      photos.add({
        'fileName': (photoFileName != null && photoFileName.isNotEmpty)
            ? photoFileName
            : 'evidencia.jpg',
        'base64': base64Encode(photoBytes),
      });
    } else if (photoBase64 != null && photoBase64.isNotEmpty) {
      photos.add({
        'fileName': (photoFileName != null && photoFileName.isNotEmpty)
            ? photoFileName
            : 'evidencia.jpg',
        'base64': photoBase64,
      });
    } else if (photoPath != null && photoPath.isNotEmpty) {
      final file = File(photoPath);
      final bytes = await file.readAsBytes();
      final fileName = photoPath.split(Platform.pathSeparator).last;
      photos.add({
        'fileName': fileName,
        'base64': base64Encode(bytes),
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

    print('UPLOAD payload: ${jsonEncode(payload)}');

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

    print('UPLOAD response status: ${res.statusCode}');
    print('UPLOAD response body: ${res.body}');

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
              decoded['message']?.toString() ?? 'El servidor rechazo la evidencia.',
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
