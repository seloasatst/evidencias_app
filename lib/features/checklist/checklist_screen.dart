import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seloasa_evidencias/ui/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../home/presentation/route_provider.dart';

enum ChecklistType { salida, entrada }

final unitsProvider = FutureProvider<List<String>>((ref) async {
  return ref.read(routeServiceProvider).getUnits();
});

class ChecklistScreen extends ConsumerStatefulWidget {
  final String? initialRouteId;
  final String? initialUnidad;
  final ChecklistType type;

  const ChecklistScreen({
    super.key,
    this.initialRouteId,
    this.initialUnidad,
    this.type = ChecklistType.salida,
  });

  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _routeController = TextEditingController();
  final TextEditingController _obsController = TextEditingController();
  final List<Offset> _damagePoints = [];

  String? _selectedUnit;

  @override
  void initState() {
    super.initState();
    _routeController.text = widget.initialRouteId ?? '';
    _selectedUnit = widget.initialUnidad;
  }

  @override
  void dispose() {
    _unitController.dispose();
    _routeController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  final Map<String, List<Map<String, dynamic>>> checklistData = {
    'Estado de la Unidad': [
      {'item': 'Nivel de aceite motor', 'status': null},
      {'item': 'Nivel de anticongelante', 'status': null},
      {'item': 'Nivel de líquido de frenos', 'status': null},
      {'item': 'Fuga de Fluidos', 'status': null},
      {'item': 'Inspección de Bandas', 'status': null},
      {'item': 'Inspección de Llantas', 'status': null},
    ],
    'Funcionalidad': [
      {'item': 'Duplicado de llave', 'status': null},
      {'item': 'Luces frontales', 'status': null},
      {'item': 'Espejos retrovisores', 'status': null},
      {'item': 'Direccionales - Intermitentes', 'status': null},
      {'item': 'Limpiaparabrisas', 'status': null},
    ],
    'Documentación': [
      {'item': 'Placas legibles', 'status': null},
      {'item': 'Tarjeta de circulación', 'status': null},
      {'item': 'Bitácora de viaje', 'status': null},
    ],
    'Accesorios y Seguridad': [
      {'item': 'Gato hidráulico', 'status': null},
      {'item': 'Llave de tuercas', 'status': null},
      {'item': 'Extintor vigente', 'status': null},
      {'item': 'Triángulos reflejantes', 'status': null},
    ],
  };

  void _addDamagePoint(TapUpDetails details) {
    setState(() {
      _damagePoints.add(details.localPosition);
    });
  }

  void _clearDamagePoints() {
    setState(() {
      _damagePoints.clear();
    });
  }

  Future<void> _saveChecklist() async {
    final service = ref.read(routeServiceProvider);
    
    final Map<String, dynamic> results = {};
    checklistData.forEach((section, items) {
      results[section] = items.map((i) => {
        'item': i['item'],
        'status': i['status'],
      }).toList();
    });

    results['damage_points'] = _damagePoints.map((p) => {'x': p.dx, 'y': p.dy}).toList();

    final success = await service.sendChecklist(
      routeId: _routeController.text.isEmpty ? 'GENERAL' : _routeController.text,
      unit: _selectedUnit ?? '',
      type: widget.type == ChecklistType.salida ? 'SALIDA' : 'ENTRADA',
      data: results,
      observations: _obsController.text,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inspección guardada correctamente'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al guardar inspección'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.type == ChecklistType.salida ? 'Inspección de Salida' : 'Inspección de Entrada';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Información de Unidad"),
            const SizedBox(height: 16),
            _buildInfoCard(),
            
            const SizedBox(height: 32),
            _buildDamageDiagramSection(),
            
            const SizedBox(height: 32),
            ...checklistData.entries.map((e) => _buildChecklistSection(e.key, e.value)),
            
            const SizedBox(height: 32),
            _buildSectionHeader("Observaciones Adicionales"),
            const SizedBox(height: 12),
            _buildObservationsField(),
            
            const SizedBox(height: 40),
            _buildSaveButton(),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.accentOrange),
    );
  }

