import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../data/models/attendance_record.dart';
import '../data/services/face_liveness_service.dart';
import '../data/services/geofence_service.dart';
import '../data/services/location_service.dart';
import '../data/services/network_time_service.dart';
import '../data/services/security_service.dart';
import '../utils/time_utils.dart';
import '../../../../ui/theme/app_colors.dart';
import 'providers/checador_providers.dart';

class CameraCheckinScreen extends ConsumerStatefulWidget {
  final AttendanceType type;

  const CameraCheckinScreen({super.key, required this.type});

  @override
  ConsumerState<CameraCheckinScreen> createState() => _CameraCheckinScreenState();
}

class _CameraCheckinScreenState extends ConsumerState<CameraCheckinScreen> {
  CameraController? _backController;
  CameraController? _frontController;
  bool _isBackReady = false;
  bool _isFrontReady = false;
  bool _frontInitFailed = false;
  bool _isProcessing = false;
  bool _isDetectingFace = false;

  final FaceLivenessService _faceService = FaceLivenessService();
  FaceLivenessState _livenessState = FaceLivenessState.searching;

  String? _securityBlockingError;

  LocationResult? _currentLocation;
  String? _locationError;
  GeofenceCheckResult? _geofenceResult;

  final bool _isOvertimeSelected = false;
  final TextEditingController _overtimeReasonController = TextEditingController();

  Timer? _liveTimer;
  Timer? _livenessTimer;
  DateTime _currentTime = NetworkTimeService.getRealTime();

