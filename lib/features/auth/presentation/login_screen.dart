import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:seloasa_evidencias/ui/theme/app_colors.dart';

import '../../home/presentation/route_provider.dart';
import 'alerts/failed_login.dart';
import 'alerts/success_login.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _storage = const FlutterSecureStorage();

  bool _obscure = true;
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final credentials = await ref.read(authStateProvider.notifier).getSavedCredentials();
    if (credentials != null) {
      _user.text = credentials['user']!;
      _pass.text = credentials['pass']!;
    }

    final enabled = await _storage.read(key: 'use_biometrics');
    if (enabled == 'true' && mounted) {
      setState(() => _isBiometricEnabled = true);
    }
  }

  Future<void> _authenticateBiometric() async {
    final auth = LocalAuthentication();
    final authenticated = await auth.authenticate(
      localizedReason: 'Inicia sesión con tu huella digital',
      options: const AuthenticationOptions(stickyAuth: true),
    );

    if (authenticated) {
      _submit();
    }
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    final success = await ref.read(authStateProvider.notifier).login(
          _user.text,
          _pass.text,
        );

    if (!mounted) return;

    if (success) {
      final user = ref.read(authStateProvider).user;
      ref.read(pendingRoutesProvider.future);
      await showSuccessLoginDialog(
        context,
        userName: user?.name ?? 'Usuario',
        onContinue: () {
          context.goNamed('home');
        },
      );
    } else {
      final error = ref.read(authStateProvider).error ?? 'Error desconocido';
      await showFailedLoginDialog(context, message: error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                ClipPath(
                  clipper: HeaderClipper(),
                  child: Container(
                    height: 320,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
                    ),
                    child: Stack(
                      children: [
                        Image.asset(
                          'assets/images/login_banner.jpg',
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: AppColors.primaryGreen),
                        ),
                        Container(
                          color: AppColors.primaryGreen.withValues(alpha: 0.75),
                        ),
                        Center(
                          child: Image.asset(
                            'assets/images/seloasa_logo.png',
                            height: 70,
                            fit: BoxFit.contain,
                            color: Colors.white,
                            colorBlendMode: BlendMode.srcIn,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Text(
                    "OneRoute",
                    style: GoogleFonts.poppins(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentOrange,
                    ),
                  ),
                  Text(
                    "Gestión inteligente de rutas y evidencias SELOASA",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Form(
                    key: _form,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _user,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.person_outline),
                            hintText: 'Usuario',
                            labelText: null,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu usuario' : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _pass,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline),
                            hintText: 'Contraseña',
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 20,
                              ),
                            ),
                          ),
                          validator: (v) => (v == null || v.length < 4) ? 'Mínimo 4 caracteres' : null,
                        ),
                        const SizedBox(height: 40),
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: ElevatedButton(
                                onPressed: authState.isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentOrange,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (authState.isLoading)
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    else ...[
                                      Text('Acceder', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_rounded, size: 20),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            if (_isBiometricEnabled) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: InkWell(
                                  onTap: _authenticateBiometric,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white10 : AppColors.primaryGreen.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark ? Colors.white24 : AppColors.primaryGreen.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.fingerprint,
                                      color: isDark ? Colors.white : AppColors.primaryGreen,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),
                  Text(
                    '© 2026 Servicios Logísticos Alsera S.A. de C.V.\nTodos los derechos reservados.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 60);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 20,
      size.width,
      size.height - 60,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