  Widget _buildInfoCard() {
    final String routeDisplay = _routeController.text.isEmpty ? "Inspección General" : _routeController.text;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.route_outlined, color: isDark ? Colors.white : AppColors.accentOrange, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Ruta: $routeDisplay", 
                  style: GoogleFonts.poppins(
                    fontSize: 14, 
                    fontWeight: FontWeight.bold, 
                    color: _routeController.text.isEmpty 
                        ? (isDark ? Colors.white54 : AppColors.textSecondary)
                        : (isDark ? Colors.white : AppColors.textPrimary)
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 32, thickness: 1),
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, color: isDark ? Colors.white : AppColors.accentOrange, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: ref.watch(unitsProvider).when(
                  data: (units) {
                    if (units.isEmpty) return Text("No hay unidades disponibles", style: TextStyle(color: isDark ? Colors.white70 : Colors.black));
                    if (_selectedUnit == null && units.isNotEmpty) {
                      _selectedUnit = units.first;
                    }
                    return DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedUnit,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white : AppColors.accentOrange),
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary),
                        items: units.map((String unit) {
                          return DropdownMenuItem<String>(
                            value: unit,
                            child: Text(unit),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedUnit = newValue;
                          });
                        },
                      ),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => Text("Error al cargar unidades", style: TextStyle(color: isDark ? Colors.red.shade300 : Colors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDamageDiagramSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader("Mapa de Daños"),
            if (_damagePoints.isNotEmpty)
              TextButton.icon(
                onPressed: _clearDamagePoints,
                icon: const Icon(Icons.refresh, size: 16, color: Colors.red),
                label: const Text("Limpiar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text("Toca el diagrama para marcar daños externos", style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white70 : AppColors.textSecondary)),
        const SizedBox(height: 16),
        Container(
          height: 240,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white10 : AppColors.cardBorder),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.02), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: GestureDetector(
              onTapUp: _addDamagePoint,
              child: Stack(
                children: [
                  Center(child: Image.asset('assets/images/truck_diagram.jpg', fit: BoxFit.contain)),
                  ..._damagePoints.map((p) => Positioned(
                    left: p.dx - 12,
                    top: p.dy - 12,
                    child: const Icon(Icons.close, color: Colors.red, size: 24, shadows: [Shadow(color: Colors.white, blurRadius: 4)]),
                  )),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistSection(String title, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: _buildSectionHeader(title),
        ),
        ...items.map((item) => _buildChecklistItem(item)).toList(),
      ],
    );
  }

  Widget _buildChecklistItem(Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.cardBorder.withOpacity(0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item['item'],
              style: GoogleFonts.poppins(
                fontSize: 13, 
                fontWeight: FontWeight.w600, 
                color: isDark ? Colors.white : AppColors.textPrimary
              ),
            ),
          ),
          _buildToggleButton(item, true, "SÍ", Colors.green),
          const SizedBox(width: 8),
          _buildToggleButton(item, false, "NO", Colors.red),
        ],
      ),
    );
  }

  Widget _buildToggleButton(Map<String, dynamic> item, bool value, String label, Color color) {
    final bool isSelected = item['status'] == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => setState(() => item['status'] = value),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color : (isDark ? Colors.white10 : AppColors.cardBorder), width: 1.5),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildObservationsField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.cardBorder),
      ),
      child: TextField(
        controller: _obsController,
        maxLines: 3,
        style: GoogleFonts.poppins(fontSize: 14, color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: "Escribe aquí cualquier detalle o anomalía encontrada...",
          hintStyle: GoogleFonts.poppins(color: isDark ? Colors.white38 : AppColors.textSecondary.withOpacity(0.5), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _saveChecklist,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentOrange,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: AppColors.accentOrange.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text("FINALIZAR REVISIÓN", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      ),
    );
  }
}
