import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthApi {
  final String baseUrl;
  final http.Client _client;
  final bool _disposeClient;

  AuthApi({required this.baseUrl, http.Client? client}) 
      : _client = client ?? http.Client(),
        _disposeClient = client == null;

  Future<Map<String, dynamic>> login(String user, String pass) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('--- 🚀 INICIANDO LOGIN: $uri ---');
      
      final res = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'user': user, 'password': pass}),
      ).timeout(const Duration(seconds: 60));

      stopwatch.stop();
      debugPrint('--- ✅ LOGIN RECIBIDO EN ${stopwatch.elapsed.inMilliseconds}ms (Status: ${res.statusCode}) ---');

      final body = res.body.isNotEmpty ? jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true)) : {};

      if (res.statusCode == 200 && body['success'] == true) {
        final userData = body['user'];
        if (userData == null) throw Exception('La respuesta no contiene datos de usuario.');
        
        debugPrint('--- 👤 USUARIO OBTENIDO: ${userData['name']} (Code: ${userData['code']}) ---');
        debugPrint('--- 📦 PAYLOAD COMPLETO: ${jsonEncode(userData)} ---');
        
        return Map<String, dynamic>.from(body);
      } else {
        final msg = (body is Map && body['message'] != null)
            ? body['message'].toString()
            : 'Error de autenticación (${res.statusCode}).';
        debugPrint('--- ❌ ERROR LOGIN: $msg ---');
        throw Exception(msg);
      }
    } catch (e) {
      stopwatch.stop();
      debugPrint('--- 🔥 EXCEPCIÓN LOGIN TRAS ${stopwatch.elapsed.inMilliseconds}ms: $e ---');
      if (e is Exception) rethrow;
      throw Exception('Error de conexión: $e');
    }
  }

  void dispose() {
    if (_disposeClient) {
      _client.close();
    }
  }
}
