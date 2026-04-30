import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_api_config.dart';
import '../../../core/services/widget_service.dart';
import '../../auth/data/token_storage.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/route_models.dart';
import '../data/route_service.dart';

String _normalizeEvidenceUserRole(String? rawRole) {
  final role = (rawRole ?? '').trim().toUpperCase();

  switch (role) {
    case 'OP':
    case 'OPERADOR':
      return 'OPERADOR';
    case 'GESTOR':
    case 'GST':
      return 'GESTOR';
    default:
      return 'OPERADOR';
  }
}

final routeServiceProvider = Provider((ref) {
  return RouteService(
    baseUrl: AppApiConfig.evidenciasBaseUrl,
    storage: TokenStorage(),
  );
});

final pendingRoutesProvider = FutureProvider<List<RouteModel>>((ref) async {
  final authState = ref.watch(authStateProvider);
  final service = ref.watch(routeServiceProvider);
  final user = authState.user;
  final userCode = (user?.username?.isNotEmpty ?? false) ? user!.username : user?.code;
  final userRole = _normalizeEvidenceUserRole(user?.type);

  if (userCode == null || userCode.isEmpty) {
    WidgetService.updateRouteInfo(null);
    return [];
  }

  final routes = await service.getPendingRoutes(
    userCode: userCode,
    userRole: userRole,
  );

  if (routes.isNotEmpty) {
    WidgetService.updateRouteInfo(routes.first.coverage);
  } else {
    WidgetService.updateRouteInfo(null);
  }

  return routes;
});

final routeDetailProvider = FutureProvider.family<List<OrderModel>, String>((ref, guideNumber) async {
  final service = ref.watch(routeServiceProvider);
  return service.getRouteDetail(guideNumber);
});

final evidenceSubmissionProvider = StateNotifierProvider<EvidenceNotifier, AsyncValue<bool>>((ref) {
  return EvidenceNotifier(ref, ref.watch(routeServiceProvider));
});

class EvidenceNotifier extends StateNotifier<AsyncValue<bool>> {
  final Ref _ref;
  final RouteService _service;

  EvidenceNotifier(this._ref, this._service) : super(const AsyncValue.data(false));

  Future<bool> submit({
    required String routeId,
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
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(authStateProvider).user;
      final userCode = (user?.username?.isNotEmpty ?? false) ? user!.username : (user?.code ?? '');

      final success = await _service.sendEvidence(
        routeId: routeId,
        orderId: os,
        userCode: userCode,
        os: os,
        result: result,
        quantity: quantity,
        observations: observations,
        timestamp: timestamp,
        photoPath: photoPath,
        photoBase64: photoBase64,
        photoBytes: photoBytes,
        photoFileName: photoFileName,
      );
      state = AsyncValue.data(success);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
