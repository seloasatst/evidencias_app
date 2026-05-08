import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 🚀 Proveedor de cliente HTTP compartido para reutilizar conexiones SSL (Keep-Alive)
// Esto evita que cada petición tenga que repetir el handshake SSL de 20 segundos.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  
  // Nos aseguramos de cerrar el cliente cuando el provider se destruya (raro en este caso)
  ref.onDispose(() {
    client.close();
  });
  
  return client;
});
