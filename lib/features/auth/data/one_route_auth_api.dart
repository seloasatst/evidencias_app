import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_api_config.dart';

class OneRouteAuthApi {
  static Future<Map<String, dynamic>> login({
    required String user,
    required String password,
  }) async {
    final uri = Uri.parse('${AppApiConfig.authBaseUrl}/auth/login');

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'user': user,
        'password': password,
      }),
    );

    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Respuesta invalida del servidor (${res.statusCode}).');
    }

    if (res.statusCode != 200 || json['success'] != true) {
      final msg = (json['message'] ?? 'Login fallido').toString();
      throw Exception(msg);
    }

    return json;
  }
}