  @override
  void initState() {
    super.initState();
    _initCameras();
    _auditSecurityAndDevice();
    _fetchLocation();

    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = NetworkTimeService.getRealTime();
        });
      }
    });
  }

  Future<void> _auditSecurityAndDevice() async {
    setState(() {
      _securityBlockingError = null;
    });

    try {
      final integrity = await SecurityService.checkDeviceIntegrity();
      if (!integrity.isSecure) {
        if (mounted) {
          setState(() {
            _securityBlockingError = integrity.failureReason;
          });
        }
        return;
      }

      try {
        final serverTime = await NetworkTimeService.ensureServerTimeSynced();
        if (mounted) {
          setState(() {
            _currentTime = serverTime;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _securityBlockingError = e.toString();
          });
        }
        return;
      }
    } catch (_) {
      // Ignorar errores menores
    }
  }

  Future<void> _initCameras() async {
    CameraController? front;

    try {
      final available = await availableCameras();
      final frontList = available
          .where((c) => c.lensDirection == CameraLensDirection.front)
          .toList();

      for (final cam in frontList) {
        front = await _tryInitialize(cam, isFront: true);
        if (front != null) break;
      }

      if (!mounted) {
        front?.dispose();
        return;
      }

      setState(() {
        _frontController = front;
        _isFrontReady = front != null;
        _frontInitFailed = front == null;
        _backController = null;
        _isBackReady = false;
      });

      if (_isFrontReady) {
        _startLivenessMonitoring();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo acceder a la cámara frontal del dispositivo.'),
          ),
        );
      }
    } catch (e) {
      front?.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al inicializar la cámara: $e')),
        );
      }
    }
  }

  Future<CameraController?> _tryInitialize(
    CameraDescription camera, {
    required bool isFront,
  }) async {
    final controller = CameraController(
      camera,
      isFront ? ResolutionPreset.low : ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      return controller;
    } catch (_) {
      controller.dispose();
      return null;
    }
  }

  void _startLivenessMonitoring() {
    _livenessTimer?.cancel();
    _livenessTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      _detectFaceFromFront();
    });
  }

  Future<void> _detectFaceFromFront() async {
    final front = _frontController;
    if (_isDetectingFace ||
        _isProcessing ||
        front == null ||
        !front.value.isInitialized ||
        front.value.isTakingPicture ||
        !mounted) {
      return;
    }

    _isDetectingFace = true;
    try {
      final temp = await getTemporaryDirectory();
      final shot = await front.takePicture();
      final file = await File(shot.path).copy(
        '${temp.path}/liveness_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await File(shot.path).delete();

      final state = await _faceService.analyzePhoto(file);
      await file.delete();

      if (mounted) {
        setState(() {
          _livenessState = state;
        });
      }
    } catch (_) {
    } finally {
      _isDetectingFace = false;
    }
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _locationError = null;
    });

    try {
      final loc = await LocationService.getCurrentRealLocation();
      GeofenceService.clearCache();
      final geo = await GeofenceService.validateLocation(
        userLatitude: loc.latitude,
        userLongitude: loc.longitude,
      );

      if (mounted) {
        setState(() {
          _currentLocation = loc;
          _geofenceResult = geo;
        });
      }
    } on FakeGpsException catch (e) {
      if (mounted) {
        setState(() {
          _locationError = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Error al obtener GPS: $e';
        });
      }
    }
  }

  Future<void> _captureAndSave() async {
    final back = _backController;
    final front = _frontController;
    final isBackReady = back != null && back.value.isInitialized;
    final isFrontReady = front != null && front.value.isInitialized;

    if ((!isBackReady && !isFrontReady) || _isProcessing) {
      return;
    }

    _livenessTimer?.cancel();

    setState(() {
      _isProcessing = true;
    });

    try {
      if (_currentLocation == null) {
        await _fetchLocation();
        if (_currentLocation == null) {
          throw Exception(_locationError ?? 'Ubicación GPS no disponible');
        }
      }

      // Se permiten los registros siempre, almacenando las coordenadas GPS reales capturadas.

      final tempDir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;

      String? photoPath;
      String? selfiePath;

      if (isBackReady) {
        try {
          final shot = await back.takePicture();
          final file = await File(shot.path).copy(
            '${tempDir.path}/checador_${widget.type.dbValue}_$stamp.jpg',
          );
          await File(shot.path).delete();
          photoPath = file.path;
        } catch (_) {}
      }

      if (isFrontReady) {
        try {
          final shot = await front.takePicture();
          final file = await File(shot.path).copy(
            '${tempDir.path}/selfie_${widget.type.dbValue}_$stamp.jpg',
          );
          await File(shot.path).delete();
          selfiePath = file.path;
        } catch (_) {}
      }

      if (photoPath == null && selfiePath == null) {
        throw Exception('No fue posible capturar las fotografías. Inténtalo de nuevo.');
      }

      photoPath ??= selfiePath;

      await ref.read(checadorProvider.notifier).saveCheckIn(
            type: widget.type,
            photoPath: photoPath!,
            selfiePath: selfiePath,
            latitude: _currentLocation!.latitude,
            longitude: _currentLocation!.longitude,
            isMocked: _currentLocation!.isMocked,
            isOvertimeSelected: _isOvertimeSelected,
            overtimeReason: _isOvertimeSelected ? _overtimeReasonController.text : null,
          );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        final msg = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Error al fichar: $msg',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  bool get _hasAnyCameraReady => _isBackReady || _isFrontReady;

  Widget _buildLivenessChip() {
    final IconData icon;
    final Color color;
    final String text;

    switch (_livenessState) {
      case FaceLivenessState.noFace:
        icon = Icons.person_off_rounded;
        color = Colors.redAccent;
        text = 'Sin rostro';
      case FaceLivenessState.searching:
        icon = Icons.visibility_rounded;
        color = Colors.amberAccent;
        text = 'Coloca tu rostro';
      case FaceLivenessState.verified:
        icon = Icons.verified_user_rounded;
        color = Colors.greenAccent;
        text = 'Rostro verificado';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _cameraLoadingPlaceholder() {
    return Container(
      color: Colors.black26,
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.emerald),
      ),
    );
  }

  Widget _buildTimeStatusOverlay() {
    return Positioned(
      top: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time_rounded, color: AppColors.accentOrange, size: 15),
            const SizedBox(width: 7),
            Text(
              TimeUtils.formatTime(_currentTime, includeSeconds: true),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            if (_geofenceResult != null) ...[
              const SizedBox(width: 10),
              Container(
                width: 1,
                height: 14,
                color: Colors.white24,
              ),
              const SizedBox(width: 10),
              Icon(
                _geofenceResult!.isInside
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: _geofenceResult!.isInside
                    ? Colors.greenAccent
                    : Colors.amberAccent,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityBlockOverlay() {
    if (_securityBlockingError == null) return const SizedBox.shrink();
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block_rounded, color: Colors.redAccent, size: 50),
              const SizedBox(height: 12),
              Text(
                _securityBlockingError!,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraUnavailable({required bool isFront}) {
    return Container(
      color: Colors.black38,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFront ? Icons.face_retouching_off_rounded : Icons.videocam_off_rounded,
                color: Colors.white54,
                size: 34,
              ),
              const SizedBox(height: 8),
              Text(
                isFront ? 'Cámara frontal no disponible' : 'Cámara trasera no disponible',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPane() {
    final controller = _frontController;
    final isReady = _isFrontReady;
    final initFailed = _frontInitFailed;

    final Widget content;
    if (isReady && controller != null && controller.value.previewSize != null) {
      final previewSize = controller.value.previewSize!;
      content = Positioned.fill(
        child: Center(
          child: AspectRatio(
            aspectRatio: previewSize.width / previewSize.height,
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: previewSize.width,
                height: previewSize.height,
                child: CameraPreview(controller),
              ),
            ),
          ),
        ),
      );
    } else if (initFailed) {
      content = _buildCameraUnavailable(isFront: true);
    } else {
      content = _cameraLoadingPlaceholder();
    }

    final pane = Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        content,
        _buildTimeStatusOverlay(),
        if (_securityBlockingError != null) _buildSecurityBlockOverlay(),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildLivenessChip(),
          ),
        ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: pane,
    );
  }

  Widget _buildSinglePreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildCameraPane(),
    );
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _livenessTimer?.cancel();
    _backController?.dispose();
    _frontController?.dispose();
    _faceService.dispose();
    _overtimeReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141916),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildSinglePreview(),
            ),

            // Botón de disparo
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: (_isProcessing || !_hasAnyCameraReady || _securityBlockingError != null)
                      ? null
                      : _captureAndSave,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_rounded, color: Colors.white),
                  label: Text(
                    _isProcessing ? 'Enviando registro...' : 'Tomar Foto y Registrar',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}