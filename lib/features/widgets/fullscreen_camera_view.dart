// lib/features/auth/presentation/fullscreen_camera_view.dart
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class FullscreenCameraView extends StatefulWidget {
  const FullscreenCameraView({super.key});

  @override
  State<FullscreenCameraView> createState() => _FullscreenCameraViewState();
}

class _FullscreenCameraViewState extends State<FullscreenCameraView> {
  CameraController? _controller;
  bool _inicializando = true;
  bool _tomando = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _initCamara();
  }

  Future<void> _initCamara() async {
    try {
      final cameras = await availableCameras();

      // preferimos cámara trasera si existe
      CameraDescription cam;
      if (cameras.any((c) => c.lensDirection == CameraLensDirection.back)) {
        cam = cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
        );
      } else {
        cam = cameras.first; // fallback
      }

      final controller = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _inicializando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'No se pudo iniciar la cámara: $e';
        _inicializando = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _tomarFoto() async {
    if (_tomando || _controller == null) return;
    setState(() => _tomando = true);

    try {
      final foto = await _controller!.takePicture();
      if (!mounted) return;
      Navigator.pop(context, foto.path); // devolvemos el path
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al tomar foto: $e')),
      );
      setState(() => _tomando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // errores tempranos
    if (_errorMsg != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: Text(
                _errorMsg!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      );
    }

    if (_inicializando || _controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final previewSize = _controller!.value.previewSize!;
    final previewWidth = previewSize.width;
    final previewHeight = previewSize.height;

    // Queremos cubrir toda la pantalla con la cámara sin deformarla.
    // Lo que hacemos: metemos el CameraPreview en un FittedBox con BoxFit.cover
    // y le damos el tamaño "natural" (height = previewHeight, width = previewWidth)
    // dentro de un SizedBox que está rotado si hace falta.
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: previewWidth / previewHeight,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: previewWidth,
                  height: previewHeight,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),

          // Cerrar
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Botón disparo
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: FloatingActionButton(
                backgroundColor: Colors.orange,
                onPressed: _tomarFoto,
                child: _tomando
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.camera_alt, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
