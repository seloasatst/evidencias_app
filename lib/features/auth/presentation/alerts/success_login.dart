import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showSuccessLoginDialog(
    BuildContext context, {
      required String userName,
      required VoidCallback onContinue,
    }) async {
  final theme = Theme.of(context);

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.all(20),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      title: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF3FA556), size: 28),
          const SizedBox(width: 10),
          Text(
            'Conexión exitosa',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
      content: Text(
        'Bienvenido, $userName.\nTu sesión se inició correctamente.',
        style: GoogleFonts.poppins(fontSize: 14),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onContinue();
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3FA556),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
}
