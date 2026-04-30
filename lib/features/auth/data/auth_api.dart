import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthApi {
  final String baseUrl;
  AuthApi({required this.baseUrl});

  Future<Map<String, dynamic>> login(String user, String pass) async {
    final uri = Uri.parse('$baseUrl/auth/login');

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'user': user, 'password': pass}),
    );

    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};

    if (res.statusCode != 200) {
      final msg = (body is Map && body['message'] != null)
          ? body['message'].toString()
          : 'Error de autenticación.';
      throw Exception(msg); // ✅ aquí viaja "Usuario inactivo." o "Credenciales inválidas."
    }

    return Map<String, dynamic>.from(body);
  }
}
