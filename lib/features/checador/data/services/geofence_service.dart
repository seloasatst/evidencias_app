import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/geofence_model.dart';
import 'checador_api_service.dart';

class GeofenceCheckResult {
  final bool isInside;
  final bool isEnforced;
  final String nearestGeofenceName;
  final double distanceMeters;
  final double allowedRadiusMeters;
  final String message;

  GeofenceCheckResult({
    required this.isInside,
    required this.isEnforced,
    required this.nearestGeofenceName,
    required this.distanceMeters,
    required this.allowedRadiusMeters,
    required this.message,
  });
}

class GeofenceService {
  static const String _prefEnforcedKey = 'app_geofence_enforced_v1';
  static const String _prefLocalGeofencesKey = 'app_local_geofences_list_v1';
  static List<GeofenceModel>? _cachedGeofences;
  static bool _hasRealGeofences = false;

  static Future<bool> isGeofenceEnforced() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefEnforcedKey) ?? true;
  }

  static Future<void> setGeofenceEnforced(bool enforced) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnforcedKey, enforced);
  }

  static Future<List<GeofenceModel>> getLocalGeofences() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_prefLocalGeofencesKey);
    if (jsonList == null || jsonList.isEmpty) return [];
    try {
      return jsonList.map((item) => GeofenceModel.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveLocalGeofence(GeofenceModel model) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getLocalGeofences();
    final idx = current.indexWhere((g) => g.id == model.id);
    if (idx != -1) {
      current[idx] = model;
    } else {
      current.add(model);
    }
    final jsonList = current.map((g) => g.toJson()).toList();
    await prefs.setStringList(_prefLocalGeofencesKey, jsonList);
    _cachedGeofences = current;
  }

/// Carga las geocercas activas:
  /// 1. Intenta desde el servidor o fallback de red local.
  /// 2. Si no responde, consulta el caché guardado.
  /// 3. Fallback con geocercas oficiales precargadas (incluye SELOASA LERMA).
  static Future<List<GeofenceModel>> loadGeofences() async {
    if (_cachedGeofences != null && _cachedGeofences!.isNotEmpty) {
      return _cachedGeofences!;
    }
    try {
      final apiService = ChecadorApiService();
      final remote = await apiService.fetchGeocercas();
      if (remote.isNotEmpty) {
        _cachedGeofences = remote;
        _hasRealGeofences = true;
        return remote;
      }
    } catch (_) {}

    final local = await getLocalGeofences();
    if (local.isNotEmpty) {
      _cachedGeofences = local;
      _hasRealGeofences = true;
      return local;
    }

    _cachedGeofences = GeofenceModel.defaultGeofences;
    _hasRealGeofences = false;
    return GeofenceModel.defaultGeofences;
  }

  static void clearCache() {
    _cachedGeofences = null;
    _hasRealGeofences = false;
  }

  /// Valida si el usuario está dentro de alguna geocerca activa
  static Future<GeofenceCheckResult> validateLocation({
    required double userLatitude,
    required double userLongitude,
    List<GeofenceModel>? geofences,
  }) async {
    final enforced = await isGeofenceEnforced();
    final activeGeofences = geofences ?? await loadGeofences();

    final hasData =
        (geofences != null && geofences.isNotEmpty) || _hasRealGeofences;

    // Sin geocercas reales del servidor no se penaliza la ubicación:
    // el registro siempre está permitido y se almacenan las coordenadas.
    if (!hasData) {
      return GeofenceCheckResult(
        isInside: true,
        isEnforced: false,
        nearestGeofenceName: 'Zona Libre',
        distanceMeters: 0,
        allowedRadiusMeters: 500,
        message: 'Ubicación autorizada (validación sin datos del servidor).',
      );
    }

    if (!enforced) {
      return GeofenceCheckResult(
        isInside: true,
        isEnforced: false,
        nearestGeofenceName: 'Zona Libre',
        distanceMeters: 0,
        allowedRadiusMeters: 500,
        message: 'Ubicación autorizada (Validación desactivada).',
      );
    }

    GeofenceModel? nearest;
    double nearestDistance = double.infinity;

    for (final g in activeGeofences) {
      final distance = Geolocator.distanceBetween(
        userLatitude,
        userLongitude,
        g.latitude,
        g.longitude,
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = g;
      }

      if (distance <= g.radiusMeters) {
        return GeofenceCheckResult(
          isInside: true,
          isEnforced: true,
          nearestGeofenceName: g.name,
          distanceMeters: distance,
          allowedRadiusMeters: g.radiusMeters,
          message: 'Dentro de ${g.name} (${distance.round()}m del centro).',
        );
      }
    }

    final ref = nearest ?? GeofenceModel.seloasaLermaGeofence;
    return GeofenceCheckResult(
      isInside: false,
      isEnforced: true,
      nearestGeofenceName: ref.name,
      distanceMeters: nearestDistance,
      allowedRadiusMeters: ref.radiusMeters,
      message: '¡FUERA DE GEOCERCA!\n'
          'Estás a ${nearestDistance.round()} metros de "${ref.name}" '
          '(Radio permitido: ${ref.radiusMeters.round()} metros).\n'
          'Debes encontrarte en las instalaciones autorizadas.',
    );
  }
}
