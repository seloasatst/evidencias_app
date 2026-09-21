import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const String _appGroupId = 'com.seloasa.seloasa_evidencias'; // Cambiar si es necesario
  static const String _androidWidgetName = 'SeloasaWidgetProvider';
  static const String _androidSosWidgetName = 'SosWidgetProvider';
  static bool get _isSupportedPlatform => !kIsWeb;

  static Future<void> init() async {
    if (!_isSupportedPlatform) return;
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  static Future<void> updateRouteInfo(String? routeTitle) async {
    if (!_isSupportedPlatform) return;
    try {
      final title = routeTitle ?? "SIN RUTAS ACTIVAS";
      await HomeWidget.saveWidgetData<String>('route_title', title);
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
      );
      await HomeWidget.updateWidget(
        androidName: _androidSosWidgetName,
      );
    } catch (e) {
      debugPrint('Error actualizando widget: $e');
    }
  }
}
