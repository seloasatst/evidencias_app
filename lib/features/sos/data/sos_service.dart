import 'dart:convert';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/app_api_config.dart';
import '../../auth/data/token_storage.dart';
import '../../notifications/data/notification_inbox_service.dart';
import '../../notifications/domain/notification_item.dart';

class SosPayloadResult {
  final bool success;
  final String message;
  final double? latitude;
  final double? longitude;
  final int? batteryLevel;

  const SosPayloadResult({
    required this.success,
    required this.message,
    this.latitude,
    this.longitude,
    this.batteryLevel,
  });
}

class SosService {
  final TokenStorage _storage;
  final Battery _battery = Battery();

  SosService({TokenStorage? storage}) : _storage = storage ?? TokenStorage();

  /// Obtiene la posición GPS con alta precisión
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Servicio de ubicación desactivado');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Permisos de ubicación denegados');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Permisos de ubicación denegados permanentemente');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Error obteniendo ubicación GPS: $e');
      return null;
    }
  }

  /// Obtiene el nivel de batería del dispositivo (0 a 100)
  Future<int?> getBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (e) {
      debugPrint('Error obteniendo nivel de batería: $e');
      return null;
    }
  }

  /// Envía la alerta SOS crítica o de prueba al servidor de Seloasa / Intranet
  Future<SosPayloadResult> sendSosAlert({
    required String emergencyType,
    required String userCode,
    String? note,
    bool isTest = false,
  }) async {
    // 1. Obtener datos de telemetría en paralelo
    final locationFuture = getCurrentLocation();
    final batteryFuture = getBatteryLevel();

    final results = await Future.wait([locationFuture, batteryFuture]);
    final position = results[0] as Position?;
    final batteryLevel = results[1] as int?;

    final double? lat = position?.latitude;
    final double? lng = position?.longitude;
    final double? speedKmh = position != null ? (position.speed * 3.6) : null; // m/s a km/h
    final double? heading = position?.heading;
    final double? accuracy = position?.accuracy;

    final token = await _storage.getToken();
    final activeBaseUrl = AppApiConfig.evidenciasBaseUrl;
    final baseUri = Uri.parse(activeBaseUrl);

    // Endpoint 1: Registro general de incidencias en Seloasa
    final incidenciasUri = Uri.parse('$activeBaseUrl/incidencias');

    // Endpoint 2: Endpoint directo de telemetría Michelin para refresco instantáneo (1s)
    final telemetriaSosUri = Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.port,
      path: '/api/telemetria/sos',
    );

    final googleMapsUrl = (lat != null && lng != null)
        ? 'https://www.google.com/maps?q=$lat,$lng'
        : 'Ubicacion no disponible';

    final headerTag = isTest
        ? '[PRUEBA DE TELEMETRICOS - SIMULACION]'
        : '[ALERTA SOS - TELEMETRICOS]';

    final fullComments = [
      headerTag,
      if (isTest) 'ESTADO: SIMULACION / TEST DE MONITOREO',
      'Tipo de Emergencia: $emergencyType',
      if (note != null && note.trim().isNotEmpty) 'Nota del Operador: ${note.trim()}',
      'Operador: $userCode',
      'Bateria: ${batteryLevel != null ? "$batteryLevel%" : "Desconocida"}',
      'Coordenadas: ${lat ?? "N/A"}, ${lng ?? "N/A"}',
      'Velocidad: ${speedKmh != null ? "${speedKmh.toStringAsFixed(1)} km/h" : "0 km/h"}',
      'Precision GPS: ${accuracy != null ? "+/-${accuracy.toStringAsFixed(1)} m" : "N/A"}',
      'Rumbo: ${heading != null ? "${heading.toStringAsFixed(0)} grados" : "N/A"}',
      'Mapa: $googleMapsUrl',
      'Fecha/Hora: ${DateTime.now().toIso8601String()}',
    ].join('\n');

    final payload = {
      'tipo': isTest ? 'PRUEBA_TELEMETRICOS' : 'SOS_$emergencyType',
      'emergencyType': emergencyType,
      'comentarios': fullComments,
      'userCode': userCode,
      'operador': userCode,
      'economico': userCode,
      'fecha': DateTime.now().toIso8601String(),
      'latitude': lat,
      'longitude': lng,
      'latitud': lat,
      'longitud': lng,
      'lat': lat,
      'lng': lng,
      'velocidad': speedKmh,
      'speed': speedKmh,
      'rumbo': heading,
      'precision': accuracy,
      'batteryLevel': batteryLevel,
      'bateria': batteryLevel,
      'prioridad': isTest ? 'TEST' : 'CRITICA',
      'isSos': !isTest,
      'es_sos': !isTest,
      'es_prueba': isTest,
      'isTest': isTest,
      'modulo': 'TELEMETRICOS',
      'telemetria': {
        'latitud': lat,
        'longitud': lng,
        'lat': lat,
        'lng': lng,
        'velocidad_kmh': speedKmh,
        'bateria_porcentaje': batteryLevel,
        'precision_metros': accuracy,
        'rumbo_grados': heading,
        'es_prueba': isTest,
        'google_maps': googleMapsUrl,
      },
    };

    bool apiSuccess = false;
    String returnMessage = isTest
        ? 'Alerta de prueba enviada con éxito.'
        : 'Alerta SOS registrada.';

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    final bodyJson = jsonEncode(payload);

    try {
      // Envío concurrente a ambos endpoints para máxima velocidad y redundancia
      final req1 = http
          .post(incidenciasUri, headers: headers, body: bodyJson)
          .timeout(const Duration(seconds: 10));

      final req2 = http
          .post(telemetriaSosUri, headers: headers, body: bodyJson)
          .timeout(const Duration(seconds: 10))
          .catchError((e) {
        debugPrint('Endpoint directo /api/telemetria/sos respondió con excepción: $e');
        return http.Response('{"status":"skipped"}', 200);
      });

      final responses = await Future.wait([req1, req2]);
      final res1 = responses[0];
      final res2 = responses[1];

      if ((res1.statusCode >= 200 && res1.statusCode < 300) ||
          (res2.statusCode >= 200 && res2.statusCode < 300)) {
        apiSuccess = true;
        returnMessage = isTest
            ? 'Prueba de telemétricos enviada a la pantalla de monitoreo.'
            : 'Alerta SOS transmitida con éxito en tiempo real.';
      } else {
        returnMessage = 'Alerta registrada localmente (${res1.statusCode})';
      }
    } catch (e) {
      debugPrint('Error enviando SOS por red: $e');
      returnMessage = 'Alerta guardada localmente (Sin conexión de red directa)';
    }

    // Guardar en la bandeja local de notificaciones del dispositivo
    try {
      final inboxService = NotificationInboxService();
      await inboxService.saveNotification(
        NotificationItem(
          id: 'sos_${DateTime.now().millisecondsSinceEpoch}',
          title: isTest
              ? 'Prueba SOS Enviada ($emergencyType)'
              : 'Alerta SOS Enviada ($emergencyType)',
          body: 'Ubicacion GPS: ${lat != null ? "$lat, $lng" : "Sin GPS"}. Bateria: ${batteryLevel ?? "N/A"}%.',
          timestamp: DateTime.now(),
          type: 'sos',
          isRead: false,
          data: {
            'type': 'sos',
            'emergencyType': emergencyType,
            'isTest': isTest,
            'lat': lat,
            'lng': lng,
            'battery': batteryLevel,
          },
        ),
      );
    } catch (e) {
      debugPrint('Error guardando SOS en bandeja local: $e');
    }

    return SosPayloadResult(
      success: apiSuccess,
      message: returnMessage,
      latitude: lat,
      longitude: lng,
      batteryLevel: batteryLevel,
    );
  }
}
