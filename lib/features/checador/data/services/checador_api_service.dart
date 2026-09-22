import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/app_api_config.dart';
import '../models/attendance_record.dart';
import '../models/geofence_model.dart';

class ChecadorApiService {
  static const String _prefSapCodeKey = 'checador_sap_code';
  static const String _prefNombreKey = 'checador_nombre_empleado';

  static const List<String> candidateBaseUrls = [
    'http://rutas.seloasa.com.mx:2350/api/seloasa',
    'http://10.0.2.2:8000/api/seloasa',
    'http://192.168.101.6:8000/api/seloasa',
    'http://127.0.0.1:8000/api/seloasa',
  ];

  final Dio _dio;

  ChecadorApiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppApiConfig.evidenciasBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 25),
                headers: {'Accept': 'application/json'},
              ),
            );

  Future<String> getSapCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefSapCodeKey) ?? '';
  }

  Future<String> getNombreEmpleado() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefNombreKey) ?? 'Empleado';
  }

  // ---------------------------------------------------------------------------
  // GET /api/seloasa/checador/geocercas
  // ---------------------------------------------------------------------------
  Future<List<GeofenceModel>> fetchGeocercas() async {
    // 1. Probar con Dio configurado por defecto
    final direct = await _tryFetchGeocercas(_dio);
    if (direct != null && direct.isNotEmpty) return direct;

    // 2. Probar candidatos alternativos de red/emulador
    for (final url in candidateBaseUrls) {
      if (url == _dio.options.baseUrl) continue;
      try {
        final altDio = Dio(
          BaseOptions(
            baseUrl: url,
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 4),
            headers: {'Accept': 'application/json'},
          ),
        );
        final res = await _tryFetchGeocercas(altDio);
        if (res != null && res.isNotEmpty) {
          _dio.options.baseUrl = url;
          return res;
        }
      } catch (_) {}
    }

    return [];
  }

  Future<List<GeofenceModel>?> _tryFetchGeocercas(Dio client) async {
    try {
      final response = await client.get('/checador/geocercas');
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['data'] is List) {
          final list = data['data'] as List;
          return list
              .map((item) => GeofenceModel.fromApiMap(item as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}
    return null;
  }

// ---------------------------------------------------------------------------
  // POST /api/seloasa/checador/fichar
  // ---------------------------------------------------------------------------
  Future<bool> createCheckIn(AttendanceRecord record, {String? selfiePath}) async {
    try {
      final sapCode = await getSapCode();
      if (sapCode.isEmpty) {
        throw Exception(
          'No se pudo identificar el SAP code del empleado. Cierra sesión y vuelve a iniciarla para activar el checador.',
        );
      }
      final nombre = await getNombreEmpleado();

      final hasPhoto = record.photoPath.isNotEmpty && await File(record.photoPath).exists();
      final hasSelfie = selfiePath != null &&
          selfiePath.isNotEmpty &&
          await File(selfiePath).exists();

      final fields = {
        'sap_code': sapCode,
        'nombre_empleado': nombre,
        'tipo_fichaje': record.type.dbValue,
        'latitud': record.latitude.toString(),
        'longitud': record.longitude.toString(),
        'es_gps_falso': record.isMocked ? '1' : '0',
        'fecha_hora_cliente': record.timestamp.toIso8601String(),
        'notas': record.status,
      };

      final multipart = <String, dynamic>{...fields};

      if (hasPhoto) {
        multipart['foto'] = await MultipartFile.fromFile(
          record.photoPath,
          filename: 'fichaje_${sapCode}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      if (hasSelfie) {
        multipart['selfie'] = await MultipartFile.fromFile(
          selfiePath,
          filename: 'selfie_${sapCode}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      final formData = FormData.fromMap(multipart);

      late final Response response;
      try {
        response = await _dio.post(
          '/checador/fichar',
          data: formData,
          options: Options(headers: {'Content-Type': 'multipart/form-data'}),
        );
      } on DioException catch (e) {
        throw Exception(networkErrorDescription(e));
      }

      final ok = response.statusCode == 200 &&
          (response.data as Map?)?['success'] == true;

      if (!ok) {
        throw Exception(
          'El servidor rechazó el registro (HTTP ${response.statusCode}): ${response.data}',
        );
      }

      return true;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error inesperado al fichar: $e');
    }
  }

  static String networkErrorDescription(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Tiempo de espera agotado al conectar con el servidor (${e.type.name}).';
      case DioExceptionType.connectionError:
        return 'No se pudo conectar con el servidor. Verifica tu conexión a internet o que la Intranet esté disponible.';
      case DioExceptionType.badCertificate:
        return 'Certificado SSL no válido del servidor.';
      case DioExceptionType.cancel:
        return 'La solicitud fue cancelada.';
      default:
        return 'Error de red al conectar con el servidor: ${e.message ?? e.type.name}';
    }
  }

  // ---------------------------------------------------------------------------
  // GET /api/seloasa/checador/historial
  // ---------------------------------------------------------------------------
  Future<List<AttendanceRecord>?> fetchRecords({int? mes, int? anio}) async {
    try {
      final sapCode = await getSapCode();
      if (sapCode.isEmpty) return null;

      final now = DateTime.now();
      final response = await _dio.get(
        '/checador/historial',
        queryParameters: {
          'sap_code': sapCode,
          'mes': (mes ?? now.month).toString(),
          'anio': (anio ?? now.year).toString(),
        },
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['data'] is List) {
          final list = data['data'] as List;
          return list
              .map((item) => AttendanceRecord.fromApiMap(item as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------------------
  // POST /api/seloasa/checador/justificar
  // ---------------------------------------------------------------------------
  Future<bool> sendJustification({
    required int? recordId,
    required String reason,
    String? evidenciaPath,
  }) async {
    try {
      final sapCode = await getSapCode();
      if (sapCode.isEmpty) return false;

      final hasEvidencia = evidenciaPath != null &&
          evidenciaPath.isNotEmpty &&
          await File(evidenciaPath).exists();

      final fields = <String, dynamic>{
        'sap_code': sapCode,
        'motivo': reason,
        if (recordId != null) 'registro_id': recordId.toString(),
      };

      FormData formData;
      if (hasEvidencia) {
        formData = FormData.fromMap({
          ...fields,
          'evidencia': await MultipartFile.fromFile(
            evidenciaPath,
            filename: 'justificante_${sapCode}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        });
      } else {
        formData = FormData.fromMap(fields);
      }

      final response = await _dio.post(
        '/checador/justificar',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );
      return response.statusCode == 200 && (response.data as Map?)?['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
