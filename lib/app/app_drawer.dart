import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:seloasa_evidencias/ui/theme/app_colors.dart';
import '../features/auth/presentation/auth_provider.dart';
import '../features/sos/presentation/sos_modal.dart';

final drawerAppVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return 'v${info.version}';
  } catch (_) {
    return 'v2.0.6';
  }
});

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  void _navigateTo(BuildContext context, String routeName) {
    Navigator.of(context).pop(); // Cierra el Drawer
    context.goNamed(routeName);
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF252525) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Cerrar Sesión',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas salir de la aplicación?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isDark ? Colors.white70 : AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'CERRAR SESIÓN',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      Navigator.of(context).pop(); // Cerrar drawer
      await ref.read(authStateProvider.notifier).logout();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String currentPath = GoRouterState.of(context).uri.path;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authStateProvider).user;
    final displayName = user == null
        ? 'SIN SESIÓN'
        : (user.name.trim().isNotEmpty ? user.name : user.username).toUpperCase();
    final versionText = ref.watch(drawerAppVersionProvider).valueOrNull ?? 'v2.0.6';

    final Color drawerBgColor = isDark ? const Color(0xFF181C19) : Colors.white;

    return Drawer(
      backgroundColor: drawerBgColor,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Cabecera con Perfil de Usuario e Imagen de Fondo Fusionada
            SizedBox(
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/login_banner.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primaryGreen.withValues(alpha: isDark ? 0.72 : 0.82),
                            AppColors.primaryGreen.withValues(alpha: isDark ? 0.92 : 0.95),
                            drawerBgColor,
                          ],
                          stops: const [0.0, 0.65, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/images/seloasa_logo.png',
                            height: 52,
                            fit: BoxFit.contain,
                            color: Colors.white,
                            colorBlendMode: BlendMode.srcIn,
                            errorBuilder: (context, error, stackTrace) => Text(
                              "SELOASA",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            shadows: const [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Lista de Opciones de Navegación
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                children: [
                  _buildSectionHeader(context, 'PRINCIPAL'),
                  _DrawerItem(
                    icon: Icons.grid_view_rounded,
                    activeIcon: Icons.grid_view_rounded,
                    label: 'Inicio',
                    isSelected: currentPath == '/home',
                    onTap: () => _navigateTo(context, 'home'),
                  ),
                  _DrawerItem(
                    icon: Icons.local_shipping_outlined,
                    activeIcon: Icons.local_shipping_rounded,
                    label: 'Evidencias & Rutas',
                    isSelected: currentPath.startsWith('/evidencias'),
                    onTap: () => _navigateTo(context, 'evidencias'),
                  ),
                  _DrawerItem(
                    icon: Icons.menu_book_outlined,
                    activeIcon: Icons.menu_book_rounded,
                    label: 'Base de Conocimiento',
                    isSelected: currentPath.startsWith('/kb'),
                    onTap: () => _navigateTo(context, 'knowledge_base'),
                  ),
                  _DrawerItem(
                    icon: Icons.access_time_outlined,
                    activeIcon: Icons.access_time_filled_rounded,
                    label: 'Checador de Asistencia',
                    isSelected: currentPath.startsWith('/checador'),
                    onTap: () => _navigateTo(context, 'checador'),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),

                  _buildSectionHeader(context, 'SEGURIDAD'),
                  _DrawerItem(
                    icon: Icons.emergency_rounded,
                    activeIcon: Icons.emergency_rounded,
                    label: 'Botón de Pánico S.O.S',
                    isSelected: currentPath.startsWith('/sos'),
                    isEmergency: true,
                    onTap: () {
                      Navigator.of(context).pop();
                      SosModal.show(context);
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),

                  _buildSectionHeader(context, 'SISTEMA'),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings_rounded,
                    label: 'Configuración',
                    isSelected: currentPath.startsWith('/settings'),
                    onTap: () => _navigateTo(context, 'configuracion'),
                  ),
                ],
              ),
            ),

            // Footer con Cerrar Sesión y Versión
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111512) : Colors.grey[50],
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _confirmLogout(context, ref),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.logout_rounded,
                              color: Colors.redAccent,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Cerrar Sesión',
                              style: GoogleFonts.poppins(
                                color: Colors.redAccent,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Text(
                    versionText,
                    style: GoogleFonts.poppins(
                      color: isDark ? Colors.white54 : AppColors.textSecondary.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.accentOrange.withValues(alpha: 0.85) : AppColors.textSecondary.withValues(alpha: 0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isEmergency;

  const _DrawerItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isEmergency = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color iconColor;
    Color textColor;
    Color tileBackgroundColor;

    if (isEmergency) {
      iconColor = const Color(0xFFFF5252);
      textColor = isDark ? const Color(0xFFFF8A80) : const Color(0xFFD32F2F);
      tileBackgroundColor = isDark ? const Color(0xFF3A1A1A) : const Color(0xFFFDE8E8);
    } else if (isSelected) {
      iconColor = AppColors.accentOrange;
      textColor = isDark ? Colors.white : AppColors.primaryGreen;
      tileBackgroundColor = AppColors.primaryGreen.withValues(alpha: isDark ? 0.35 : 0.09);
    } else {
      iconColor = isDark ? Colors.white70 : AppColors.textSecondary;
      textColor = isDark ? Colors.white.withValues(alpha: 0.88) : AppColors.textPrimary;
      tileBackgroundColor = Colors.transparent;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: tileBackgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Barra de acento vertical naranja a la izquierda si está seleccionado
          if (isSelected)
            Positioned(
              left: 0,
              top: 8,
              bottom: 8,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: AppColors.accentOrange,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentOrange.withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ListTile(
            onTap: onTap,
            dense: true,
            contentPadding: EdgeInsets.only(
              left: isSelected ? 16 : 14,
              right: 14,
              top: 2,
              bottom: 2,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isEmergency
                    ? const Color(0xFFFF5252).withValues(alpha: 0.15)
                    : (isSelected
                        ? AppColors.accentOrange.withValues(alpha: 0.18)
                        : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04))),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: iconColor,
                size: 20,
              ),
            ),
            title: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: isSelected || isEmergency ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
