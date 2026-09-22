import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../data/models/attendance_record.dart';
import '../data/services/network_time_service.dart';
import '../utils/time_utils.dart';
import '../../../../ui/theme/app_colors.dart';
import 'camera_checkin_screen.dart';
import 'providers/checador_providers.dart';
import 'widgets/glass_container.dart';

class ChecadorHomeScreen extends ConsumerStatefulWidget {
  const ChecadorHomeScreen({super.key});

  @override
  ConsumerState<ChecadorHomeScreen> createState() => _ChecadorHomeScreenState();
}

class _ChecadorHomeScreenState extends ConsumerState<ChecadorHomeScreen> {
  late Timer _clockTimer;
  DateTime _now = NetworkTimeService.getRealTime();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = NetworkTimeService.getRealTime();
        });
      }
    });
  }

  Future<void> _syncGoogleTime() async {
    final serverTime = await NetworkTimeService.fetchGoogleCentralMexicoTime();
    if (mounted) {
      setState(() {
        _now = serverTime;
      });
    }
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  void _openCameraCheckin(AttendanceType type) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CameraCheckinScreen(type: type),
      ),
    );
    if (result == true) {
      ref.read(checadorProvider.notifier).loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checadorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final timeString = DateFormat('hh:mm:ss a').format(_now);
    final dateString = DateFormat('EEEE, d MMMM yyyy', 'es_MX').format(_now);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          await _syncGoogleTime();
          await ref.read(checadorProvider.notifier).loadData();
        },
        color: AppColors.emerald,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Reloj Digital
              GlassContainer(
                padding: const EdgeInsets.all(20),
                borderRadius: 22,
                backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time_filled_rounded, color: AppColors.accentOrange, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          timeString,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateString.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentOrange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Banner de descanso de comida si aplica
              if (state.isOnMealBreak) _buildMealTimerBanner(state.mealRemainingTime),

              // Recomendación de justificante si aplica
              if (state.recommendation != null) _buildRecommendationBanner(state.recommendation!),

              const SizedBox(height: 8),

              // Tarjetas de Fichaje
              _buildStepCard(
                title: '1. Entrada Laboral',
                subtitle: 'Horario oficial: 8:00 AM (15 min tolerancia)',
                icon: Icons.login_rounded,
                type: AttendanceType.entrada,
                isRegistered: state.hasEntrada,
                records: state.todayRecords,
                isEnabled: !state.hasEntrada,
              ),
              const SizedBox(height: 12),

              _buildStepCard(
                title: '2. Inicio de Comida',
                subtitle: 'Duración permitida: 1 Hora',
                icon: Icons.restaurant_rounded,
                type: AttendanceType.inicioComida,
                isRegistered: state.hasInicioComida,
                records: state.todayRecords,
                isEnabled: state.hasEntrada && !state.hasInicioComida,
              ),
              const SizedBox(height: 12),

              _buildStepCard(
                title: '3. Regreso de Comida',
                subtitle: 'Registro al finalizar la comida',
                icon: Icons.set_meal_rounded,
                type: AttendanceType.finComida,
                isRegistered: state.hasFinComida,
                records: state.todayRecords,
                isEnabled: state.hasInicioComida && !state.hasFinComida,
              ),
              const SizedBox(height: 12),

              _buildStepCard(
                title: '4. Salida Laboral',
                subtitle: 'Finalización de la jornada diaria',
                icon: Icons.logout_rounded,
                type: AttendanceType.salida,
                isRegistered: state.hasSalida,
                records: state.todayRecords,
                isEnabled: state.hasEntrada && (!state.hasInicioComida || state.hasFinComida) && !state.hasSalida,
              ),
              const SizedBox(height: 24),

              // Acceso directo a Historial Calendario
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text(
                  'Ver Historial en Calendario',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: () => context.push('/checador/historial'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealTimerBanner(Duration remaining) {
    final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.accentOrange.withValues(alpha: 0.4),
      backgroundColor: AppColors.accentOrange.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.timer_rounded, color: AppColors.accentOrange, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tiempo Restante de Comida',
                  style: TextStyle(color: AppColors.accentOrange, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  '$minutes:$seconds min',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationBanner(JustificationRecommendation rec) {
    if (rec.recommendedRecord == null && !rec.hasUsedQuincenaQuota) return const SizedBox.shrink();

    final used = rec.hasUsedQuincenaQuota;
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      borderColor: used ? Colors.redAccent.withValues(alpha: 0.4) : Colors.amber.withValues(alpha: 0.4),
      backgroundColor: used ? Colors.red.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            used ? Icons.lock_rounded : Icons.auto_awesome_rounded,
            color: used ? Colors.redAccent : Colors.amber,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              rec.message,
              style: const TextStyle(fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required AttendanceType type,
    required bool isRegistered,
    required List<AttendanceRecord> records,
    required bool isEnabled,
  }) {
    final matching = records.where((r) => r.type == type).toList();
    final record = matching.isNotEmpty ? matching.first : null;

    Color badgeColor = Colors.grey;
    String badgeLabel = 'Pendiente';

    if (isRegistered && record != null) {
      if (record.status == 'PUNTUAL') {
        badgeColor = AppColors.emerald;
        badgeLabel = 'Puntual (${TimeUtils.formatTime(record.timestamp)})';
      } else if (record.status == 'RETARDO_1') {
        badgeColor = Colors.orangeAccent;
        badgeLabel = 'Retardo 1 (${TimeUtils.formatTime(record.timestamp)})';
      } else if (record.status == 'RETARDO_2') {
        badgeColor = Colors.redAccent;
        badgeLabel = 'Retardo 2 (${TimeUtils.formatTime(record.timestamp)})';
      } else if (record.isOvertime) {
        badgeColor = Colors.purpleAccent;
        badgeLabel = 'Hora Extra (${TimeUtils.formatTime(record.timestamp)})';
      } else {
        badgeColor = AppColors.emerald;
        badgeLabel = 'Registrado (${TimeUtils.formatTime(record.timestamp)})';
      }
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isRegistered ? badgeColor.withValues(alpha: 0.2) : Colors.black12,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isRegistered ? badgeColor : Colors.grey, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isRegistered)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isEnabled ? AppColors.emerald : Colors.grey.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isEnabled ? () => _openCameraCheckin(type) : null,
              child: const Text('Fichar', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          else
            const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 28),
        ],
      ),
    );
  }
}
