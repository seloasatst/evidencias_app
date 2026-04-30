import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/config/app_api_config.dart';
import '../../auth/data/token_storage.dart';

class IncidentService {
  final String baseUrl;
  final TokenStorage storage;
  static const Duration _requestTimeout = Duration(seconds: 30);

  IncidentService({
    this.baseUrl = '',
    TokenStorage? storage,
  }) : storage = storage ?? TokenStorage();

  Future<void> sendIncident({
    required String tipo,
    required String comentarios,
    required String userCode,
    required DateTime fecha,
    Uint8List? photoBytes,
    String? photoFileName,
  }) async {
    final token = await storage.getToken();
    final uri = Uri.parse('${baseUrl.isEmpty ? AppApiConfig.evidenciasBaseUrl : baseUrl}/incidencias');
    final photos = <Map<String, dynamic>>[];

    if (photoBytes != null && photoBytes.isNotEmpty) {
      final base64Photo = base64Encode(photoBytes);
      final fileName = (photoFileName != null && photoFileName.isNotEmpty)
          ? photoFileName
          : 'incidencia.jpg';

      // 1. Subir foto directamente al portal de Seloasa
      try {
        await http.post(
          Uri.parse('https://rutas.seloasa.com.mx/seloasa/subida-imagen'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'ordenServicio': 'INC_$userCode',
            'imagen64': base64Photo,
          }),
        ).timeout(const Duration(seconds: 15));
      } catch (e) {
        print('Error al subir foto al portal: $e');
        // Continuamos de todos modos, el backend ahora ignora si la subida falló aquí
      }

      photos.add({
        'fileName': fileName,
        'base64': base64Photo,
      });
    }

    final payload = {
      'tipo': tipo,
      'comentarios': comentarios,
      'userCode': userCode,
      'fecha': fecha.toIso8601String(),
      'photos': photos,
    };

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(_requestTimeout);

    final body = response.body.trim();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body.isEmpty
            ? 'Error al enviar incidencia (${response.statusCode}).'
            : 'Error al enviar incidencia (${response.statusCode}): $body',
      );
    }

    if (body.isEmpty) return;

    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      decoded = null;
    }

    if (decoded is Map<String, dynamic> && decoded['success'] == false) {
      throw Exception(decoded['message']?.toString() ?? 'La API rechazo la incidencia.');
    }
  }
}
