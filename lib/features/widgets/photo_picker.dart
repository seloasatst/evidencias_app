import 'dart:io';
import 'package:image_picker/image_picker.dart';

/// Servicio/repo muy sencillo para escoger/tomar fotos.
/// Lo hacemos como funciones estáticas para que sea fácil llamarlo.
class PhotoPicker {
  static final ImagePicker _picker = ImagePicker();

  /// Abre la cámara NATIVA del teléfono (rápido, sin UI custom).
  /// Devuelve `File` de la foto o null si el usuario canceló.
  static Future<File?> pickFromSystemCamera() async {
    final XFile? taken = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90, // comprime un poquito
    );
    if (taken == null) return null;
    return File(taken.path);
  }

  /// Abre la galería (imágenes existentes).
  /// Devuelve `File` o null si cancelan.
  static Future<File?> pickFromGallery() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return null;
    return File(picked.path);
  }
}
