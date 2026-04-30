import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChecklistScreen extends StatelessWidget {
  const ChecklistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Checklist de Unidades', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Center(
        child: Text(
          'Aquí va el checklist 👀',
          style: GoogleFonts.poppins(fontSize: 16),
        ),
      ),
    );
  }
}
