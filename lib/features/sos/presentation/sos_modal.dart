import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../ui/theme/app_colors.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../notifications/presentation/notification_inbox_provider.dart';
import '../data/sos_service.dart';

class SosModal extends ConsumerStatefulWidget {
  const SosModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SosModal(),
    );
  }

  @override
  ConsumerState<SosModal> createState() => _SosModalState();
}

class _SosModalState extends ConsumerState<SosModal> {
  final SosService _sosService = SosService();
  final TextEditingController _noteController = TextEditingController();

  String _selectedEmergency = 'Accidente';
  bool _isSending = false;
  bool _isFetchingLocation = true;
  double? _currentLat;
  double? _currentLng;
  int? _batteryLevel;

  final List<Map<String, dynamic>> _emergencyTypes = [
    {
      'id': 'Accidente',
      'label': 'Accidente',
      'icon': Icons.car_crash_outlined,
    },
    {
      'id': 'Seguridad / Riesgo',
      'label': 'Seguridad / Riesgo',
      'icon': Icons.security_outlined,
    },
    {
      'id': 'Falla Mecanica',
      'label': 'Falla Mecánica',
      'icon': Icons.build_outlined,
    },
    {
      'id': 'Medica',
      'label': 'Médica',
      'icon': Icons.local_hospital_outlined,
    },
    {
      'id': 'Prueba',
      'label': 'Prueba de Sistema',
      'icon': Icons.tune_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadTelemetry();
  }

  Future<void> _loadTelemetry() async {
    setState(() => _isFetchingLocation = true);
    final pos = await _sosService.getCurrentLocation();
    final batt = await _sosService.getBatteryLevel();

    if (mounted) {
      setState(() {
        _currentLat = pos?.latitude;
        _currentLng = pos?.longitude;
        _batteryLevel = batt;
        _isFetchingLocation = false;
      });
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _triggerSos({bool isTest = false}) async {
    final authState = ref.read(authStateProvider);
    final userCode = authState.user?.code.isNotEmpty == true
        ? authState.user!.code
        : (authState.user?.username ?? authState.user?.name ?? 'OPERADOR');

    final bool testMode = isTest || _selectedEmergency == 'Prueba';

    setState(() => _isSending = true);

    try {
      final result = await _sosService.sendSosAlert(
        emergencyType: testMode ? 'Prueba de Telemétricos' : _selectedEmergency,
        userCode: userCode,
        note: _noteController.text.trim(),
        isTest: testMode,
      );

      // Recargar lista de notificaciones locales
      ref.read(notificationInboxProvider.notifier).loadNotifications();

      if (!mounted) return;

      Navigator.pop(context);

      _showSuccessDialog(result, isTest: testMode);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar alerta: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSuccessDialog(SosPayloadResult result, {bool isTest = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Theme.of(ctx).cardColor,
        title: Row(
          children: [
            Icon(
              isTest ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              color: isTest ? Colors.blue : Colors.red.shade700,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              isTest ? 'Prueba Enviada' : 'Alerta Transmitida',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isTest
                  ? 'Se transmitió la señal de prueba a la pantalla de Telemétricos.'
                  : 'La alerta ha sido registrada y transmitida a la cabina de monitoreo.',
              style: GoogleFonts.poppins(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GPS: ${result.latitude != null ? "${result.latitude!.toStringAsFixed(5)}, ${result.longitude!.toStringAsFixed(5)}" : "No disponible"}',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Batería: ${result.batteryLevel ?? "--"}%',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!isTest)
            TextButton.icon(
              onPressed: () => _callEmergency('tel:911'),
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
              icon: const Icon(Icons.phone, size: 16),
              label: const Text('Llamar 911'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: isTest ? Colors.blue.shade700 : AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _callEmergency(String telUrl) async {
    final uri = Uri.parse(telUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Indicador superior
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Encabezado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alerta de Emergencia',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Transmisión directa a Telemétricos',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Telemetría de Ubicación y Batería
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF262626) : const Color(0xFFF5F6F8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _currentLat != null ? Icons.my_location : Icons.location_searching,
                    color: _currentLat != null ? AppColors.primaryGreen : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isFetchingLocation
                          ? 'Obteniendo GPS...'
                          : (_currentLat != null
                              ? '${_currentLat!.toStringAsFixed(4)}, ${_currentLng!.toStringAsFixed(4)}'
                              : 'GPS no disponible'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    height: 18,
                    width: 1,
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  Icon(
                    Icons.battery_std_rounded,
                    color: (_batteryLevel ?? 100) > 20 ? AppColors.primaryGreen : Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _batteryLevel != null ? '$_batteryLevel%' : '--',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Tipo de Evento:',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Opciones de tipo de emergencia sin emojis
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emergencyTypes.map((t) {
                final isSelected = _selectedEmergency == t['id'];

                return InkWell(
                  onTap: () => setState(() => _selectedEmergency = t['id']),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? Colors.red.shade900.withValues(alpha: 0.3) : const Color(0xFFFFECEC))
                          : (isDark ? const Color(0xFF262626) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? Colors.red.shade700 : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          t['icon'] as IconData,
                          size: 16,
                          color: isSelected
                              ? Colors.red.shade700
                              : (isDark ? Colors.white60 : Colors.grey.shade700),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          t['label'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? (isDark ? Colors.white : Colors.red.shade800)
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 14),

            // Nota breve opcional
            TextField(
              controller: _noteController,
              maxLines: 2,
              style: GoogleFonts.poppins(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Detalle o referencia opcional...',
                hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                filled: true,
                fillColor: isDark ? const Color(0xFF262626) : Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.red.shade700),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Botón Principal SOS
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSending ? null : () => _triggerSos(isTest: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSending
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'TRANSMITIENDO...',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'ENVIAR ALERTA SOS',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 8),

            // Botones secundarios limpios
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSending ? null : () => _triggerSos(isTest: true),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      'Enviar señal de prueba',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _callEmergency('tel:911'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: Icon(Icons.phone, color: Colors.red.shade700, size: 15),
                    label: Text(
                      'Llamar 911',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
