import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../auth/data/token_storage.dart';
import '../../home/data/route_models.dart';

class PaqueteriaService {
  final String baseUrl;
  final TokenStorage storage;

  PaqueteriaService({required this.baseUrl, required this.storage});

  Future<List<RouteModel>> getGuiasGestor(String userCode) async {
    final token = await storage.getToken();
    final uri = Uri.parse('$baseUrl/paqueteria/guias/$userCode');
    
    // Imprimimos la URL en consola para depuración
    print('DEBUG: Consultando Paquetería en: $uri');
    
    try {
      final res = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final List jsonList = jsonDecode(res.body);
        return jsonList.map((j) => RouteModel.fromJson(Map<String, dynamic>.from(j))).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
