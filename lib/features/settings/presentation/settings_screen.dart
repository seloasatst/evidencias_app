import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:seloasa_evidencias/ui/theme/app_colors.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:seloasa_evidencias/app/theme_provider.dart';
import '../../auth/presentation/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  bool _isBiometricEnabled = false;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _loadSettings();
  }

  Future<void> _checkBiometrics() async {
    bool canCheck = await auth.canCheckBiometrics;
    setState(() => _canCheckBiometrics = canCheck);
  }

  Future<void> _loadSettings() async {
    String? enabled = await _storage.read(key: 'use_biometrics');
    setState(() => _isBiometricEnabled = enabled == 'true');
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      bool authenticated = await auth.authenticate(
        localizedReason: 'Confirma tu huella para activar el acceso rápido',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (!authenticated) return;
    }

    await _storage.write(key: 'use_biometrics', value: value.toString());
    setState(() => _isBiometricEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/seloasa_logo.png',
              height: 20,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Text("CONFIGURACIONES", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ],
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionHeader("Apariencia"),
          const SizedBox(height: 16),
          _buildThemeSelector(),
          const Divider(height: 40),
          _buildSectionHeader("Seguridad"),
          const SizedBox(height: 16),
          _buildSettingsTile(
            icon: Icons.fingerprint,
            title: "Acceso con Huella Digital",
            subtitle: _canCheckBiometrics ? "Activa el acceso biométrico" : "No disponible en este equipo",
            trailing: Switch(
              value: _isBiometricEnabled,
              activeThumbColor: AppColors.primaryGreen,
              onChanged: _canCheckBiometrics ? _toggleBiometrics : null,
            ),
          ),
          const Divider(height: 40),
          _buildSectionHeader("Soporte y Ayuda"),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => context.pushNamed('knowledge_base'),
            borderRadius: BorderRadius.circular(16),
            child: _buildSettingsTile(
              icon: Icons.menu_book_rounded,
              title: "Base de Conocimientos",
              subtitle: "Guías, tutoriales y preguntas frecuentes",
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 40),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.accentOrange, letterSpacing: 1),
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, required String subtitle, required Widget trailing}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: isDark ? Colors.white : AppColors.primaryGreen, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary)),
                Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: isDark ? Colors.white70 : AppColors.textSecondary)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return OutlinedButton(
      onPressed: () async {
        await ref.read(authStateProvider.notifier).logout();
        if (!mounted) return;
        context.goNamed('login');
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        side: const BorderSide(color: Colors.red),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text("CERRAR SESIÓN", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildThemeSelector() {
    final currentTheme = ref.watch(themeProvider);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          _buildThemeOption(ThemeModeOption.light, "Claro", Icons.wb_sunny_outlined, currentTheme),
          _buildThemeOption(ThemeModeOption.dark, "Oscuro", Icons.nightlight_round_outlined, currentTheme),
          _buildThemeOption(ThemeModeOption.system, "Sistema", Icons.phone_android_outlined, currentTheme),
        ],
      ),
    );
  }

  Widget _buildThemeOption(ThemeModeOption option, String label, IconData icon, ThemeModeOption current) {
    final isSelected = option == current;
    return Expanded(
      child: InkWell(
        onTap: () => ref.read(themeProvider.notifier).setTheme(option),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : AppColors.textSecondary, size: 20),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
