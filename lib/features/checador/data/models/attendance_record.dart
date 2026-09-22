enum AttendanceType {
  entrada,
  inicioComida,
  finComida,
  salida,
}

extension AttendanceTypeExtension on AttendanceType {
  String get label {
    switch (this) {
      case AttendanceType.entrada:
        return 'Entrada';
      case AttendanceType.inicioComida:
        return 'Inicio de Comida';
      case AttendanceType.finComida:
        return 'Regreso de Comida';
      case AttendanceType.salida:
        return 'Salida';
    }
  }

  String get dbValue {
    switch (this) {
      case AttendanceType.entrada:
        return 'ENTRADA';
      case AttendanceType.inicioComida:
        return 'INICIO_COMIDA';
      case AttendanceType.finComida:
        return 'FIN_COMIDA';
      case AttendanceType.salida:
        return 'SALIDA';
    }
  }

  static AttendanceType fromDbValue(String value) {
    switch (value) {
      case 'ENTRADA':
        return AttendanceType.entrada;
      case 'INICIO_COMIDA':
        return AttendanceType.inicioComida;
      case 'FIN_COMIDA':
        return AttendanceType.finComida;
      case 'SALIDA':
        return AttendanceType.salida;
      default:
        return AttendanceType.entrada;
    }
  }
}

class AttendanceRecord {
  final int? id;
  final AttendanceType type;
  final DateTime timestamp;
  final String photoPath;
  final double latitude;
  final double longitude;
  final bool isMocked;
  final String status; // PUNTUAL, RETARDO_1, RETARDO_2, NORMAL, HORA_EXTRA
  final int retardoMinutes;
  final bool isOvertime;
  final String? overtimeReason;
  final bool isJustified;
  final String? justificationReason;
  final DateTime? justifiedAt;

  AttendanceRecord({
    this.id,
    required this.type,
    required this.timestamp,
    required this.photoPath,
    required this.latitude,
    required this.longitude,
    required this.isMocked,
    required this.status,
    this.retardoMinutes = 0,
    this.isOvertime = false,
    this.overtimeReason,
    this.isJustified = false,
    this.justificationReason,
    this.justifiedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.dbValue,
      'timestamp': timestamp.toIso8601String(),
      'photo_path': photoPath,
      'latitude': latitude,
      'longitude': longitude,
      'is_mocked': isMocked ? 1 : 0,
      'status': status,
      'retardo_minutes': retardoMinutes,
      'is_overtime': isOvertime ? 1 : 0,
      'overtime_reason': overtimeReason,
      'is_justified': isJustified ? 1 : 0,
      'justification_reason': justificationReason,
      'justified_at': justifiedAt?.toIso8601String(),
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] is int ? map['id'] as int : int.tryParse(map['id']?.toString() ?? ''),
      type: AttendanceTypeExtension.fromDbValue(map['type'] as String? ?? 'ENTRADA'),
      timestamp: DateTime.parse(map['timestamp'] as String),
      photoPath: map['photo_path'] as String? ?? map['photoPath'] as String? ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      isMocked: map['is_mocked'] == 1 || map['is_mocked'] == true || map['isMocked'] == true,
      status: map['status'] as String? ?? 'NORMAL',
      retardoMinutes: (map['retardo_minutes'] as num? ?? map['retardoMinutes'] as num? ?? 0).toInt(),
      isOvertime: map['is_overtime'] == 1 || map['is_overtime'] == true || map['isOvertime'] == true,
      overtimeReason: map['overtime_reason'] as String? ?? map['overtimeReason'] as String?,
      isJustified: map['is_justified'] == 1 || map['is_justified'] == true || map['isJustified'] == true,
      justificationReason: map['justification_reason'] as String? ?? map['justificationReason'] as String?,
      justifiedAt: map['justified_at'] != null
          ? DateTime.parse(map['justified_at'] as String)
          : (map['justifiedAt'] != null ? DateTime.parse(map['justifiedAt'] as String) : null),
    );
  }

  /// Factory para datos recibidos desde la API del backend Laravel
  factory AttendanceRecord.fromApiMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] is int ? map['id'] as int : int.tryParse(map['id']?.toString() ?? ''),
      type: AttendanceTypeExtension.fromDbValue(
          (map['tipo_fichaje'] as String? ?? map['type'] as String? ?? 'ENTRADA').toUpperCase()),
      timestamp: map['fecha_hora_servidor'] != null
          ? DateTime.tryParse(map['fecha_hora_servidor'] as String) ?? DateTime.now()
          : (map['timestamp'] != null
              ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
              : DateTime.now()),
      photoPath: map['foto_sharepoint_url'] as String? ?? map['photo_path'] as String? ?? '',
      latitude: (map['latitud'] as num? ?? map['latitude'] as num? ?? 0).toDouble(),
      longitude: (map['longitud'] as num? ?? map['longitude'] as num? ?? 0).toDouble(),
      isMocked: false,
      status: map['estatus'] as String? ?? map['status'] as String? ?? 'PUNTUAL',
      retardoMinutes: 0,
      isOvertime: (map['estatus'] as String? ?? '').toUpperCase() == 'HORA_EXTRA',
      overtimeReason: map['notas'] as String?,
      isJustified: false,
    );
  }
  AttendanceRecord copyWith({
    int? id,
    AttendanceType? type,
    DateTime? timestamp,
    String? photoPath,
    double? latitude,
    double? longitude,
    bool? isMocked,
    String? status,
    int? retardoMinutes,
    bool? isOvertime,
    String? overtimeReason,
    bool? isJustified,
    String? justificationReason,
    DateTime? justifiedAt,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      photoPath: photoPath ?? this.photoPath,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isMocked: isMocked ?? this.isMocked,
      status: status ?? this.status,
      retardoMinutes: retardoMinutes ?? this.retardoMinutes,
      isOvertime: isOvertime ?? this.isOvertime,
      overtimeReason: overtimeReason ?? this.overtimeReason,
      isJustified: isJustified ?? this.isJustified,
      justificationReason: justificationReason ?? this.justificationReason,
      justifiedAt: justifiedAt ?? this.justifiedAt,
    );
  }
}

