import 'package:flutter/foundation.dart';

class AppApiConfig {
  static String get evidenciasBaseUrl {
    const configured = String.fromEnvironment('EVIDENCIAS_API_BASE_URL', defaultValue: '');
    if (configured.isNotEmpty) {
      return configured;
    }

    if (kIsWeb) {
      return 'http://localhost:5005/api/v1';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:5005/api/v1';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'http://localhost:5005/api/v1';
    }
  }

  static String get authBaseUrl {
    const configured = String.fromEnvironment('AUTH_API_BASE_URL', defaultValue: '');
    if (configured.isNotEmpty) {
      return configured;
    }

    return 'https://rutas.seloasa.com.mx/api/seloasa';
  }
}
