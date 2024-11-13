import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter_real_time_face_recognition/functions/functions.dart';
import 'package:image/image.dart' as img;
import 'package:bloc/bloc.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_real_time_face_recognition/shared/shared.dart';
import 'package:flutter_real_time_face_recognition/utils/utils.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';

part 'camera_state.dart';

class CameraCubit extends Cubit<CameraState> {
  CameraController? _controller;
  final Rect acceptableFaceArea =
      const Rect.fromLTRB(154.0, 280.0, 568.0, 698.0);

  CameraCubit() : super(CameraInitial());

  Future<void> initializeCamera() async {
    emit(CameraLoading());
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final controller = CameraController(
          cameras[1],
          ResolutionPreset.high,
        );
        await controller.initialize();
        emit(CameraReady(controller));
      } else {
        emit(CameraError("No camera found"));
      }
    } catch (e) {
      emit(CameraError("Failed to initialize camera: $e"));
    }
  }

  void takePicture() async {
    if (isClosed) return;
    if (state is CameraReady) {
      final controller = (state as CameraReady).controller;

      try {
        final XFile image = await controller.takePicture();
        final Rect? detectedFace = await faceDetect(image);

        Map<String, dynamic> args = {
          'originalImage': image,
          'boundingBox': detectedFace
        };

        MSG.DBG("Detected Face = $detectedFace");

        if (detectedFace != null) {
          if (isFaceProperlyPositioned(detectedFace)) {
            try {
              final cropResult = await compute(cropImage, args);

              List<double> output = await getEmbeddedVector(cropResult);

              emit(CameraCaptured(cropResult));
              emit(OutputEmbeddedVector(output));
              emit(CameraReady(controller));
            } catch (e) {
              MSG.ERR("Error cropping image: $e");
              emit(CameraError("Failed to process image: $e"));
              emit(CameraReady(controller));
            }
          } else {
            MSG.DBG("Face not within the acceptable area");
            if (!isClosed) {
              emit(CameraFaceAlert('Face not within the acceptable area'));
              emit(CameraReady(controller));
            }
          }
        } else {
          MSG.ERR("No faces detected");
          if (!isClosed) {
            emit(CameraReady(controller));
          }
        }
      } catch (e, stackTrace) {
        MSG.ERR('Error: $e');
        MSG.ERR('Stack trace: $stackTrace');
        if (!isClosed) {
          emit(CameraError("Failed to capture image: $e"));
        }
      }
    }
  }

  bool isFaceWithinBounds(Rect detectedFace, Rect acceptableBounds) {
    return acceptableBounds.contains(detectedFace.topLeft) &&
        acceptableBounds.contains(detectedFace.bottomRight);
  }

  Future<Rect?> faceDetect(XFile img) async {
    File file = File(img.path);

    final InputImage inputImage = InputImage.fromFile(file);

    final options = FaceDetectorOptions();
    final faceDetector = FaceDetector(options: options);

    final List<Face> faces = await faceDetector.processImage(inputImage);

    if (faces.isNotEmpty) {
      final boundingBox = faces[0].boundingBox;
      boundingBoxValue = boundingBox;

      return boundingBox;
    }

    return null;
  }

  bool isFaceProperlyPositioned(Rect detectedFace) {
    final double ovalCenterX = acceptableFaceArea.center.dx;
    final double ovalCenterY = acceptableFaceArea.center.dy;
    final double ovalWidth = acceptableFaceArea.width;
    final double ovalHeight = acceptableFaceArea.height;

    final double faceCenterX = detectedFace.center.dx;
    final double faceCenterY = detectedFace.center.dy;

    final double normalizedX =
        pow(faceCenterX - ovalCenterX, 2) / pow(ovalWidth / 2, 2);
    final double normalizedY =
        pow(faceCenterY - ovalCenterY, 2) / pow(ovalHeight / 2, 2);
    final bool isInOval = normalizedX + normalizedY <= 1;

    const double sizeTolerance = 0.2;
    final bool isCorrectSize =
        (detectedFace.width >= ovalWidth * (1 - sizeTolerance) &&
                detectedFace.width <= ovalWidth * (1 + sizeTolerance)) &&
            (detectedFace.height >= ovalHeight * (1 - sizeTolerance) &&
                detectedFace.height <= ovalHeight * (1 + sizeTolerance));

    return isInOval && isCorrectSize;
  }

  @override
  Future<void> close() {
    _controller?.dispose();
    return super.close();
  }
}
