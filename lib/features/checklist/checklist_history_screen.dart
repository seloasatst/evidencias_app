import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seloasa_evidencias/ui/theme/app_colors.dart';

import '../home/presentation/route_provider.dart';
import 'checklist_screen.dart';

class ChecklistHistoryScreen extends ConsumerStatefulWidget {
  final String? activeRouteId;

  const ChecklistHistoryScreen({super.key, this.activeRouteId});

  @override
  ConsumerState<ChecklistHistoryScreen> createState() => _ChecklistHistoryScreenState();
}

class _ChecklistHistoryScreenState extends ConsumerState<ChecklistHistoryScreen> {
  bool _isSalidaDone = false;
  bool _isEntradaDone = false;

  @override
  Widget build(BuildContext context) {
    final routesState = ref.watch(pendingRoutesProvider);

    return routesState.routes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text("Error al cargar rutas: $e")),
      data: (routes) {
        final activeRoute = routes.isNotEmpty ? routes.first.id : null;
        final routeLabel = activeRoute ?? widget.activeRouteId ?? 'Ninguna';
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Inspección de ruta",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentOrange,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Ruta activa: $routeLabel",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                _InspectionButton(
                  label: "Checklist Salida",
                  subtitle: _isSalidaDone ? "Completado" : "Pendiente",
                  icon: Icons.exit_to_app_rounded,
                  color: _isSalidaDone ? AppColors.primaryGreen : AppColors.accentOrange,
                  onTap: () async {
                    final result = await context.pushNamed('checklist_detail', extra: {
                      'routeId': activeRoute ?? '',
                      'type': ChecklistType.salida,
                    });
                    if (result == true) setState(() => _isSalidaDone = true);
                  },
                ),
                const SizedBox(height: 20),
                _InspectionButton(
                  label: "Checklist Entrega",
                  subtitle: !_isSalidaDone ? "Bloqueado (Requiere Salida)" : (_isEntradaDone ? "Completado" : "Disponible"),
                  icon: Icons.assignment_returned_outlined,
                  color: _isSalidaDone
                      ? (_isEntradaDone ? AppColors.primaryGreen : AppColors.accentOrange)
                      : (isDark ? Colors.white10 : const Color(0xFFE0E0E0)),
                  textColor: _isSalidaDone ? Colors.white : (isDark ? Colors.white54 : Colors.grey),
                  onTap: !_isSalidaDone
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Debes completar el Checklist de Salida primero."),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      : () async {
                          final result = await context.pushNamed('checklist_detail', extra: {
                            'routeId': activeRoute ?? '',
                            'type': ChecklistType.entrada,
                          });
                          if (result == true) setState(() => _isEntradaDone = true);
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InspectionButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _InspectionButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.textColor = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 80,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 2,
          shadowColor: color.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: textColor.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}
