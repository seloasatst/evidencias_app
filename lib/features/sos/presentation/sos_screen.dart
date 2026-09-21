import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../ui/theme/app_colors.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../notifications/presentation/notification_inbox_provider.dart';
import '../data/sos_service.dart';

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> with SingleTickerProviderStateMixin {
  final SosService _sosService = SosService();
  final TextEditingController _noteController = TextEditingController();

  String _selectedEmergency = 'Accidente';
  bool _isSending = false;
  bool _isFetchingLocation = true;
  double? _currentLat;
  double? _currentLng;
  int? _batteryLevel;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Map<String, dynamic>> _emergencyTypes = [
    {
      'id': 'Accidente',
      'label': 'Accidente',
      'icon': Icons.car_crash_outlined,
      'color': const Color(0xFFE53935),
    },
    {
      'id': 'Seguridad / Riesgo',
      'label': 'Seguridad / Riesgo',
      'icon': Icons.security_outlined,
      'color': const Color(0xFFFF5722),
    },
    {
      'id': 'Falla Mecanica',
      'label': 'Falla Mecánica',
      'icon': Icons.build_outlined,
      'color': const Color(0xFFFFB300),
    },
    {
      'id': 'Medica',
      'label': 'Médica',
      'icon': Icons.local_hospital_outlined,
      'color': const Color(0xFF00E676),
    },
    {
      'id': 'Prueba',
      'label': 'Prueba de Sistema',
      'icon': Icons.tune_rounded,
      'color': const Color(0xFF29B6F6),
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

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
    _pulseController.dispose();
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

      ref.read(notificationInboxProvider.notifier).loadNotifications();

      if (!mounted) return;
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
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(ctx).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        title: Row(
          children: [
            Icon(
              isTest ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              color: isTest ? Colors.blue : Colors.red.shade700,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              isTest ? 'Prueba Transmitida' : '¡Alerta S.O.S Enviada!',
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
                  ? 'Se transmitió la señal de prueba a la pantalla de Telemétricos exitosamente.'
                  : 'La alerta crítica ha sido registrada y transmitida inmediatamente a la cabina de monitoreo y telemétricos con tu ubicación exacta.',
              style: GoogleFonts.poppins(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).brightness == Brightness.dark
                    ? Colors.white10
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Estado: ${result.message}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  if (result.latitude != null && result.longitude != null) ...[
                    const SizedBox(height: 4),
                    Text("Coordenadas: ${result.latitude!.toStringAsFixed(5)}, ${result.longitude!.toStringAsFixed(5)}",
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                  if (result.batteryLevel != null) ...[
                    const SizedBox(height: 4),
                    Text("Batería: ${result.batteryLevel}%",
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
            child: const Text('ENTENDIDO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _makeCall(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0606) : const Color(0xFFFFF7F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white70 : Colors.black87),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          "BOTÓN DE PÁNICO S.O.S",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.redAccent.shade700,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // Banner de estado en vivo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "TRANSMISIÓN INMEDIATA A CABINA DE MONITOREO 24/7",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.redAccent.shade700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Botón central de pánico palpitante
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTap: _isSending ? null : () => _triggerSos(),
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFFFF1744),
                          Color(0xFFD50000),
                          Color(0xFF8A0000),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.5),
                          blurRadius: 32,
                          spreadRadius: 6,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8),
                        width: 4,
                      ),
                    ),
                    child: Center(
                      child: _isSending
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.emergency_rounded,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "S.O.S",
                                  style: GoogleFonts.poppins(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                  ),
                                ),
                                Text(
                                  "PULSAR AQUÍ",
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Toca el botón central para disparar la alerta de emergencia.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),

            // Telemetría en tiempo real
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1010) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Row(
                    children: [
                      Icon(Icons.my_location_rounded,
                          color: _isFetchingLocation ? Colors.orange : Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("GPS",
                              style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                          Text(
                            _isFetchingLocation
                                ? "Adquiriendo..."
                                : "${_currentLat?.toStringAsFixed(4)}, ${_currentLng?.toStringAsFixed(4)}",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(height: 30, width: 1, color: isDark ? Colors.white12 : Colors.black12),
                  Row(
                    children: [
                      Icon(Icons.battery_charging_full_rounded,
                          color: (_batteryLevel ?? 100) < 20 ? Colors.red : Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Batería",
                              style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                          Text(
                            _batteryLevel != null ? "$_batteryLevel%" : "--",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Selección de tipo de emergencia
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Tipo de Emergencia:",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emergencyTypes.map((type) {
                final isSelected = _selectedEmergency == type['id'];
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(type['icon'] as IconData,
                          size: 16, color: isSelected ? Colors.white : (type['color'] as Color)),
                      const SizedBox(width: 6),
                      Text(type['label'] as String),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: Colors.redAccent.shade700,
                  backgroundColor: isDark ? const Color(0xFF221111) : Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedEmergency = type['id']);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Campo de nota opcional
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "Nota adicional (opcional, ej. km 45 carretera...)",
                hintStyle: const TextStyle(fontSize: 12),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1010) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Botones de llamada rápida de auxilio
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _makeCall("911"),
                    icon: const Icon(Icons.call_rounded, color: Colors.redAccent),
                    label: Text(
                      "LLAMAR 911",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSending ? null : () => _triggerSos(),
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    label: Text(
                      "TRANSMITIR",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
