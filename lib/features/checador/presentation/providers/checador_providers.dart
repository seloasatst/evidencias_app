import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/attendance_record.dart';
import '../../data/services/checador_api_service.dart';
import '../../data/services/checador_db_service.dart';
import '../../data/services/network_time_service.dart';
import '../../utils/time_utils.dart';

class ChecadorState {
  final List<AttendanceRecord> todayRecords;
  final List<AttendanceRecord> quincenaRecords;
  final List<AttendanceRecord> allHistory;
  final JustificationRecommendation? recommendation;
  final DateTime? activeMealStartTime;
  final Duration mealRemainingTime;
  final bool isLoading;
  final String? errorMessage;

  ChecadorState({
    this.todayRecords = const [],
    this.quincenaRecords = const [],
    this.allHistory = const [],
    this.recommendation,
    this.activeMealStartTime,
    this.mealRemainingTime = Duration.zero,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get hasEntrada => todayRecords.any((r) => r.type == AttendanceType.entrada);
  bool get hasInicioComida => todayRecords.any((r) => r.type == AttendanceType.inicioComida);
  bool get hasFinComida => todayRecords.any((r) => r.type == AttendanceType.finComida);
  bool get hasSalida => todayRecords.any((r) => r.type == AttendanceType.salida);
  bool get isOnMealBreak => hasInicioComida && !hasFinComida;

  ChecadorState copyWith({
    List<AttendanceRecord>? todayRecords,
    List<AttendanceRecord>? quincenaRecords,
    List<AttendanceRecord>? allHistory,
    JustificationRecommendation? recommendation,
    DateTime? activeMealStartTime,
    Duration? mealRemainingTime,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ChecadorState(
      todayRecords: todayRecords ?? this.todayRecords,
      quincenaRecords: quincenaRecords ?? this.quincenaRecords,
      allHistory: allHistory ?? this.allHistory,
      recommendation: recommendation ?? this.recommendation,
      activeMealStartTime: activeMealStartTime ?? this.activeMealStartTime,
      mealRemainingTime: mealRemainingTime ?? this.mealRemainingTime,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ChecadorNotifier extends StateNotifier<ChecadorState> {
  final ChecadorApiService _apiService = ChecadorApiService();
  Timer? _mealTimer;

  ChecadorNotifier() : super(ChecadorState()) {
    loadData();
  }

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await NetworkTimeService.fetchGoogleCentralMexicoTime();
      final db = ChecadorDbService.instance;
      await db.purgeDuplicateRecords();

      // Intentar cargar desde API real; fallback a SQLite local
      final apiRecords = await _apiService.fetchRecords();
      final now = DateTime.now();

      List<AttendanceRecord> today;
      List<AttendanceRecord> quincena;
      List<AttendanceRecord> all;

      if (apiRecords != null && apiRecords.isNotEmpty) {
        all = apiRecords;
        today = apiRecords.where((r) {
          return r.timestamp.year == now.year &&
              r.timestamp.month == now.month &&
              r.timestamp.day == now.day;
        }).toList();
        quincena = await db.getRecordsForQuincena(NetworkTimeService.getRealTime());
      } else {
        today = await db.getTodayRecords();
        quincena = await db.getRecordsForQuincena(NetworkTimeService.getRealTime());
        all = await db.getAllRecords();
      }

      final recommendation = TimeUtils.analyzeQuincenaJustifications(quincena);

      final mealStartRecords = today.where((r) => r.type == AttendanceType.inicioComida).toList();
      final hasFin = today.any((r) => r.type == AttendanceType.finComida);

      DateTime? mealStart;
      if (mealStartRecords.isNotEmpty && !hasFin) {
        mealStart = mealStartRecords.first.timestamp;
        _startMealTimer(mealStart);
      } else {
        _stopMealTimer();
      }

      state = state.copyWith(
        todayRecords: today,
        quincenaRecords: quincena,
        allHistory: all,
        recommendation: recommendation,
        activeMealStartTime: mealStart,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al cargar datos de asistencia: $e',
      );
    }
  }

  void _startMealTimer(DateTime start) {
    _mealTimer?.cancel();
    _updateMealRemaining(start);
    _mealTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateMealRemaining(start);
    });
  }

  void _updateMealRemaining(DateTime start) {
    final endMeal = start.add(const Duration(hours: 1));
    final realNow = NetworkTimeService.getRealTime();
    final diff = endMeal.difference(realNow);
    state = state.copyWith(
      mealRemainingTime: diff.isNegative ? Duration.zero : diff,
    );
  }

  void _stopMealTimer() {
    _mealTimer?.cancel();
    _mealTimer = null;
    state = state.copyWith(mealRemainingTime: Duration.zero);
  }

Future<void> saveCheckIn({
    required AttendanceType type,
    required String photoPath,
    String? selfiePath,
    required double latitude,
    required double longitude,
    required bool isMocked,
    required bool isOvertimeSelected,
    String? overtimeReason,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final realNow = NetworkTimeService.getRealTime();
      String status = 'NORMAL';
      int retardoMinutes = 0;

      if (type == AttendanceType.entrada) {
        final eval = TimeUtils.evaluateEntryTime(realNow);
        status = eval.status;
        retardoMinutes = eval.minutesLate;
      } else if (type == AttendanceType.salida) {
        if (isOvertimeSelected && TimeUtils.isEligibleForOvertime(realNow)) {
          status = 'HORA_EXTRA';
        } else {
          status = 'NORMAL';
        }
      }

      final record = AttendanceRecord(
        type: type,
        timestamp: realNow,
        photoPath: photoPath,
        latitude: latitude,
        longitude: longitude,
        isMocked: isMocked,
        status: status,
        retardoMinutes: retardoMinutes,
        isOvertime: isOvertimeSelected && TimeUtils.isEligibleForOvertime(realNow),
        overtimeReason: overtimeReason,
      );

// Único camino de persistencia: la API de la Intranet (SAP HANA vía APIs).
      // No se inserta localmente desde la app.
      await _apiService.createCheckIn(record, selfiePath: selfiePath);

      await loadData();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al registrar asistencia: $e',
      );
      rethrow;
    }
  }

  @override
  void dispose() {
    _mealTimer?.cancel();
    super.dispose();
  }
}

final checadorProvider =
    StateNotifierProvider<ChecadorNotifier, ChecadorState>((ref) {
  return ChecadorNotifier();
});

