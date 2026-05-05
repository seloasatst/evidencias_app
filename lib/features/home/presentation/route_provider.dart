import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_api_config.dart';
import '../../../core/services/widget_service.dart';
import '../../auth/data/token_storage.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/route_models.dart';
import '../data/route_service.dart';

String _normalizeEvidenceUserRole(AuthUser? user) {
  if (user == null) return 'OP';
  final role = (user.type ?? '').trim().toUpperCase();
  final username = (user.username).trim().toLowerCase();

  // 1. ADMINISTRATIVOS (Miran @GUIDE0)
  if (role == 'AD2' || role == 'AD' || username == 'mdamian') return 'AD';
  
  // 2. GESTORES (Miran @FENV1)
  if (role == 'GE' || username == 'lburola') return 'GE';
  
  // 3. OPERADORES
  if (role == 'OP') return 'OP';

  return 'OP';
}

final routeServiceProvider = Provider((ref) {
  return RouteService(
    baseUrl: AppApiConfig.evidenciasBaseUrl,
    storage: TokenStorage(),
  );
});

final pendingRoutesProvider = StateNotifierProvider<PendingRoutesNotifier, AsyncValue<List<RouteModel>>>((ref) {
  return PendingRoutesNotifier(ref);
});

class PendingRoutesNotifier extends StateNotifier<AsyncValue<List<RouteModel>>> {
  final Ref _ref;
  int _currentPage = 1;
  bool _hasMore = true;
  int _totalCount = 0;
  final List<RouteModel> _allRoutes = [];

  PendingRoutesNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadInitial();
  }

  bool get hasMore => _hasMore;
  int get totalCount => _totalCount;

  Future<void> loadInitial() async {
    _currentPage = 1;
    _allRoutes.clear();
    _totalCount = 0;
    _hasMore = true;
    await loadMore();
  }

  Future<void> loadMore() async {
    if (!_hasMore && _currentPage > 1) return;

    final authState = _ref.read(authStateProvider);
    final service = _ref.read(routeServiceProvider);
    final user = authState.user;
    final userCode = (user?.username.isNotEmpty ?? false) ? user!.username : user?.code;
    final userRole = _normalizeEvidenceUserRole(user);

    if (userCode == null || userCode.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    final now = DateTime.now();
    final startDt = DateTime(now.year - 1, 12, 1);
    final startDateStr = DateFormat('yyyy-MM-dd').format(startDt);

    try {
      if (userRole == 'AD') {
        final response = await service.getAdminRoutes(
          userCode: userCode,
          startDate: startDateStr,
          page: _currentPage,
          pageSize: 10,
        );
        
        final newRoutes = response.routes;
        _totalCount = response.totalCount;

        if (newRoutes.isEmpty) {
          _hasMore = false;
        } else {
          _allRoutes.addAll(newRoutes);
          _currentPage++;
          if (_allRoutes.length >= _totalCount) _hasMore = false;
        }
      } else {
        final List<RouteModel> newRoutes = await service.getPendingRoutes(
          userCode: userCode,
          userRole: userRole,
          startDate: startDateStr,
        );
        _allRoutes.addAll(newRoutes);
        _totalCount = _allRoutes.length;
        _hasMore = false; 
      }

      if (_allRoutes.isNotEmpty) {
        WidgetService.updateRouteInfo(_allRoutes.first.coverage);
      }

      state = AsyncValue.data(List.from(_allRoutes));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

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
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
