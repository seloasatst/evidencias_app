import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_api_config.dart';
import '../../auth/data/token_storage.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../home/data/route_models.dart';
import '../../home/presentation/route_provider.dart';
import '../data/paqueteria_service.dart';

final paqueteriaServiceProvider = Provider((ref) {
  return PaqueteriaService(
    baseUrl: AppApiConfig.evidenciasBaseUrl,
    storage: TokenStorage(),
  );
});

final guiasPaqueteriaProvider = FutureProvider<List<RouteModel>>((ref) async {
  final user = ref.watch(authStateProvider).user;
  if (user == null) return [];
  
  final service = ref.watch(routeServiceProvider);
  final userCode = user.username.isNotEmpty ? user.username : user.code;
  
  // Llamamos al servicio estándar pero forzando el rol de GESTOR
  return service.getPendingRoutes(
    userCode: userCode,
    userRole: 'GESTOR',
  );
});
