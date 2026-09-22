import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seloasa_evidencias/ui/theme/app_colors.dart';

import '../features/auth/presentation/auth_provider.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/checklist/checklist_history_screen.dart';
import '../features/checklist/checklist_screen.dart';
import '../features/dispersion/presentation/dispersion_request_screen.dart';
import '../features/dispersion/presentation/card_scanner_screen.dart';
import '../features/dispersion/presentation/dispersion_success_screen.dart';
import '../features/home/dashboard_screen.dart';
import '../features/home/pending_routes/home_screen.dart';
import '../features/home/pending_routes/os_capture/os_capture_screen.dart';
import '../features/home/pending_routes/route_detail/route_detail_screen.dart';
import '../features/incidents/presentation/incident_report_screen.dart';
import '../features/knowledge_base/presentation/kb_article_detail_screen.dart';
import '../features/knowledge_base/presentation/knowledge_base_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/sos/presentation/sos_screen.dart';
import '../features/checador/presentation/checador_home_screen.dart';
import '../features/checador/presentation/checador_history_screen.dart';
import 'app_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    errorBuilder: (context, state) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline, size: 64, color: Colors.red),
                ),
                const SizedBox(height: 24),
                Text(
                  '¡Ups! Ruta no encontrada',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'La ruta "${state.uri.path}" no existe o ha sido movida.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDark ? Colors.white38 : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 200,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => context.go('/home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentOrange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Text(
                      'VOLVER AL INICIO',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    redirect: (context, state) {
      if (!authState.isInitialized) return null;

      final loggedIn = authState.user != null;
      final loggingIn = state.matchedLocation == '/login';
      final isRoot = state.matchedLocation == '/';
      final isAutoIncident = state.matchedLocation == '/incident' && state.uri.queryParameters['auto'] == 'true';

      if (!loggedIn) {
        if (isAutoIncident) return null;
        return loggingIn ? null : '/login';
      }

      if (loggingIn || isRoot) return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/evidencias',
            name: 'evidencias',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/checklist',
            name: 'checklist_main',
            builder: (context, state) => const ChecklistHistoryScreen(),
          ),
          GoRoute(
            path: '/route-detail',
            name: 'route_detail',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return RouteDetailScreen(
                idRuta: extra['idRuta'],
                routeId: extra['routeId'],
                cobertura: extra['cobertura'],
              );
            },
          ),
          GoRoute(
            path: '/dispersion-request',
            name: 'dispersion_request',
            builder: (context, state) => const DispersionRequestScreen(),
          ),
          GoRoute(
            path: '/kb',
            name: 'knowledge_base',
            builder: (context, state) => const KnowledgeBaseScreen(),
          ),
          GoRoute(
            path: '/checador',
            name: 'checador',
            builder: (context, state) => const ChecadorHomeScreen(),
          ),
          GoRoute(
            path: '/checador/historial',
            name: 'checador_historial',
            builder: (context, state) => const ChecadorHistoryScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/os-capture',
        name: 'os_capture',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return OSCaptureScreen(
            numGuia: extra['numGuia'],
            routeId: extra['routeId'],
            osFolio: extra['osFolio'],
            referenciaOR: extra['referenciaOR'] ?? '',
            ppza: extra['ppza'] ?? '',
            fechaProgramada: extra['fechaProgramada'] ?? '',
            estadoDestino: extra['estadoDestino'] ?? '',
            clienteDestino: extra['clienteDestino'],
            direccion: extra['direccion'],
            horaCompromiso: extra['horaCompromiso'],
          );
        },
      ),
      GoRoute(
        path: '/checklist-detail',
        name: 'checklist_detail',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ChecklistScreen(
            initialRouteId: extra?['routeId'],
            type: extra?['type'] ?? ChecklistType.salida,
          );
        },
      ),
      GoRoute(
        path: '/incident-report',
        name: 'incident_report',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final type = (state.extra as String?) ?? state.uri.queryParameters['type'];
          return IncidentReportScreen(initialType: type);
        },
      ),
      GoRoute(
        path: '/incident',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final type = state.uri.queryParameters['type'];
          final auto = state.uri.queryParameters['auto'] == 'true';
          return IncidentReportScreen(
            initialType: type,
            autoSubmit: auto,
          );
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'configuracion',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notificaciones',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/card-scanner',
        name: 'card_scanner',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CardScannerScreen(),
      ),
      GoRoute(
        path: '/kb/article/:idOrSlug',
        name: 'kb_article_detail',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final idOrSlug = state.pathParameters['idOrSlug'] ?? '';
          return KbArticleDetailScreen(idOrSlug: idOrSlug);
        },
      ),
      GoRoute(
        path: '/dispersion-success',
        name: 'dispersion_success',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return DispersionSuccessScreen(
            tarjeta: extra['tarjeta'] ?? '•••• •••• •••• 0000',
            ruta: extra['ruta'] ?? 'RUTA GENERAL',
          );
        },
      ),
      GoRoute(
        path: '/sos',
        name: 'sos',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SosScreen(),
      ),
    ],
  );
});
