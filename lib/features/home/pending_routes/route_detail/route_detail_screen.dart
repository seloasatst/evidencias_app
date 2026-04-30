import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seloasa_evidencias/ui/theme/app_colors.dart';

import '../../presentation/route_provider.dart';

class RouteDetailScreen extends ConsumerStatefulWidget {
  final String idRuta;
  final String routeId;
  final String cobertura;

  const RouteDetailScreen({
    super.key,
    required this.idRuta,
    required this.routeId,
    required this.cobertura,
  });

  @override
  ConsumerState<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends ConsumerState<RouteDetailScreen> {
  final TextEditingController _buscadorCtrl = TextEditingController();

  @override
  void dispose() {
    _buscadorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(routeDetailProvider(widget.idRuta));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Buscar mi ruta',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.accentOrange,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _buscadorCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Orden, referencia, destino',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : AppColors.textSecondary.withOpacity(0.5),
                ),
                suffixIcon: Icon(Icons.search, color: isDark ? Colors.white : AppColors.textPrimary),
                fillColor: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.white24 : AppColors.textPrimary, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.white24 : AppColors.textPrimary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Ordenes de servicio',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.accentOrange,
              ),
            ),
            Text(
              'Selecciona una orden para capturar evidencias',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            detailAsync.when(
              data: (listado) {
                final query = _buscadorCtrl.text.trim().toLowerCase();
                final filtered = query.isEmpty
                    ? listado
                    : listado.where((orden) {
                        final searchable = [
                          orden.guideNumber,
                          orden.os,
                          orden.referenceOr,
                          orden.pieces,
                          orden.scheduledDate,
                          orden.destinationState,
                          orden.client,
                          orden.address,
                        ].join(' ').toLowerCase();
                        return searchable.contains(query);
                      }).toList();

                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        listado.isEmpty
                            ? 'No hay ordenes asignadas a esta guia'
                            : 'No se encontraron ordenes con esa busqueda',
                        style: GoogleFonts.poppins(color: isDark ? Colors.white70 : AppColors.textSecondary),
                      ),
                    ),
                  );
                }

                return Column(
                  children: filtered
                      .map(
                        (orden) => _OSCard(
                          osFolio: orden.os,
                          pieces: orden.pieces,
                          scheduledDate: orden.scheduledDate,
                          onTap: () async {
                            final sent = await context.pushNamed<bool>('os_capture', extra: {
                              'numGuia': orden.guideNumber.isNotEmpty ? orden.guideNumber : widget.idRuta,
                              'routeId': widget.routeId,
                              'osFolio': orden.os,
                              'referenciaOR': orden.referenceOr,
                              'ppza': orden.pieces,
                              'fechaProgramada': orden.scheduledDate,
                              'estadoDestino': orden.destinationState,
                              'clienteDestino': orden.client,
                              'direccion': orden.address,
                              'horaCompromiso': orden.time,
                            });

                            if (sent == true && context.mounted) {
                              ref.invalidate(routeDetailProvider(widget.idRuta));
                              ref.invalidate(pendingRoutesProvider);
                              context.pop(true);
                            }
                          },
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Error al cargar el detalle: $e',
                    style: GoogleFonts.poppins(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  minimumSize: const Size(120, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                child: const Text('Ver mas', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OSCard extends StatelessWidget {
  final String osFolio;
  final String pieces;
  final String scheduledDate;
  final VoidCallback onTap;

  const _OSCard({
    required this.osFolio,
    required this.pieces,
    required this.scheduledDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 12,
            bottom: 12,
            child: Container(
              width: 4,
              decoration: const BoxDecoration(
                color: AppColors.accentOrange,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
              ),
            ),
          ),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2C) : AppColors.accentOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      color: AppColors.accentOrange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          osFolio,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'PPZA: ${pieces.isEmpty ? 'N/D' : pieces}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Fecha programada: ${scheduledDate.isEmpty ? 'N/D' : scheduledDate}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
