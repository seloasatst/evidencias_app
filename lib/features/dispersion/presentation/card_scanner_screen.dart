import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:seloasa_evidencias/ui/theme/app_colors.dart';

class CardScannerScreen extends StatefulWidget {
  const CardScannerScreen({super.key});

  @override
  State<CardScannerScreen> createState() => _CardScannerScreenState();
}

class _CardScannerScreenState extends State<CardScannerScreen> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _inicializando = true;
  bool _hasCamera = false;
  String? _errorMsg;
  bool _disposed = false;
  bool _isAnalyzing = false;

  // ML Kit Text Recognizer
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  // Animaciones para la línea de escáner
  late AnimationController _scannerAnimationController;
  late Animation<double> _scannerAnimation;

  // Estado del escaneo
  String _scanStatus = 'Buscando tarjeta...';
  bool _cardDetected = false;
  String _detectedCardNumber = '';
  double _scanProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initScannerAnimation();
    _initCamara();
  }

  void _initScannerAnimation() {
    _scannerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scannerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scannerAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _initCamara() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        setState(() {
          _hasCamera = false;
          _inicializando = false;
        });
        _startSimulatedScan();
        return;
      }

      CameraDescription cam;
      if (cameras.any((c) => c.lensDirection == CameraLensDirection.back)) {
        cam = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back);
      } else {
        cam = cameras.first;
      }

      final controller = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      if (_disposed) return;

      setState(() {
        _controller = controller;
        _hasCamera = true;
        _inicializando = false;
      });

      _startLiveAnalysis();
    } catch (e) {
      if (_disposed) return;
      setState(() {
        _hasCamera = false;
        _inicializando = false;
        _errorMsg = 'Error cámara: $e. Activando modo simulado.';
      });
      _startSimulatedScan();
    }
  }

  // Bucle de análisis OCR en tiempo real usando capturas periódicas
  Future<void> _startLiveAnalysis() async {
    if (_disposed || _isAnalyzing) return;
    _isAnalyzing = true;

    while (!_disposed && !_cardDetected) {
      if (_controller == null || !_controller!.value.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }

      try {
        final file = await _controller!.takePicture();
        if (_disposed || _cardDetected) {
          try {
            await File(file.path).delete();
          } catch (_) {}
          break;
        }

        if (!mounted) return;
        setState(() {
          _scanStatus = 'Analizando imagen...';
        });

        final inputImage = InputImage.fromFilePath(file.path);
        final recognizedText = await _textRecognizer.processImage(inputImage);

        // Eliminamos el archivo temporal inmediatamente para no llenar memoria
        try {
          await File(file.path).delete();
        } catch (_) {}

        final cardNum = _extractCardNumber(recognizedText);

        if (cardNum != null && cardNum.length == 16) {
          if (!mounted) return;
          setState(() {
            _scanStatus = '¡Tarjeta detectada!';
            _cardDetected = true;
            _detectedCardNumber = cardNum;
            _scanProgress = 1.0;
          });
          _scannerAnimationController.stop();
          break;
        } else {
          if (!mounted) return;
          setState(() {
            _scanStatus = 'Alinea la tarjeta en el cuadro...';
            // Progreso dinámico sutil para retroalimentación
            _scanProgress = 0.2 + (math.Random().nextDouble() * 0.4);
          });
        }
      } catch (e) {
        debugPrint('Error en bucle de escaneo: $e');
      }

      // Esperar 1.2 segundos antes de volver a capturar para no saturar hardware
      await Future.delayed(const Duration(milliseconds: 1200));
    }
    _isAnalyzing = false;
  }

  // Intenta extraer exactamente 16 dígitos de la tarjeta
  String? _extractCardNumber(RecognizedText recognizedText) {
    // 1. Buscar en líneas independientes primero (donde los números suelen agruparse)
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        // Limpiamos espacios, guiones y caracteres no numéricos
        final cleanLine = line.text.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanLine.length == 16) {
          return cleanLine;
        }
      }
    }

    // 2. Si no lo encuentra en una única línea, busca combinando todos los bloques
    // por si el OCR los separó en distintas cajas
    final cleanAll = recognizedText.text.replaceAll(RegExp(r'[^0-9]'), '');
    final match = RegExp(r'\d{16}').firstMatch(cleanAll);
    if (match != null) {
      return match.group(0);
    }

    return null;
  }

  // Caída a escaneo simulado (para emuladores sin cámara o fallos de permisos)
  void _startSimulatedScan() {
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (_disposed || _cardDetected) return;
      setState(() {
        _scanStatus = 'Tarjeta detectada. Enfocando...';
        _scanProgress = 0.4;
      });
    });

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (_disposed || _cardDetected) return;
      setState(() {
        _scanStatus = 'Leyendo números...';
        _scanProgress = 0.7;
      });
    });

    Future.delayed(const Duration(milliseconds: 3500), () {
      if (_disposed || _cardDetected) return;
      setState(() {
        _scanStatus = '¡Tarjeta escaneada exitosamente!';
        _scanProgress = 1.0;
        _cardDetected = true;
        _detectedCardNumber = '45561234${_generateRandomDigits(8)}';
      });
      _scannerAnimationController.stop();
    });
  }

  String _generateRandomDigits(int length) {
    final rand = math.Random();
    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      buffer.write(rand.nextInt(10));
    }
    return buffer.toString();
  }

  String _formatCardWithSpaces(String raw) {
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      buffer.write(raw[i]);
      final nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != raw.length) {
        buffer.write(' ');
      }
    }
    return buffer.toString();
  }

  @override
  void dispose() {
    _disposed = true;
    _controller?.dispose();
    _scannerAnimationController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardWidth = size.width * 0.85;
    final cardHeight = cardWidth * 0.63; // Relación de aspecto estándar de tarjeta
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Fondo: Cámara en vivo o placeholder animado
          if (_inicializando)
            const Center(child: CircularProgressIndicator(color: AppColors.accentOrange))
          else if (_hasCamera && _controller != null && _controller!.value.isInitialized)
            Center(
              child: CameraPreview(_controller!),
            )
          else
            _buildSimulatorBackground(),

          // 2. Capa de recorte oscuro (Overlay)
          Positioned.fill(
            child: _buildScannerOverlay(cardWidth, cardHeight),
          ),

          // Borde verde del escáner activo
          Center(
            child: Container(
              width: cardWidth,
              height: cardHeight,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _cardDetected ? Colors.green : Colors.greenAccent,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // 3. Interfaz de usuario superior (Instrucciones)
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'ESCÁNER DE TARJETA',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _cardDetected 
                      ? 'Revisa los datos leídos de tu tarjeta' 
                      : 'Coloca el frente de tu tarjeta de débito dentro del recuadro verde.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Animación de escaneo láser (sólo si no se ha detectado la tarjeta)
          if (!_cardDetected && !_inicializando)
            Positioned(
              left: (size.width - cardWidth) / 2,
              top: 0,
              child: AnimatedBuilder(
                animation: _scannerAnimation,
                builder: (context, child) {
                  final topOffset = (size.height - cardHeight) / 2 + (_scannerAnimation.value * cardHeight);
                  return Transform.translate(
                    offset: Offset(0, topOffset),
                    child: Container(
                      width: cardWidth,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.withValues(alpha: 0.8),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // 5. Panel de estado inferior y resultados
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        _cardDetected ? Icons.check_circle : Icons.hourglass_empty_rounded,
                        color: _cardDetected ? Colors.green : AppColors.accentOrange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _scanStatus,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _scanProgress,
                    backgroundColor: Colors.white10,
                    color: _cardDetected ? Colors.green : AppColors.accentOrange,
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 24),

                  if (_cardDetected) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NÚMERO DETECTADO',
                            style: GoogleFonts.poppins(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Center(
                            child: Text(
                              _formatCardWithSpaces(_detectedCardNumber),
                              style: GoogleFonts.shareTechMono(
                                color: Colors.greenAccent,
                                fontSize: 24,
                                letterSpacing: 2.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _cardDetected = false;
                                _scanStatus = 'Buscando tarjeta...';
                                _scanProgress = 0.0;
                                _initScannerAnimation();
                                if (_hasCamera) {
                                  _startLiveAnalysis();
                                } else {
                                  _startSimulatedScan();
                                }
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white30),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'VOLVER A LEER',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context, _detectedCardNumber);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'USAR TARJETA',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Ingresar tarjeta manualmente',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            decoration: TextDecoration.underline,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Efecto de flash al capturar la tarjeta
          if (_scanProgress == 1.0 && _detectedCardNumber.isNotEmpty)
            _FlashEffect(),
        ],
      ),
    );
  }

  Widget _buildSimulatorBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F0F1A), Color(0xFF1E1E2E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white24,
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              'Simulación de Cámara de Escaneo',
              style: GoogleFonts.poppins(
                color: Colors.white30,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_errorMsg != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _errorMsg!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white24,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScannerOverlay(double width, double height) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withValues(alpha: 0.75),
        BlendMode.srcOut,
      ),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Center(
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlashEffect extends StatefulWidget {
  @override
  State<_FlashEffect> createState() => _FlashEffectState();
}

class _FlashEffectState extends State<_FlashEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = Tween<double>(begin: 0.8, end: 0.0).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        if (_opacity.value == 0.0) return const SizedBox.shrink();
        return Positioned.fill(
          child: Container(
            color: Colors.white.withValues(alpha: _opacity.value),
          ),
        );
      },
    );
  }
}
