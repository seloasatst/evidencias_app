import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/attendance_record.dart';
import '../utils/time_utils.dart';
import '../../../../ui/theme/app_colors.dart';
import 'providers/checador_providers.dart';
import 'widgets/glass_container.dart';
import 'widgets/record_details_dialog.dart';

class ChecadorHistoryScreen extends ConsumerStatefulWidget {
  const ChecadorHistoryScreen({super.key});

  @override
  ConsumerState<ChecadorHistoryScreen> createState() => _ChecadorHistoryScreenState();
}

class _ChecadorHistoryScreenState extends ConsumerState<ChecadorHistoryScreen> {
  late DateTime _selectedDay;
  late DateTime _focusedMonth;

  final List<String> _monthNames = const [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  final List<String> _weekDays = const ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _focusedMonth = DateTime(now.year, now.month, 1);
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Map<String, List<AttendanceRecord>> _groupRecordsByDate(List<AttendanceRecord> records) {
    final Map<String, List<AttendanceRecord>> map = {};
    for (var r in records) {
      final key = _dateKey(r.timestamp);
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDay = DateTime(now.year, now.month, now.day);
      _focusedMonth = DateTime(now.year, now.month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checadorProvider);
    final allRecords = state.allHistory;
    final groupedRecords = _groupRecordsByDate(allRecords);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.emerald))
          : _buildCalendarView(groupedRecords),
    );
  }

  // ==========================================
  // VISTA CALENDARIO
  // ==========================================
  Widget _buildCalendarView(Map<String, List<AttendanceRecord>> groupedRecords) {
    final selectedKey = _dateKey(_selectedDay);
    final dayRecords = groupedRecords[selectedKey] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 22,
            child: Column(
              children: [
                // Cabecera del Mes y Flechas de Navegación
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: AppColors.accentOrange),
                      onPressed: _previousMonth,
                    ),
                    Text(
                      '${_monthNames[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _goToToday,
                          child: const Text('HOY', style: TextStyle(color: AppColors.accentOrange, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, color: AppColors.accentOrange),
                          onPressed: _nextMonth,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Días de la Semana (Lun, Mar, Mié...)
                Row(
                  children: _weekDays.map((day) {
                    return Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),

                // Cuadrícula de Días del Mes
                _buildMonthGrid(groupedRecords),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Título de la fecha seleccionada
          Text(
            'Registros del ${TimeUtils.formatDate(_selectedDay)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          // Registros del día seleccionado
          if (dayRecords.isEmpty)
            GlassContainer(
              padding: const EdgeInsets.all(24),
              borderRadius: 18,
              child: const Center(
                child: Text(
                  'No hay asistencias registradas para esta fecha.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dayRecords.length,
              itemBuilder: (context, index) {
                return _buildRecordCard(dayRecords[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(Map<String, List<AttendanceRecord>> groupedRecords) {
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startingWeekday = firstDayOfMonth.weekday; // 1 = Lunes, 7 = Domingo

    final List<Widget> dayWidgets = [];

    // Celdas vacías antes del día 1
    for (int i = 1; i < startingWeekday; i++) {
      dayWidgets.add(const SizedBox.shrink());
    }

    // Días reales del mes
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final key = _dateKey(date);
      final records = groupedRecords[key] ?? [];
      final isSelected = date.year == _selectedDay.year &&
          date.month == _selectedDay.month &&
          date.day == _selectedDay.day;
      final isToday = date.year == DateTime.now().year &&
          date.month == DateTime.now().month &&
          date.day == DateTime.now().day;

      Color? dotColor;
      if (records.isNotEmpty) {
        if (records.any((r) => r.status == 'RETARDO_2')) {
          dotColor = Colors.redAccent;
        } else if (records.any((r) => r.status == 'RETARDO_1')) {
          dotColor = Colors.orangeAccent;
        } else if (records.any((r) => r.isOvertime)) {
          dotColor = Colors.purpleAccent;
        } else {
          dotColor = AppColors.emerald;
        }
      }

      dayWidgets.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedDay = date;
            });
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.emerald.withValues(alpha: 0.3)
                  : (isToday ? AppColors.accentOrange.withValues(alpha: 0.15) : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.emerald
                    : (isToday ? AppColors.accentOrange : Colors.transparent),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                if (dotColor != null)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: dayWidgets,
    );
  }

  Widget _buildRecordCard(AttendanceRecord record) {
    Color badgeColor = Colors.grey;
    String badgeText = record.status;

    if (record.status == 'PUNTUAL') {
      badgeColor = AppColors.emerald;
      badgeText = 'Puntual';
    } else if (record.status == 'RETARDO_1') {
      badgeColor = Colors.orangeAccent;
      badgeText = 'Retardo 1 (Medio Día)';
    } else if (record.status == 'RETARDO_2') {
      badgeColor = Colors.redAccent;
      badgeText = 'Retardo 2 (Día Completo)';
    } else if (record.isOvertime) {
      badgeColor = Colors.purpleAccent;
      badgeText = 'Hora Extra';
    } else if (record.status == 'NORMAL') {
      badgeColor = AppColors.emerald;
      badgeText = 'Normal';
    }

    final photoFile = File(record.photoPath);

    return GestureDetector(
      onTap: () => RecordDetailsDialog.show(context, record),
      child: GlassContainer(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        borderColor: badgeColor.withValues(alpha: 0.3),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: photoFile.existsSync()
                  ? Image.file(photoFile, width: 56, height: 56, fit: BoxFit.cover)
                  : Container(
                      width: 56,
                      height: 56,
                      color: Colors.black12,
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.grey),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(record.type.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${TimeUtils.formatDate(record.timestamp)} - ${TimeUtils.formatTime(record.timestamp, includeSeconds: true)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'GPS: ${record.latitude.toStringAsFixed(4)}, ${record.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
