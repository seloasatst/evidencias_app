import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seloasa_evidencias/ui/theme/app_colors.dart';

import 'widgets/evidence_form.dart';

class OSCaptureScreen extends StatelessWidget {
  final String numGuia;
  final String routeId;
  final String osFolio;
  final String referenciaOR;
  final String ppza;
  final String fechaProgramada;
  final String estadoDestino;
  final String clienteDestino;
  final String direccion;
  final String horaCompromiso;

  const OSCaptureScreen({
    super.key,
    required this.numGuia,
    required this.routeId,
    required this.osFolio,
    required this.referenciaOR,
    required this.ppza,
    required this.fechaProgramada,
    required this.estadoDestino,
    required this.clienteDestino,
    required this.direccion,
    required this.horaCompromiso,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              referenciaOR.isEmpty ? osFolio : referenciaOR,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              'OS $osFolio',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? Colors.white70 : AppColors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: EvidenceForm(
            numGuia: numGuia,
            routeId: routeId,
            osFolio: osFolio,
            referenciaOR: referenciaOR,
            ppza: ppza,
            fechaProgramada: fechaProgramada,
            estadoDestino: estadoDestino,
            clienteDestino: clienteDestino,
            direccion: direccion,
            horaCompromiso: horaCompromiso,
          ),
        ),
      ),
    );
  }
}
