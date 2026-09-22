import 'dart:io';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum FaceLivenessState { noFace, searching, verified }

class FaceLivenessService {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.15,
    ),
  );

  Future<FaceLivenessState> analyzePhoto(File file) async {
    try {
      final faces = await _detector.processImage(InputImage.fromFile(file));
      if (faces.isEmpty || faces.length > 1) {
        return FaceLivenessState.noFace;
      }

      final face = faces.first;
      final rotY = face.headEulerAngleY ?? 0.0;
      final rotZ = face.headEulerAngleZ ?? 0.0;

      if (rotY.abs() > 35.0 || rotZ.abs() > 35.0) {
        return FaceLivenessState.searching;
      }

      return FaceLivenessState.verified;
    } catch (_) {
      return FaceLivenessState.searching;
    }
  }

  void dispose() {
    _detector.close();
  }
}