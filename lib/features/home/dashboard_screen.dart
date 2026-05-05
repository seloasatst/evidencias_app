import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seloasa_evidencias/ui/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/presentation/auth_provider.dart';
import './presentation/route_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String formattedDate = DateFormat('d MMMM yyyy', 'es').format(DateTime.now());
    final user = ref.watch(authStateProvider).user;
    
    final String welcomeName = user?.name.split(' ').first ?? 'Usuario';
    final routesAsync = ref.watch(pendingRoutesProvider);
    final String pendingCount = routesAsync.maybeWhen(
      data: (_) => ref.watch(pendingRoutesProvider.notifier).totalCount.toString(),
      orElse: () => "0",
    );

    final int hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = "Buen día";
    } else if (hour < 19) {
      greeting = "Buenas tardes";
    } else {
      greeting = "Buenas noches";
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formattedDate,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "$greeting, $welcomeName",
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.accentOrange,
              ),
            ),
            const SizedBox(height: 24),
            _SummaryCard(
              title: "Rutas pendientes de cerrar",
              value: pendingCount,
              isFullWidth: true,
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: "Rutas en curso",
                    value: "0",
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _SummaryCard(
                    title: "Alertas activas",
                    value: "0",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionHeader("Rutas actuales"),
            const SizedBox(height: 12),
            _buildIncidentsWidget(context),
          ],
        ),
      ),
    );
  }


  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.accentOrange),
    );
  }

  Widget _buildIncidentsWidget(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Icon(
                  Icons.info_outline,
                  color: (isDark ? Colors.white38 : AppColors.textSecondary).withValues(alpha: 0.3),
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  "No hay incidencias reportadas hoy",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.pushNamed('incident_report'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.accentOrange),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                "REPORTAR NUEVA INCIDENCIA",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentOrange,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final bool isFullWidth;

  const _SummaryCard({
    required this.title,
    required this.value,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? (isDark ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: isFullWidth ? 32 : 24,
              fontWeight: FontWeight.w800,
              color: AppColors.accentOrange,
            ),
          ),
        ],
      ),
    );
  }
}
