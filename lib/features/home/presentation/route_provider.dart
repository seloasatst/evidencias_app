import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_api_config.dart';
import '../../../core/services/widget_service.dart';
import '../../auth/data/token_storage.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../../core/network/http_client_provider.dart';
import '../data/route_models.dart';
import '../data/route_service.dart';

// 🚀 Nuevo objeto de estado para evitar errores de sincronización
class PendingRoutesState {
  final AsyncValue<List<RouteModel>> routes;
  final int totalCount;
  final int inProgressCount;

  PendingRoutesState({
    required this.routes,
    required this.totalCount,
    this.inProgressCount = 0,
  });

  PendingRoutesState copyWith({
    AsyncValue<List<RouteModel>>? routes,
    int? totalCount,
    int? inProgressCount,
  }) {
    return PendingRoutesState(
      routes: routes ?? this.routes,
      totalCount: totalCount ?? this.totalCount,
      inProgressCount: inProgressCount ?? this.inProgressCount,
    );
  }
}

String normalizeEvidenceUserRole(AuthUser? user) {
  if (user == null) return 'OP';
  final role = (user.type ?? '').trim().toUpperCase();
  final username = (user.username).trim().toLowerCase();

  // 1. ADMINISTRATIVOS (Miran @GUIDE0)
  if (role == 'AD2' || role == 'AD' || role == 'ADMIN' || username == 'mdamian') return 'AD';
  
  // 2. GESTORES (Miran @FENV1)
  if (role == 'GE' || role == 'GESTOR' || role == 'GST' || username == 'lburola') return 'GE';
  
  // 3. OPERADORES
  if (role == 'OP' || role == 'OPERADOR') return 'OP';

  return role.isNotEmpty ? role : 'OP';
}

final routeServiceProvider = Provider((ref) {
  final httpClient = ref.watch(httpClientProvider);
  return RouteService(
    baseUrl: AppApiConfig.evidenciasBaseUrl,
    storage: TokenStorage(),
    client: httpClient,
  );
});

final pendingRoutesProvider = StateNotifierProvider<PendingRoutesNotifier, PendingRoutesState>((ref) {
  final authState = ref.watch(authStateProvider);
  final service = ref.read(routeServiceProvider);
  final storage = ref.read(tokenStorageProvider);
  
  final notifier = PendingRoutesNotifier(
    service: service,
    storage: storage,
    user: authState.user,
    ref: ref,
  );

  // 🚀 Carga inicial automática al crear el provider
  Future.microtask(() => notifier.loadInitial());

  return notifier;
});

class PendingRoutesNotifier extends StateNotifier<PendingRoutesState> {
  final RouteService _service;
  final TokenStorage _tokenStorage;
  final AuthUser? _user;
  final Ref _ref;

  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final List<RouteModel> _allRoutes = [];

  PendingRoutesNotifier({
    required RouteService service,
    required TokenStorage storage,
    required AuthUser? user,
    required Ref ref,
  }) : _service = service,
       _tokenStorage = storage,
       _user = user,
       _ref = ref,
       super(PendingRoutesState(routes: const AsyncValue.loading(), totalCount: 0));

  @override
  void dispose() {
    super.dispose();
  }

  // Helper para evitar actualizar estado si el notifier ya no existe
  void _safeSetState(PendingRoutesState newState) {
    if (mounted) {
      state = newState;
    }
  }

  bool get hasMore => _hasMore;
  int get totalCount => state.totalCount;

  Future<void> loadInitial({bool force = false}) async {
    if (!mounted) return;
    
    // Si ya estamos cargando o tenemos datos, evitamos el parpadeo
    if (_isLoadingMore) return;
    if (!force && _allRoutes.isNotEmpty && _currentPage == 1) return;

    _currentPage = 1;
    _allRoutes.clear();
    _hasMore = true;
    _isLoadingMore = false; // Reset por seguridad
    
    if (mounted) {
      state = state.copyWith(
        routes: const AsyncValue.loading(),
        totalCount: 0,
      );
    }
    
    await loadMore();
  }


