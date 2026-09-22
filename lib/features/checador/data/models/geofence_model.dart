import 'dart:convert';

class GeofenceModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  const GeofenceModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  // Geocerca oficial SELOASA LERMA
  static const seloasaLermaGeofence = GeofenceModel(
    id: '1',
    name: 'SELOASA LERMA',
latitude: 19.298064,
    longitude: -99.545327,
    radiusMeters: 300.0,
  );

  // Geocerca base operativa general
  static const defaultCompanyGeofence = GeofenceModel(
    id: 'seloasa_hq',
    name: 'SELOASA Base Operativa',
    latitude: 19.432608,
    longitude: -99.133209,
    radiusMeters: 500.0,
  );

  static const List<GeofenceModel> defaultGeofences = [
    seloasaLermaGeofence,
    defaultCompanyGeofence,
  ];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
    };
  }

  String toJson() => jsonEncode(toMap());

  factory GeofenceModel.fromJson(String source) =>
      GeofenceModel.fromMap(jsonDecode(source) as Map<String, dynamic>);

  /// Factory para respuesta del backend Laravel (/api/seloasa/checador/geocercas)
  factory GeofenceModel.fromApiMap(Map<String, dynamic> map) {
    return GeofenceModel(
      id: map['id']?.toString() ?? 'default',
      name: map['nombre'] as String? ?? map['name'] as String? ?? 'Zona Autorizada',
      latitude: (map['latitud'] as num? ?? map['latitude'] as num? ?? 0).toDouble(),
      longitude: (map['longitud'] as num? ?? map['longitude'] as num? ?? 0).toDouble(),
      radiusMeters: (map['radio_metros'] as num? ?? map['radius_meters'] as num? ?? 500.0).toDouble(),
    );
  }

  /// Factory legacy para compatibilidad con datos locales guardados
  factory GeofenceModel.fromMap(Map<String, dynamic> map) {
    return GeofenceModel(
      id: map['id']?.toString() ?? 'default',
      name: map['name'] as String? ?? map['nombre'] as String? ?? 'Base Operativa',
      latitude: (map['latitude'] as num? ?? map['latitud'] as num? ?? 0).toDouble(),
      longitude: (map['longitude'] as num? ?? map['longitud'] as num? ?? 0).toDouble(),
      radiusMeters: (map['radius_meters'] as num? ?? map['radiusMeters'] as num? ?? map['radio_metros'] as num? ?? 500.0).toDouble(),
    );
  }
}
