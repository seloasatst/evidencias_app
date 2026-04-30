import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

/// Servicio/repo muy sencillo para escoger/tomar fotos.
/// Lo hacemos como funciones estáticas para que sea fácil llamarlo.
class PhotoPicker {
  static final ImagePicker _picker = ImagePicker();

  /// Escanea un documento automáticamente (detecta bordes y recorta)
  static Future<File?> scanDocument() async {
    try {
      final scanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormat: DocumentFormat.jpeg,
          mode: ScannerMode.full,
          pageLimit: 1,
        ),
      );

      final result = await scanner.scanDocument();
      if (result.images.isNotEmpty) {
        return File(result.images.first);
      }
    } catch (e) {
      print('Error al escanear documento: $e');
    }
    return null;
  }

  /// Abre la cámara NATIVA del teléfono (rápido, sin UI custom).
  /// Devuelve `File` de la foto o null si el usuario canceló.
  static Future<File?> pickFromSystemCamera() async {
    final XFile? taken = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 45,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (taken == null) return null;
    return File(taken.path);
  }

  /// Abre la galería (imágenes existentes).
  /// Devuelve `File` o null si cancelan.
  static Future<File?> pickFromGallery() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 45,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return null;
    return File(picked.path);
  }
}