  Future<void> loadMore() async {
    if (!mounted) return;
    if (_isLoadingMore || (!_hasMore && _currentPage > 1)) return;
    _isLoadingMore = true;

    final user = _user;
    final userCode = (user?.username.isNotEmpty ?? false) ? user!.username : (user?.code ?? '');
    final userRole = normalizeEvidenceUserRole(user);

    if (userCode.isEmpty) {
      if (mounted) {
        state = state.copyWith(
          routes: const AsyncValue.data([]),
          totalCount: 0,
          inProgressCount: 0,
        );
      }
      _isLoadingMore = false;
      return;
    }

    // Filtro desde diciembre 2025 solicitado por el usuario
    const String startDateStr = '2025-12-01';

    try {
      final RoutePaginatedResponse response;

      if (userRole == 'AD') {
        response = await _service.getAdminRoutes(
          userCode: userCode,
          startDate: startDateStr,
          page: _currentPage,
          pageSize: 15,
        );
      } else {
        response = await _service.getPendingRoutes(
          userCode: userCode,
          userRole: userRole,
          startDate: startDateStr,
          page: _currentPage,
          pageSize: 15,
          includeCount: false, // 🚀 OPTIMIZACIÓN: Nunca bloqueamos la carga de datos por el conteo
        );
      }
      
      // 🚀 FILTRADO QUIRÚRGICO: Si es OPERADOR, removemos las rutas de PAQUETERIA
      // según lo solicitado ("que operadores no tuvieran rutas [de paqueteria]")
      final newRoutes = response.routes.where((r) {
        final isPaqueteria = r.type.toUpperCase().contains('PAQUETERIA') || 
                             r.id.toUpperCase().startsWith('PQG');

        if (userRole == 'OP' && isPaqueteria) {
          debugPrint('--- 🚫 FILTRADO: Saltando guía ${r.id} (Tipo: ${r.type}) por ser de PAQUETERIA para OPERADOR ---');
          return false;
        }
        return true;
      }).toList();

      if (newRoutes.isEmpty) {
        _hasMore = false;
      } else {
        // 🚀 DE-DUPLICACIÓN: Solo añadimos las que no estén ya (ej: por caché)
        for (var route in newRoutes) {
          if (!_allRoutes.any((existing) => existing.id == route.id)) {
            _allRoutes.add(route);
          }
        }
        _currentPage++;
        // Si recibimos menos de 10 guías, es que ya no hay más páginas
        if (newRoutes.length < 10) {
          _hasMore = false;
        }
      }

      if (_allRoutes.isNotEmpty) {
        _updateStateWithRoutes();
      } else {
        if (mounted) {
          state = state.copyWith(
            routes: const AsyncValue.data([]),
            totalCount: 0,
            inProgressCount: 0,
          );
        }
      }
    } catch (e, stack) {
      if (mounted) {
        state = state.copyWith(routes: AsyncValue.error(e, stack));
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  // Centralizamos la actualización del estado y el cálculo de contadores
  void _updateStateWithRoutes({int totalFromServer = -1}) {
    if (!mounted) return;
    
    final inProgress = _allRoutes.where((r) => r.operatorPackages > 0).length;
    
    state = state.copyWith(
      routes: AsyncValue.data(List.from(_allRoutes)),
      inProgressCount: inProgress,
      totalCount: _allRoutes.length, // El conteo ahora se basa en las tarjetas cargadas
    );
  }

  // 🚀 Función para guardar caché sin bloquear
  Future<void> _saveCacheInBackground(List<RouteModel> routes) async {
    try {
      final String jsonToCache = await compute(_encodeJson, routes);
      await _tokenStorage.save('cached_routes', jsonToCache);
    } catch (e) {
      debugPrint('Error guardando caché: $e');
    }
  }
}

// Provider para obtener solo las estadísticas del Dashboard (Independiente para evitar lentitud)
// Eliminamos el provider redundante para evitar doble carga
final pendingCountProvider = Provider<String>((ref) {
  final routesState = ref.watch(pendingRoutesProvider);
  return routesState.totalCount.toString();
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
      final userCode = (user?.username.isNotEmpty ?? false) ? user!.username : (user?.code ?? '');

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
      if (success) {
        // Forzamos la recarga de las rutas para actualizar la lista y el contador del dashboard
        _ref.invalidate(pendingRoutesProvider);
      }
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

// Funciones auxiliares para el procesamiento en segundo plano (Isolates)
List<RouteModel> _parseCachedRoutesIsolate(String json) {
  final List decoded = jsonDecode(json);
  return decoded.map((j) => RouteModel.fromJson(Map<String, dynamic>.from(j))).toList();
}

String _encodeJson(List<RouteModel> data) => jsonEncode(data.map((r) => r.toJson()).toList());
