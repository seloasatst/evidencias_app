import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seloasa_evidencias/ui/theme/app_colors.dart';

import '../../auth/presentation/auth_provider.dart';
import '../../widgets/photo_picker.dart';
import '../data/incident_service.dart';

class IncidentReportScreen extends ConsumerStatefulWidget {
  final String? initialType;
  final bool autoSubmit;

  const IncidentReportScreen({
    super.key,
    this.initialType,
    this.autoSubmit = false,
  });

  @override
  ConsumerState<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends ConsumerState<IncidentReportScreen> {
  String? _selectedType;
  final _commentController = TextEditingController();
  File? _photoFile;
  Uint8List? _photoBytes;
  String? _photoFileName;
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;
  final _incidentService = IncidentService();

  final List<Map<String, dynamic>> _types = [
    {'label': 'Falla Mecánica', 'icon': Icons.build_circle_outlined, 'color': Colors.orange, 'id': 'MECANICA'},
    {'label': 'Tráfico / Retraso', 'icon': Icons.timer_outlined, 'color': Colors.blue, 'id': 'TRAFICO'},
    {'label': 'Emergencia', 'icon': Icons.warning_amber_rounded, 'color': Colors.red, 'id': 'EMERGENCIA'},
    {'label': 'Otro', 'icon': Icons.more_horiz, 'color': Colors.grey, 'id': 'OTRO'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _selectedType = widget.initialType;
    }

    if (widget.autoSubmit) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final authState = ref.read(authStateProvider);

        if (authState.user == null) {
          setState(() => _isLoading = true);
          final success = await ref.read(authStateProvider.notifier).loginWithSavedCredentials();
          if (!success && mounted) {
            context.go('/login');
            return;
          }
        }

        _submit();
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await PhotoPicker.scanDocument();

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _photoBytes = bytes;
        _photoFileName = pickedFile.path.split('/').last;
        _photoFile = pickedFile;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedType == null) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).user;
      final userCode = (user?.username.isNotEmpty ?? false) ? user!.username : (user?.code ?? '');

      if (userCode.isEmpty) {
        throw Exception('No se encontró el usuario para reportar la incidencia.');
      }

      await _incidentService.sendIncident(
        tipo: _selectedType!,
        comentarios: _commentController.text.trim(),
        userCode: userCode,
        fecha: DateTime.now(),
        photoBytes: _photoBytes,
        photoFileName: _photoFileName,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });

      if (!widget.autoSubmit) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incidencia reportada correctamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _errorMessage = e.toString();
      });

      if (!widget.autoSubmit) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.autoSubmit) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading) ...[
                  const CircularProgressIndicator(color: AppColors.accentOrange),
                  const SizedBox(height: 24),
                  Text(
                    "Enviando reporte...",
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary),
                  ),
                ] else if (_isSuccess) ...[
                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
                  const SizedBox(height: 24),
                  Text(
                    "Reporte Enviado",
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tu incidencia ha sido registrada correctamente.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14, color: isDark ? Colors.white70 : Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  _buildResultButton("VOLVER AL INICIO", Colors.green, () => context.go('/home')),
                ] else if (_errorMessage != null) ...[
                  const Icon(Icons.error_outline, color: Colors.red, size: 80),
                  const SizedBox(height: 24),
                  Text(
                    "Error al Enviar",
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14, color: isDark ? Colors.white70 : Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  _buildResultButton("REINTENTAR", AppColors.accentOrange, _submit),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: Text("CANCELAR", style: GoogleFonts.poppins(color: Colors.grey)),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/seloasa_logo.png',
              height: 20,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Text("INCIDENCIAS", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Tipo de Incidencia"),
              const SizedBox(height: 16),
              _buildTypeGrid(),
              const SizedBox(height: 32),
              _buildSectionTitle("Evidencia Fotográfica"),
              const SizedBox(height: 16),
              _buildPhotoCapture(),
              const SizedBox(height: 32),
              _buildSectionTitle("Detalles Adicionales"),
              const SizedBox(height: 12),
              _buildCommentBox(),
              const SizedBox(height: 40),
              _buildActionButton(),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.accentOrange,
      ),
    );
  }

  Widget _buildTypeGrid() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: _types.length,
      itemBuilder: (context, index) {
        final t = _types[index];
        final isSelected = _selectedType == t['id'];
        return InkWell(
          onTap: () => setState(() => _selectedType = t['id']),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? t['color'] : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? t['color'] : (isDark ? Colors.white10 : AppColors.cardBorder), width: 2),
              boxShadow: isSelected
                  ? [BoxShadow(color: t['color'].withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(t['icon'], size: 28, color: isSelected ? Colors.white : t['color']),
                const SizedBox(height: 8),
                Text(
                  t['label'],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotoCapture() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white10 : AppColors.cardBorder, style: BorderStyle.solid),
        ),
        child: (_photoBytes != null || _photoFile != null)
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _photoBytes != null
                        ? Image.memory(_photoBytes!, width: double.infinity, height: 200, fit: BoxFit.cover)
                        : Image.file(_photoFile!, width: double.infinity, height: 200, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: CircleAvatar(
                      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: AppColors.accentOrange),
                        onPressed: _pickImage,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accentOrange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 36, color: AppColors.accentOrange),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Capturar Evidencia",
                    style: GoogleFonts.poppins(fontSize: 14, color: isDark ? Colors.white70 : AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCommentBox() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.cardBorder),
      ),
      child: TextField(
        controller: _commentController,
        maxLines: 4,
        style: GoogleFonts.poppins(fontSize: 14, color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: "Describe lo sucedido con el mayor detalle posible...",
          hintStyle: GoogleFonts.poppins(color: isDark ? Colors.white38 : AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: (_selectedType == null || _isLoading) ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentOrange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
          shadowColor: AppColors.accentOrange.withValues(alpha: 0.4),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text("ENVIAR REPORTE AHORA", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      ),
    );
  }

  Widget _buildResultButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
