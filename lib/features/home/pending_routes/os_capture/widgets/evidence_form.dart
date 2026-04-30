import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seloasa_evidencias/ui/theme/app_colors.dart';
import '../../../../widgets/photo_picker.dart';
import '../../../presentation/route_provider.dart';

class EvidenceForm extends ConsumerStatefulWidget {
  final String numGuia;
  final String routeId;
  final String osFolio;
  final String referenciaOR;
  final String ppza;
  final String fechaProgramada;
  final String estadoDestino;
  final String clienteDestino;
  final String direccion;
  final String horaCompromiso;

  const EvidenceForm({
    super.key,
    required this.numGuia,
    required this.routeId,
    required this.osFolio,
    required this.referenciaOR,
    required this.ppza,
    required this.fechaProgramada,
    required this.estadoDestino,
    required this.clienteDestino,
    required this.direccion,
    required this.horaCompromiso,
  });

  @override
  ConsumerState<EvidenceForm> createState() => _EvidenceFormState();
}

class _EvidenceFormState extends ConsumerState<EvidenceForm> {
  final _cantidadCtrl = TextEditingController();
  final _comentariosCtrl = TextEditingController();
  DateTime? _fechaHoraSello;
  String? _resultado;
  File? _fotoFile;
  Uint8List? _fotoBytes;
  String? _fotoFileName;
  String? _cantidadError;
  String? _fechaHoraError;

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _comentariosCtrl.dispose();
    super.dispose();
  }

  String _formatearFechaHora(DateTime? dt) {
    if (dt == null) return 'Seleccionar fecha y hora';
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final hh = hour12.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$dd/$mm/$yyyy $hh:$min $period';
  }

  Future<void> _pickFechaHora() async {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDate: now,
      locale: const Locale('es', 'MX'),
      helpText: 'Selecciona la fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      fieldHintText: 'dd/mm/aaaa',
      fieldLabelText: 'Fecha de entrega',
      errorFormatText: 'Formato de fecha invalido',
      errorInvalidText: 'Fecha fuera del rango permitido',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: isDark
              ? const ColorScheme.dark(
                  primary: AppColors.accentOrange,
                  surface: Color(0xFF1E1E1E),
                  onSurface: Colors.white,
                )
              : const ColorScheme.light(primary: AppColors.accentOrange),
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        ),
      ),
    );
    if (pickedDate == null) return;

    if (!mounted) return;

    final pickedTime = await _pickTime12h(
      initialTime: TimeOfDay.fromDateTime(_fechaHoraSello ?? now),
      isDark: isDark,
    );
    if (pickedTime == null) return;

    setState(() {
      _fechaHoraSello = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      _fechaHoraError = null;
    });
  }

  Future<TimeOfDay?> _pickTime12h({
    required TimeOfDay initialTime,
    required bool isDark,
  }) {
    var selectedHour = initialTime.hourOfPeriod == 0 ? 12 : initialTime.hourOfPeriod;
    var selectedMinute = initialTime.minute;
    var isPm = initialTime.period == DayPeriod.pm;

    return showDialog<TimeOfDay>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
            final textColor = isDark ? Colors.white : AppColors.textPrimary;
            final borderColor = isDark ? Colors.white12 : AppColors.cardBorder;
            final previewHour = selectedHour.toString().padLeft(2, '0');
            final previewMinute = selectedMinute.toString().padLeft(2, '0');

            return AlertDialog(
              backgroundColor: surfaceColor,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              title: Text(
                'Selecciona la hora',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: textColor, fontSize: 18),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: AppColors.accentOrange.withOpacity(isDark ? 0.16 : 0.1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.accentOrange.withOpacity(0.25)),
                    ),
                    child: Text(
                      '$previewHour:$previewMinute ${isPm ? 'PM' : 'AM'}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: AppColors.accentOrange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeDropdown(
                          label: 'Hora',
                          value: selectedHour,
                          values: List.generate(12, (index) => index + 1),
                          isDark: isDark,
                          borderColor: borderColor,
                          onChanged: (value) => setDialogState(() => selectedHour = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TimeDropdown(
                          label: 'Minuto',
                          value: selectedMinute,
                          values: List.generate(60, (index) => index),
                          isDark: isDark,
                          borderColor: borderColor,
                          formatter: (value) => value.toString().padLeft(2, '0'),
                          onChanged: (value) => setDialogState(() => selectedMinute = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _PeriodButton(
                          label: 'AM',
                          selected: !isPm,
                          onTap: () => setDialogState(() => isPm = false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PeriodButton(
                          label: 'PM',
                          selected: isPm,
                          onTap: () => setDialogState(() => isPm = true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              actions: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.white70 : AppColors.textSecondary,
                            side: BorderSide(color: borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text('Cancelar', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentOrange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            final hour24 = isPm
                                ? (selectedHour == 12 ? 12 : selectedHour + 12)
                                : (selectedHour == 12 ? 0 : selectedHour);
                            Navigator.pop(dialogContext, TimeOfDay(hour: hour24, minute: selectedMinute));
                          },
                          child: Text('Aceptar', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      File? pickedFile;
      if (source == ImageSource.camera) {
        pickedFile = await PhotoPicker.scanDocument();
      } else {
        pickedFile = await PhotoPicker.pickFromGallery();
      }

      if (pickedFile != null && mounted) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _fotoBytes = bytes;
          _fotoFileName = pickedFile!.path.split('/').last;
          _fotoFile = pickedFile;
        });
      }
    } catch (e) {
      print('Error seleccionando imagen: $e');
    }
  }

  Future<void> _enviar() async {
    final quantityValue = int.tryParse(_cantidadCtrl.text.trim()) ?? 0;
    setState(() {
      _cantidadError = quantityValue <= 0 ? 'La cantidad recibida debe ser mayor a 0' : null;
      _fechaHoraError = _fechaHoraSello == null ? 'Selecciona la fecha y hora de entrega' : null;
    });

    if (quantityValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('La cantidad recibida debe ser mayor a 0'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    if (_fechaHoraSello == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Selecciona la fecha y hora de entrega'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    if (_resultado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor selecciona un resultado'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final success = await ref.read(evidenceSubmissionProvider.notifier).submit(
          routeId: widget.routeId,
          os: widget.osFolio,
          result: _resultado!,
          quantity: quantityValue.toString(),
          observations: _comentariosCtrl.text,
          timestamp: _fechaHoraSello!.toIso8601String(),
          photoPath: _fotoFile?.path,
          photoBytes: _fotoBytes,
          photoFileName: _fotoFileName,
        );

    if (!mounted) return;

    if (success) {
      ref.invalidate(routeDetailProvider(widget.numGuia));
      ref.invalidate(pendingRoutesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evidencia enviada correctamente'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      final error = ref.read(evidenceSubmissionProvider).maybeWhen(
            error: (e, _) => e.toString(),
            orElse: () => 'Error al enviar evidencia',
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(evidenceSubmissionProvider).isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : AppColors.cardBorder),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.referenciaOR.isEmpty ? 'Referencia OR no disponible' : widget.referenciaOR,
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.accentOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.direccion,
                      style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.white70 : AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Folio OS: ${widget.osFolio}',
                style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.white70 : AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'PPZA: ${widget.ppza.isEmpty ? 'N/D' : widget.ppza}',
                style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.white70 : AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Fecha programada: ${widget.fechaProgramada.isEmpty ? 'N/D' : widget.fechaProgramada}',
                style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.white70 : AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Estado destino: ${widget.estadoDestino.isEmpty ? 'N/D' : widget.estadoDestino}',
                style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.white70 : AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Guia: ${widget.numGuia}',
                style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.white70 : AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Datos de Entrega',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.accentOrange),
        ),
        const SizedBox(height: 16),
        _buildInputLabel('Cantidad recibida', Icons.inventory_2_outlined),
        _buildTextField(
          isDark: isDark,
          controller: _cantidadCtrl,
          hint: 'Ej. 50 cajas',
          icon: Icons.numbers,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          errorText: _cantidadError,
          onChanged: (_) {
            final rawValue = _cantidadCtrl.text.trim();
            final value = int.tryParse(rawValue) ?? 0;
            setState(() {
              _cantidadError = rawValue.isNotEmpty && value <= 0
                  ? 'La cantidad recibida debe ser mayor a 0'
                  : null;
            });
          },
        ),
        const SizedBox(height: 24),
        _buildInputLabel('Fecha y Hora del sello', Icons.access_time),
        _buildDateSelector(),
        if (_fechaHoraError != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _fechaHoraError!,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _buildInputLabel('Resultado de entrega', Icons.check_circle_outline),
        Row(
          children: [
            Expanded(
              child: _ResultChip(
                label: 'Entregado',
                isSelected: _resultado == 'ENTREGA',
                color: Colors.green,
                icon: Icons.done_all,
                onTap: () => setState(() => _resultado = 'ENTREGA'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ResultChip(
                label: 'Rechazado',
                isSelected: _resultado == 'RECHAZO',
                color: Colors.red,
                icon: Icons.close_rounded,
                onTap: () => setState(() => _resultado = 'RECHAZO'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildInputLabel('Observaciones adicionales', Icons.edit_note_outlined),
        _buildTextField(
          isDark: isDark,
          controller: _comentariosCtrl,
          hint: 'Ej. Recibio guardia, faltaron 2 piezas...',
          maxLines: 3,
        ),
        const SizedBox(height: 32),
        Text(
          'Evidencia Visual',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.accentOrange),
        ),
        const SizedBox(height: 16),
        _buildPhotoCaptureArea(isDark),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isLoading ? null : _enviar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentOrange,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: AppColors.accentOrange.withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    'CONFIRMAR ENTREGA',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                  ),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildInputLabel(String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accentOrange),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required bool isDark,
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171717) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.cardBorder),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: GoogleFonts.poppins(fontSize: 14, color: isDark ? Colors.white : AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: isDark ? Colors.white38 : AppColors.textSecondary.withOpacity(0.5), fontSize: 13),
          prefixIcon: icon != null ? Icon(icon, size: 20, color: isDark ? Colors.white54 : AppColors.textSecondary) : null,
          border: InputBorder.none,
          errorText: errorText,
          errorStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasDate = _fechaHoraSello != null;

    return InkWell(
      onTap: _pickFechaHora,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF171717) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasDate ? AppColors.accentOrange : (isDark ? Colors.white12 : AppColors.cardBorder),
            width: hasDate ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.18 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withOpacity(isDark ? 0.16 : 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.event_available_rounded, color: AppColors.accentOrange, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasDate ? 'Fecha y hora seleccionada' : 'Seleccionar fecha y hora',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatearFechaHora(_fechaHoraSello),
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: hasDate
                          ? (isDark ? Colors.white : AppColors.textPrimary)
                          : (isDark ? Colors.white38 : AppColors.textSecondary),
                      fontWeight: hasDate ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF232323) : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white10 : AppColors.cardBorder),
              ),
              child: Text(
                hasDate ? 'Cambiar' : 'Elegir',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.accentOrange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCaptureArea(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171717) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.cardBorder, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          if (_fotoBytes != null || _fotoFile != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _fotoBytes != null
                      ? Image.memory(_fotoBytes!, height: 180, width: double.infinity, fit: BoxFit.cover)
                      : Image.file(_fotoFile!, height: 180, width: double.infinity, fit: BoxFit.cover),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: CircleAvatar(
                    backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() {
                        _fotoFile = null;
                        _fotoBytes = null;
                        _fotoFileName = null;
                      }),
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                const Icon(Icons.add_a_photo_outlined, size: 48, color: AppColors.accentOrange),
                const SizedBox(height: 12),
                Text(
                  'Captura la foto de la entrega',
                  style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white70 : AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _PhotoBtn(
                  isDark: isDark,
                  label: 'Camara',
                  icon: Icons.camera_alt_rounded,
                  onTap: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PhotoBtn(
                  isDark: isDark,
                  label: 'Galeria',
                  icon: Icons.image_rounded,
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ResultChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : (isDark ? Colors.white10 : AppColors.cardBorder), width: 1.5),
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeDropdown extends StatelessWidget {
  final String label;
  final int value;
  final List<int> values;
  final bool isDark;
  final Color borderColor;
  final String Function(int value)? formatter;
  final ValueChanged<int> onChanged;

  const _TimeDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.isDark,
    required this.borderColor,
    required this.onChanged,
    this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isDark ? Colors.white70 : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF171717) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.18 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF232323) : Colors.white,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.accentOrange),
              style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w800, fontSize: 16),
              items: values
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: item,
                      child: Text(formatter?.call(item) ?? item.toString()),
                    ),
                  )
                  .toList(),
              onChanged: (next) {
                if (next != null) onChanged(next);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentOrange : (isDark ? const Color(0xFF171717) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.accentOrange : (isDark ? Colors.white12 : AppColors.cardBorder)),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accentOrange.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: selected ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary),
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _PhotoBtn extends StatelessWidget {
  final bool isDark;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PhotoBtn({required this.isDark, required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? const Color(0xFF232323) : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
        elevation: 0,
        side: BorderSide(color: isDark ? Colors.white10 : AppColors.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
