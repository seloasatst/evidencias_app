import '../data/models/attendance_record.dart';

class EntryEvaluation {
  final String status; // PUNTUAL, RETARDO_1, RETARDO_2
  final int minutesLate;
  final String statusDescription;
  final String penaltyDescription;

  EntryEvaluation({
    required this.status,
    required this.minutesLate,
    required this.statusDescription,
    required this.penaltyDescription,
  });
}

class JustificationRecommendation {
  final AttendanceRecord? recommendedRecord;
  final bool hasUsedQuincenaQuota;
  final AttendanceRecord? alreadyJustifiedRecord;
  final String message;

  JustificationRecommendation({
    this.recommendedRecord,
    required this.hasUsedQuincenaQuota,
    this.alreadyJustifiedRecord,
    required this.message,
  });
}

class TimeUtils {
  // Evaluador de Horario de Entrada
  static EntryEvaluation evaluateEntryTime(DateTime timestamp) {
    final localTime = timestamp.isUtc
        ? DateTime(timestamp.year, timestamp.month, timestamp.day, timestamp.hour, timestamp.minute, timestamp.second, timestamp.millisecond)
        : timestamp;

    // Hora de inicio oficial: 8:00 AM
    final officialStart = DateTime(
      localTime.year,
      localTime.month,
      localTime.day,
      8,
      0,
      0,
    );

    // Caso A: Llegada antes de las 8:00 AM o hasta las 8:15:59 AM (PUNTUAL - Tolerancia de 15 min)
    final isPuntual = localTime.hour < 8 || (localTime.hour == 8 && localTime.minute <= 15);
    if (isPuntual) {
      return EntryEvaluation(
        status: 'PUNTUAL',
        minutesLate: 0,
        statusDescription: 'Llegada Puntual',
        penaltyDescription: 'Sin sanción',
      );
    }

    final diffSeconds = localTime.difference(officialStart).inSeconds;
    final diffMinutes = (diffSeconds / 60).ceil();

    // Caso B: Llegada entre las 8:16:00 AM y las 8:30:59 AM (Retardo 1 - Medio Día)
    final isRetardo1 = localTime.hour == 8 && localTime.minute <= 30;
    if (isRetardo1) {
      return EntryEvaluation(
        status: 'RETARDO_1',
        minutesLate: diffMinutes,
        statusDescription: 'Retardo Nivel 1',
        penaltyDescription: 'Descuento de Medio Día',
      );
    }

    // Caso C: Llegada a partir de las 8:31:00 AM (Retardo 2 - Día Completo)
    return EntryEvaluation(
      status: 'RETARDO_2',
      minutesLate: diffMinutes,
      statusDescription: 'Retardo Nivel 2',
      penaltyDescription: 'Descuento de Día Completo',
    );
  }

  // Elegibilidad para Horas Extras (salida después de las 7:00 PM)
  static bool isEligibleForOvertime(DateTime timestamp) {
    final localTime = timestamp.isUtc
        ? DateTime(timestamp.year, timestamp.month, timestamp.day, timestamp.hour, timestamp.minute, timestamp.second, timestamp.millisecond)
        : timestamp;

    final cutoff = DateTime(
      localTime.year,
      localTime.month,
      localTime.day,
      19,
      0,
      0,
    );
    return localTime.isAfter(cutoff);
  }

  static String getQuincenaKey(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final q = date.day <= 15 ? 'Q1' : 'Q2';
    return '$year-$month-$q';
  }

  static JustificationRecommendation analyzeQuincenaJustifications(
    List<AttendanceRecord> quincenaRecords,
  ) {
    final alreadyJustified = quincenaRecords.where((r) => r.isJustified).toList();

    if (alreadyJustified.isNotEmpty) {
      final used = alreadyJustified.first;
      return JustificationRecommendation(
        hasUsedQuincenaQuota: true,
        alreadyJustifiedRecord: used,
        message: 'Ya has utilizado la única justificación permitida para esta quincena '
            '(Se justificó el registro del ${formatDate(used.timestamp)}).',
      );
    }

    final pendingRetardos = quincenaRecords
        .where((r) => !r.isJustified && (r.status == 'RETARDO_1' || r.status == 'RETARDO_2'))
        .toList();

    if (pendingRetardos.isEmpty) {
      return JustificationRecommendation(
        hasUsedQuincenaQuota: false,
        message: '¡Excelente! No tienes retardos pendientes por justificar en esta quincena.',
      );
    }

    pendingRetardos.sort((a, b) {
      if (a.status == 'RETARDO_2' && b.status != 'RETARDO_2') return -1;
      if (b.status == 'RETARDO_2' && a.status != 'RETARDO_2') return 1;
      return b.retardoMinutes.compareTo(a.retardoMinutes);
    });

    final recommended = pendingRetardos.first;
    final penaltyText = recommended.status == 'RETARDO_2'
        ? 'Descuento de Día Completo'
        : 'Descuento de Medio Día';

    return JustificationRecommendation(
      recommendedRecord: recommended,
      hasUsedQuincenaQuota: false,
      message: 'Se recomienda justificar el retardo del ${formatDate(recommended.timestamp)} '
          '(${recommended.retardoMinutes} min tarde) ya que presenta la mayor sanción ($penaltyText).',
    );
  }

  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String formatTime(DateTime date, {bool includeSeconds = false}) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    if (includeSeconds) {
      final second = date.second.toString().padLeft(2, '0');
      return '$hour:$minute:$second hrs';
    }
    return '$hour:$minute hrs';
  }
}
