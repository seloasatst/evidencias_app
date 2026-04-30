import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:seloasa_evidencias/ui/theme/app_colors.dart';
import 'package:seloasa_evidencias/app/theme_provider.dart';
import 'package:seloasa_evidencias/app/app_router.dart';
import 'package:seloasa_evidencias/core/services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WidgetService.init();
  
  initializeDateFormatting('es_MX', null).then((_) {
    runApp(
      const ProviderScope(
        child: SeloasaApp(),
      ),
    );
  });
}

class SeloasaApp extends ConsumerWidget {
  const SeloasaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeOption = ref.watch(themeProvider);
    
    ThemeMode themeMode;
    switch (themeModeOption) {
      case ThemeModeOption.light: themeMode = ThemeMode.light; break;
      case ThemeModeOption.dark: themeMode = ThemeMode.dark; break;
      case ThemeModeOption.system: themeMode = ThemeMode.system; break;
    }

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'OneRoute SELOASA',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: themeMode,
      locale: const Locale('es', 'MX'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'MX'),
        Locale('es'),
        Locale('en'),
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
          primary: AppColors.primaryGreen,
          secondary: AppColors.accentOrange,
          surface: AppColors.white,
          background: AppColors.backgroundLight,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: AppColors.backgroundLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.white,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
          brightness: Brightness.dark,
          primary: AppColors.primaryGreen,
          secondary: AppColors.accentOrange,
          surface: const Color(0xFF1E1E1E),
          background: const Color(0xFF121212),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
