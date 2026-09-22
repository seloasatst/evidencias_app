import 'dart:async';
import 'package:geolocator/geolocator.dart';

class FakeGpsException implements Exception {
  final String message;
  FakeGpsException(this.message);
  @override
  String toString() => message;
}

class LocationResult {
  final double latitude;
  final double longitude;
  final bool isMocked;

  LocationResult({
    required this.latitude,
    required this.longitude,
    required this.isMocked,
  });
}

class LocationService {
  static Future<LocationResult> getCurrentRealLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
      const Duration(seconds: 3),
      onTimeout: () => true,
    );
    if (!serviceEnabled) {
      throw Exception('Los servicios de ubicación (GPS) están desactivados. Por favor actívalos.');
    }

    permission = await Geolocator.checkPermission().timeout(
      const Duration(seconds: 3),
      onTimeout: () => LocationPermission.denied,
    );
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Los permisos de ubicación fueron denegados.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Los permisos de ubicación están denegados permanentemente. Actívalos en los ajustes del dispositivo.',
      );
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
    } catch (_) {
      position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
    }

    if (position.isMocked) {
      throw FakeGpsException(
        '¡ATENCIÓN SEGURIDAD!\nSe ha detectado una ubicación falsa o FakeGPS activa en el dispositivo. '
        'Por regla de la empresa, no está permitido usar aplicaciones de simulación de GPS.',
      );
    }

    return LocationResult(
      latitude: position.latitude,
      longitude: position.longitude,
      isMocked: false,
    );
  }
}
