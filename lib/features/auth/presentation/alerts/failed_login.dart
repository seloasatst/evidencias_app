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
          Text(
            'No se pudo iniciar sesión',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: GoogleFonts.poppins(fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
