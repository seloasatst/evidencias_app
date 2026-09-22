import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seloasa_evidencias/ui/theme/app_colors.dart';
import '../../home/presentation/route_provider.dart';
import './paqueteria_provider.dart';

class PaqueteriaScreen extends ConsumerStatefulWidget {
  const PaqueteriaScreen({super.key});

  @override
  ConsumerState<PaqueteriaScreen> createState() => _PaqueteriaScreenState();
}

class _PaqueteriaScreenState extends ConsumerState<PaqueteriaScreen> {
  final TextEditingController _buscadorCtrl = TextEditingController();

  String _normalizeSearch(String value) => value.trim().toLowerCase();

  @override
  void dispose() {
    _buscadorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guiasAsync = ref.watch(guiasPaqueteriaProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header estilo Evidencias
            Text(
              'Paquetería / Guías',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.accentOrange,
              ),
            ),
            const SizedBox(height: 12),
            
            // Buscador idéntico al de Evidencias
            TextField(
              controller: _buscadorCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Número, NE, OS, OR, destino...',
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
            
            // Fila de acción idéntica
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Seleccione una guía de paquetería',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => ref.invalidate(guiasPaqueteriaProvider),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Recargar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Lista de Guías
            guiasAsync.when(
              data: (guias) {
                final query = _normalizeSearch(_buscadorCtrl.text);
                final filtered = query.isEmpty
                    ? guias
                    : guias.where((guia) => guia.searchableText().contains(query)).toList();

                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No se encontraron guías con esa búsqueda',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(color: isDark ? Colors.white70 : AppColors.textSecondary),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    const SizedBox(height: 8),
                    ...filtered.map(
                      (guia) => _PaqueteriaCard(
                        idGuia: guia.id,
                        cobertura: guia.coverage,
                        onTap: () async {
                          final sent = await context.pushNamed<bool>('route_detail', extra: {
                            'idRuta': guia.id,
                            'routeId': guia.routeId,
                            'cobertura': guia.coverage,
                          });

                          if (sent == true) {
                            ref.invalidate(guiasPaqueteriaProvider);
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Cargando guías...'),
                    ],
                  ),
                ),
              ),
              error: (e, _) => Center(
                child: Column(
                  children: [
                    Text(
                      'No se pudieron cargar las guías.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(guiasPaqueteriaProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Intentar de nuevo'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _PaqueteriaCard extends StatelessWidget {
  final String idGuia;
  final String cobertura;
  final VoidCallback onTap;

  const _PaqueteriaCard({
    required this.idGuia,
    required this.cobertura,
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
          // Contenido de la tarjeta
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : AppColors.accentOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.inventory_2,
                    color: isDark ? Colors.white : AppColors.accentOrange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        idGuia,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cobertura,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
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
          
          // La barra lateral naranja característica
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

          // Capa de interacción (InkWell) en la parte superior de todo
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  debugPrint('DEBUG: Click en guía $idGuia');
                  onTap();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
