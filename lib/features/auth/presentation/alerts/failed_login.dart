import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showFailedLoginDialog(
    BuildContext context, {
      required String message,
    }) async {
  final theme = Theme.of(context);

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.all(20),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      title: Row(
        children: [
          const Icon(Icons.error_rounded, color: Colors.red, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No se pudo iniciar sesión',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: GoogleFonts.poppins(fontSize: 14),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    ),
  );
}
