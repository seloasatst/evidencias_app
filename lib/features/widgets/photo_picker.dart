import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';

/// Servicio sencillo para escoger o tomar fotos.
class PhotoPicker {
  static final ImagePicker _picker = ImagePicker();

  static void _log(String message) {
    debugPrint(message);
  }

  /// Escanea un documento automáticamente.
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
      _log('Error al escanear documento: $e');
    }
    return null;
  }

  /// Abre la cámara nativa del teléfono.
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

  /// Abre la galería.
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
