import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:seloasa_evidencias/ui/theme/app_colors.dart';
import 'dart:math' as math;

class DispersionSuccessScreen extends StatelessWidget {
  final String tarjeta;
  final String ruta;

  const DispersionSuccessScreen({
    super.key,
    required this.tarjeta,
    required this.ruta,
  });

  String _generateFolio() {
    final rand = math.Random();
    final number = 1000 + rand.nextInt(9000);
    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    return 'DISP-$dateStr-$number';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final folio = _generateFolio();
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              
              // 1. Icono de éxito animado (en contenedor circular)
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                      width: 4,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.green,
                    size: 54,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 2. Títulos principales
              Text(
                'Tarjeta Vinculada',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu número de tarjeta ha sido registrado correctamente para recibir dispersiones.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 40),

              // 3. Ticket de Recibo Digital Premium
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white10 : AppColors.cardBorder,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      // Cabecera del ticket
                      Container(
                        color: AppColors.accentOrange.withValues(alpha: 0.08),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'DETALLE DE REGISTRO',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentOrange,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                'REGISTRADO',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green[800],
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Detalles del ticket
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.credit_card_rounded,
                              size: 48,
                              color: AppColors.accentOrange,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'DISPERSIÓN DE NÓMINA',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white54 : AppColors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Divider(height: 1, color: Colors.white10),
                            const SizedBox(height: 20),

                            // Fila de información
                            _buildInfoRow('Folio de trámite', folio, isDark),
                            const SizedBox(height: 12),
                            _buildInfoRow('Tarjeta registrada', tarjeta, isDark),
                            const SizedBox(height: 12),
                            _buildInfoRow('Ruta de dispersión', ruta, isDark),
                            const SizedBox(height: 12),
                            _buildInfoRow('Fecha y hora', fecha, isDark),
                            const SizedBox(height: 12),
                            _buildInfoRow('Estatus', 'Pendiente de dispersión', isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // 4. Botón de regreso
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                  child: Text(
                    'FINALIZAR',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isDark ? Colors.white54 : AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isDark ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
