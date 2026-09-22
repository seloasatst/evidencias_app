import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/attendance_record.dart';
import '../../utils/time_utils.dart';
import '../../../../ui/theme/app_colors.dart';
import 'glass_container.dart';

class RecordDetailsDialog extends StatelessWidget {
  final AttendanceRecord record;

  const RecordDetailsDialog({super.key, required this.record});

  static void show(BuildContext context, AttendanceRecord record) {
    showDialog(
      context: context,
      builder: (context) => RecordDetailsDialog(record: record),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoFile = File(record.photoPath);

    Color statusColor = Colors.grey;
    String statusLabel = record.status;

    if (record.status == 'PUNTUAL') {
      statusColor = AppColors.emerald;
      statusLabel = 'Puntual';
    } else if (record.status == 'RETARDO_1') {
      statusColor = Colors.orangeAccent;
      statusLabel = 'Retardo 1 (Medio Día)';
    } else if (record.status == 'RETARDO_2') {
      statusColor = Colors.redAccent;
      statusLabel = 'Retardo 2 (Día Completo)';
    } else if (record.isOvertime) {
      statusColor = Colors.purpleAccent;
      statusLabel = 'Hora Extra';
    } else if (record.status == 'NORMAL') {
      statusColor = AppColors.emerald;
      statusLabel = 'Normal';
    }

    final dateStr = TimeUtils.formatDate(record.timestamp);
    final timeStr = TimeUtils.formatTime(record.timestamp, includeSeconds: true);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2622),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Encabezado
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.verified_rounded, color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${record.type.label} ($statusLabel)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$dateStr - $timeStr',
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),

            // Contenido
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Evidencia fotográfica
                    const Text(
                      'Evidencia Fotográfica',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: photoFile.existsSync()
                          ? Image.file(
                              photoFile,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              height: 140,
                              width: double.infinity,
                              color: Colors.white10,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image_rounded, color: Colors.white38, size: 40),
                                  SizedBox(height: 6),
                                  Text(
                                    'Imagen no disponible localmente',
                                    style: TextStyle(color: Colors.white38, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 18),

                    // Detalles
                    GlassContainer(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 16,
                      backgroundColor: Colors.white.withValues(alpha: 0.04),
                      borderColor: Colors.white12,
                      child: Column(
                        children: [
                          _buildDetailRow(
                            icon: Icons.access_time_filled_rounded,
                            iconColor: AppColors.accentOrange,
                            title: 'Hora Registrada',
                            subtitle: timeStr,
                          ),
                          const Divider(color: Colors.white10, height: 16),
                          _buildDetailRow(
                            icon: Icons.location_on_rounded,
                            iconColor: Colors.redAccent,
                            title: 'Coordenadas GPS',
                            subtitle: '${record.latitude.toStringAsFixed(6)}, ${record.longitude.toStringAsFixed(6)}',
                            trailing: TextButton.icon(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: '${record.latitude},${record.longitude}'),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Coordenadas copiadas')),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 14, color: AppColors.accentOrange),
                              label: const Text('Copiar', style: TextStyle(color: AppColors.accentOrange, fontSize: 11)),
                            ),
                          ),
                          if (record.retardoMinutes > 0) ...[
                            const Divider(color: Colors.white10, height: 16),
                            _buildDetailRow(
                              icon: Icons.timer_off_rounded,
                              iconColor: Colors.orangeAccent,
                              title: 'Retardo',
                              subtitle: '${record.retardoMinutes} min tarde',
                            ),
                          ],
                          if (record.isJustified) ...[
                            const Divider(color: Colors.white10, height: 16),
                            _buildDetailRow(
                              icon: Icons.fact_check_rounded,
                              iconColor: AppColors.accentOrange,
                              title: 'Justificación',
                              subtitle: record.justificationReason ?? 'Aprobada',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}
