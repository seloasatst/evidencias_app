import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seloasa_evidencias/ui/theme/app_colors.dart';
import 'package:seloasa_evidencias/core/services/notification_service.dart';
import 'package:seloasa_evidencias/features/home/presentation/route_provider.dart';
import 'package:seloasa_evidencias/features/home/data/route_models.dart';
import '../../auth/presentation/auth_provider.dart';

class DispersionRequestScreen extends ConsumerStatefulWidget {
  const DispersionRequestScreen({super.key});

  @override
  ConsumerState<DispersionRequestScreen> createState() => _DispersionRequestScreenState();
}

class _DispersionRequestScreenState extends ConsumerState<DispersionRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardController = TextEditingController();
  bool _isLoading = false;
  String? _selectedRouteId;
  final _manualRouteController = TextEditingController();

  @override
  void dispose() {
    _cardController.dispose();
    _manualRouteController.dispose();
    super.dispose();
  }

  // Formatea el número de la tarjeta en grupos de 4 dígitos separados por espacio
  String _formatCardNumber(String rawNumber) {
    if (rawNumber.isEmpty) return '•••• •••• •••• ••••';
    
    final buffer = StringBuffer();
    for (int i = 0; i < rawNumber.length; i++) {
      buffer.write(rawNumber[i]);
      final nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != rawNumber.length) {
        buffer.write(' ');
      }
    }
    
    // Rellenar lo restante
    final expectedLengthWithSpaces = 19;
    final currentLength = buffer.length;
    if (currentLength < expectedLengthWithSpaces) {
      final dotsNeeded = 16 - rawNumber.length;
      for (int i = 0; i < dotsNeeded; i++) {
        if ((rawNumber.length + i) % 4 == 0 && i != 0) {
          buffer.write(' ');
        }
        buffer.write('•');
      }
    }
    
    return buffer.toString();
  }

  Future<void> _scanCard() async {
    // Esconde el teclado antes de cambiar de pantalla
    FocusScope.of(context).unfocus();
    
    final result = await context.pushNamed<String>('card_scanner');
    if (result != null && mounted) {
      setState(() {
        _cardController.text = result;
      });
      _showNotification(
        title: 'Tarjeta Escaneada',
        message: 'Número cargado correctamente en la solicitud.',
        isSuccess: true,
      );
    }
  }

  void _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    // Simular llamada al servidor
    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;
    setState(() => _isLoading = false);

    final cardDigits = _cardController.text.trim();
    
    // Regla de simulación de error: si termina en 0000, simula error
    final bool isError = cardDigits.endsWith('0000');

    if (isError) {
      _showNotification(
        title: 'Error de Dispersión',
        message: 'No se pudo registrar la tarjeta. El banco rechazó la vinculación.',
        isSuccess: false,
      );
      
      NotificationService.showLocalNotification(
        id: 102,
        title: 'Dispersión: Falló Registro',
        body: 'El banco rechazó la vinculación de tu tarjeta.',
      );
    } else {
      _showNotification(
        title: 'Registro Exitoso',
        message: 'La tarjeta se vinculó correctamente al sistema de dispersión.',
        isSuccess: true,
      );
      
      NotificationService.showLocalNotification(
        id: 101,
        title: 'Dispersión: Registro Exitoso',
        body: 'Tarjeta terminada en ${cardDigits.length > 4 ? cardDigits.substring(cardDigits.length - 4) : cardDigits} vinculada correctamente.',
      );

      final pendingRoutesState = ref.read(pendingRoutesProvider);
      final List<RouteModel> routesList = pendingRoutesState.routes.value ?? [];
      
      String routeDisplay = 'RUTA GENERAL';
      if (_selectedRouteId == 'RUTA_MANUAL') {
        routeDisplay = 'MANUAL: ${_manualRouteController.text.trim().toUpperCase()}';
      } else {
        final selectedRoute = routesList.firstWhere(
          (r) => r.routeId == _selectedRouteId,
          orElse: () => RouteModel(id: '', routeId: _selectedRouteId ?? '', coverage: 'RUTA SELECCIONADA'),
        );
        routeDisplay = '${selectedRoute.routeId} - ${selectedRoute.coverage}';
      }

      context.pushNamed(
        'dispersion_success',
        extra: {
          'tarjeta': _formatCardNumber(cardDigits.replaceAll(' ', '')),
          'ruta': routeDisplay,
        },
      );
    }
  }

  // Muestra una notificación flotante estilo push in-app
  void _showNotification({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => _FloatingNotificationBanner(
        title: title,
        message: message,
        isSuccess: isSuccess,
        onDismiss: () {
          try {
            overlayEntry.remove();
          } catch (_) {}
        },
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    // Desaparece automáticamente después de 3.5 segundos
    Future.delayed(const Duration(milliseconds: 3500), () {
      try {
        overlayEntry.remove();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final authState = ref.watch(authStateProvider);
    final String fullName = authState.user?.name ?? authState.user?.username ?? 'OPERADOR RUTA';
    final String operatorName = fullName.toUpperCase();

    final pendingRoutesState = ref.watch(pendingRoutesProvider);
    final List<RouteModel> routesList = pendingRoutesState.routes.value ?? [];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Solicitar Dispersión',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Tarjeta virtual dinámica
                    _buildVirtualCard(operatorName),
                    const SizedBox(height: 32),
                    
                    // Título de formulario
                    Text(
                      'Datos de la Tarjeta',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentOrange,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. Selector de Ruta
                    Text(
                      'Ruta de la Dispersión',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedRouteId,
                      dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      isExpanded: true,
                      style: GoogleFonts.poppins(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.alt_route_rounded, color: AppColors.accentOrange),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.white10 : AppColors.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.white10 : AppColors.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.accentOrange, width: 1.5),
                        ),
                      ),
                      hint: Text(
                        'Selecciona una ruta',
                        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.normal),
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: 'RUTA_MANUAL',
                          child: Text(
                            'RUTA MANUAL',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                        ),
                        ...routesList.map((route) {
                          return DropdownMenuItem<String>(
                            value: route.routeId,
                            child: Text(
                              '${route.routeId} - ${route.coverage}',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                          );
                        }),
                      ],
                      onChanged: _isLoading ? null : (value) {
                        setState(() {
                          _selectedRouteId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor selecciona una ruta';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Si se selecciona "RUTA MANUAL", desplegar el campo de texto manual
                    if (_selectedRouteId == 'RUTA_MANUAL') ...[
                      Text(
                        'Destino / Detalles de la Ruta',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _manualRouteController,
                        enabled: !_isLoading,
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.pin_drop_rounded, color: AppColors.accentOrange),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          hintText: 'Ej. Oficina Central / Sucursal Sur',
                          hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.normal),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? Colors.white10 : AppColors.cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? Colors.white10 : AppColors.cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.accentOrange, width: 1.5),
                          ),
                        ),
                        validator: (value) {
                          if (_selectedRouteId == 'RUTA_MANUAL' && (value == null || value.trim().isEmpty)) {
                            return 'Por favor especifica a dónde vas';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 2. Campo Tarjeta con Escáner
                    Text(
                      'Número de Tarjeta (16 dígitos)',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _cardController,
                      keyboardType: TextInputType.number,
                      maxLength: 16,
                      enabled: !_isLoading,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (val) {
                        setState(() {}); // Actualiza la tarjeta virtual
                      },
                      style: GoogleFonts.poppins(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        prefixIcon: const Icon(Icons.credit_card_rounded, color: AppColors.accentOrange),
                        suffixIcon: InkWell(
                          onTap: _isLoading ? null : _scanCard,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppColors.accentOrange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.qr_code_scanner_rounded, size: 20, color: AppColors.accentOrange),
                                const SizedBox(width: 4),
                                Text(
                                  'ESCANEAR',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.accentOrange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        hintText: '0000000000000000',
                        hintStyle: GoogleFonts.poppins(color: Colors.grey, letterSpacing: 1.0, fontWeight: FontWeight.normal),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.white10 : AppColors.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.white10 : AppColors.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.accentOrange, width: 1.5),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.white10 : AppColors.cardBorder.withValues(alpha: 0.5)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor ingresa o escanea una tarjeta';
                        }
                        if (value.replaceAll(' ', '').length != 16) {
                          return 'El número de tarjeta debe tener 16 dígitos';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '* Para simular un error en el registro, ingresa una tarjeta que termine en "0000".',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white38 : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // 3. Botón de envío
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: _isLoading ? 0 : 4,
                          shadowColor: AppColors.accentOrange.withValues(alpha: 0.4),
                        ),
                        child: Text(
                          'SOLICITAR DISPERSIÓN',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          
          // Pantalla de carga superpuesta
          if (_isLoading)
            _buildLoadingOverlay(isDark),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay(bool isDark) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.accentOrange),
              const SizedBox(height: 20),
              Text(
                'Procesando solicitud...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVirtualCard(String operatorName) {
    final cleanCardNumber = _cardController.text.trim().replaceAll(' ', '');
    final formatted = _formatCardNumber(cleanCardNumber);

    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1B3B23), // AppColors.primaryGreen
            Color(0xFF152D1C),
            Color(0xFFE34D26), // AppColors.accentOrange
          ],
          stops: [0.0, 0.65, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B3B23).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -50,
            bottom: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            left: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TARJETA DE DISPERSIÓN',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2C94C).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF2C94C), Color(0xFFF2994A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 4,
                            bottom: 4,
                            left: 10,
                            right: 10,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black12, width: 0.5),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 4,
                            right: 4,
                            top: 8,
                            bottom: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black12, width: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                Text(
                  formatted,
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white,
                    fontSize: 22,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TITULAR',
                            style: GoogleFonts.poppins(
                              color: Colors.white60,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            operatorName,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'VENCE',
                          style: GoogleFonts.poppins(
                            color: Colors.white60,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '12/30',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        Text(
                          'One',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        Text(
                          'Route',
                          style: GoogleFonts.poppins(
                            color: AppColors.accentOrange,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            height: 0.8,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Banner flotante animado para notificaciones tipo push in-app
class _FloatingNotificationBanner extends StatefulWidget {
  final String title;
  final String message;
  final bool isSuccess;
  final VoidCallback onDismiss;

  const _FloatingNotificationBanner({
    required this.title,
    required this.message,
    required this.isSuccess,
    required this.onDismiss,
  });

  @override
  State<_FloatingNotificationBanner> createState() => _FloatingNotificationBannerState();
}

class _FloatingNotificationBannerState extends State<_FloatingNotificationBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();
    
    // Iniciar animación de salida antes de descartarse
    Future.delayed(const Duration(milliseconds: 3100), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topSafeArea = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: topSafeArea + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isSuccess 
                  ? Colors.green.withValues(alpha: 0.4) 
                  : Colors.red.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.isSuccess 
                      ? Colors.green.withValues(alpha: 0.1) 
                      : Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.isSuccess 
                      ? Icons.check_circle_outline_rounded 
                      : Icons.error_outline_rounded,
                    color: widget.isSuccess ? Colors.green : Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: isDark ? Colors.white70 : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                  onPressed: () {
                    _controller.reverse().then((_) => widget.onDismiss());
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
