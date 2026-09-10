import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScreenSecurityService {
  static const _channel = MethodChannel('com.seloasa.seloasa_evidencias/security');

  /// Activa la protección contra capturas de pantalla y grabaciones (FLAG_SECURE en Android)
  static Future<void> enableSecure() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('enableSecure');
    } catch (e) {
      debugPrint('[ScreenSecurityService] enableSecure error: $e');
    }
  }

  /// Desactiva la protección de pantalla
  static Future<void> disableSecure() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('disableSecure');
    } catch (e) {
      debugPrint('[ScreenSecurityService] disableSecure error: $e');
    }
  }
}