import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seloasa_evidencias/ui/theme/app_colors.dart';

class UpdateService {
  static const MethodChannel _updateChannel = MethodChannel('com.seloasa.seloasa_evidencias/update');
  // URL del JSON que contiene la información de la última versión
  static const String _versionJsonUrl = 'http://rutas.seloasa.com.mx:2350/descargas/version.json';

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      // 1. Obtener la versión actual de la app instalada
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      // 2. Consultar el servidor para obtener la última versión
      final response = await http.get(Uri.parse(_versionJsonUrl)).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      final String latestVersion = data['version'] ?? '';
      final String apkUrl = data['url'] ?? '';
      final String releaseNotes = data['notes'] ?? 'Mejoras en el rendimiento y corrección de errores.';

      if (latestVersion.isEmpty || apkUrl.isEmpty) return;

      // 3. Comparar las versiones de forma semántica (e.g., 1.1.1 vs 1.1.2)
      if (_isVersionOlder(currentVersion, latestVersion)) {
        if (!context.mounted) return;
        _showUpdateDialog(context, latestVersion, apkUrl, releaseNotes);
      }
    } catch (e) {
      debugPrint('Error comprobando actualizaciones: $e');
    }
  }

  // Compara si la versión actual es menor que la del servidor
  static bool _isVersionOlder(String current, String latest) {
    try {
      List<int> currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < latestParts.length; i++) {
        int currentPart = i < currentParts.length ? currentParts[i] : 0;
        if (latestParts[i] > currentPart) return true;
        if (latestParts[i] < currentPart) return false;
      }
    } catch (e) {
      // Fallback a comparación de texto básica si falla el parseo
      return current != latest;
    }
    return false;
  }

  static void _showUpdateDialog(BuildContext context, String latestVersion, String apkUrl, String releaseNotes) {
    showDialog(
      context: context,
      barrierDismissible: false, // Forzar la actualización
      builder: (BuildContext context) {
        return _UpdateDialogWidget(
          latestVersion: latestVersion,
          apkUrl: apkUrl,
          releaseNotes: releaseNotes,
        );
      },
    );
  }
}

class _UpdateDialogWidget extends StatefulWidget {
  final String latestVersion;
  final String apkUrl;
  final String releaseNotes;

  const _UpdateDialogWidget({
    required this.latestVersion,
    required this.apkUrl,
    required this.releaseNotes,
  });

  @override
  State<_UpdateDialogWidget> createState() => _UpdateDialogWidgetState();
}

class _UpdateDialogWidgetState extends State<_UpdateDialogWidget> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusText = 'Preparando descarga...';

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _statusText = 'Verificando enlace de descarga...';
    });

    // Validar que la URL del APK es accesible antes de iniciar OTA
    try {
      final response = await http.head(Uri.parse(widget.apkUrl))
          .timeout(const Duration(seconds: 15));

      debugPrint('[UpdateService] HEAD status: ${response.statusCode}');
      debugPrint('[UpdateService] Content-Type: ${response.headers['content-type']}');
      debugPrint('[UpdateService] Content-Length: ${response.headers['content-length']}');

      if (response.statusCode != 200) {
        _showError(
          'No se pudo acceder al archivo de actualización '
          '(código HTTP ${response.statusCode}). Contacte a soporte.',
        );
        return;
      }

      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/vnd.android.package-archive') &&
          !contentType.contains('application/octet-stream') &&
          !contentType.contains('binary/octet-stream')) {
        debugPrint('[UpdateService] Advertencia: Content-Type inesperado: $contentType');
        // No bloqueamos, solo advertimos — algunos servidores usan tipos genéricos
      }
    } catch (e) {
      _showError('No se pudo verificar el enlace de descarga: $e');
      return;
    }

    setState(() {
      _statusText = 'Descargando actualización (0%)...';
    });

    try {
      await UpdateService._updateChannel.invokeMethod<int>('downloadUpdate', {
        'url': widget.apkUrl,
        'filename': 'seloasa-evidencias-update.apk',
      });
      if (!mounted) return;
      setState(() {
        _statusText = 'Descarga iniciada. Puede bloquear el teléfono; continuará en segundo plano.';
      });
    } on PlatformException catch (e) {
      _showError('No se pudo iniciar la descarga: ${e.message ?? e.code}');
    } catch (e) {
      _showError('No se pudo iniciar la descarga: $e');
    }
  }

  void _showError(String message) {
    setState(() {
      _isDownloading = false;
      _downloadProgress = 0.0;
      _statusText = message;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false, // Evitar cerrar con el botón atrás de Android
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: AppColors.accentOrange, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Actualización disponible',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Una nueva versión (${widget.latestVersion}) está lista para instalar.',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Novedades:',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.accentOrange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.releaseNotes,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (_isDownloading) ...[
              const SizedBox(height: 24),
              LinearProgressIndicator(
                value: _downloadProgress,
                backgroundColor: isDark ? Colors.white10 : Colors.black12,
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(10),
                minHeight: 8,
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  _statusText,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        actions: _isDownloading
            ? null
            : [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _startUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'ACTUALIZAR AHORA',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
      ),
    );
  }
}
