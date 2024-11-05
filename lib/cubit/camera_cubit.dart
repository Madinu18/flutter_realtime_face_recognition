import 'dart:io';
import 'dart:math';
import 'dart:ui';
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
    if (state is CameraReady) {
      final controller = (state as CameraReady).controller;

      try {
        final XFile image = await controller.takePicture();
        final Rect? detectedFace = await faceDetect(image);

        MSG.DBG("Detected Face = $detectedFace");

        if (detectedFace != null) {
          if (isFaceProperlyPositioned(detectedFace)) {
            final XFile? cropResult = await cropImage(image, detectedFace);
            if (cropResult == null) {
              throw Exception('Failed to crop image');
            }

            if (isClosed) return; // Check if the cubit is closed
            emit(CameraCaptured(cropResult));
            if (isClosed) return; // Check if the cubit is closed
            emit(CameraReady(controller));
          } else {
            MSG.DBG("Face not within the acceptable area");
            emit(CameraFaceAlert('Face not within the acceptable area'));
            if (isClosed) return; // Check if the cubit is closed
            emit(CameraReady(controller));
          }
        } else {
          MSG.ERR("No faces detected");
          if (isClosed) return; // Check if the cubit is closed
          emit(CameraReady(controller));
        }
      } catch (e) {
        if (isClosed) return; // Check if the cubit is closed
        emit(CameraError("Failed to capture image: $e"));
      }
    }
  }

  bool isFaceWithinBounds(Rect detectedFace, Rect acceptableBounds) {
    // Check if the detected face is entirely within the acceptable bounds
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

  Future<XFile?> cropImage(XFile originalImage, Rect boundingBox) async {
    try {
      // Read the image file
      final File imageFile = File(originalImage.path);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      final int x = boundingBox.left.round();
      final int y = boundingBox.top.round();
      final int width = boundingBox.width.round();
      final int height = boundingBox.height.round();

      final int cropX = x.clamp(0, image.width - 1);
      final int cropY = y.clamp(0, image.height - 1);
      final int cropWidth = width.clamp(1, image.width - cropX);
      final int cropHeight = height.clamp(1, image.height - cropY);

      // Crop the image
      final img.Image croppedImage = img.copyCrop(
        image,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = tempDir.path;
      final String croppedImagePath =
          '$tempPath/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final File croppedFile = File(croppedImagePath);
      await croppedFile.writeAsBytes(img.encodeJpg(croppedImage));

      return XFile(croppedImagePath);
    } catch (e) {
      // Handle error
      MSG.ERR(
          'Error cropping image: $e'); // Change this to your logging mechanism
      return null;
    }
  }

  bool isFaceProperlyPositioned(Rect detectedFace) {
    // Define the oval bounds (you may need to adjust these values)
    final double ovalCenterX = acceptableFaceArea.center.dx;
    final double ovalCenterY = acceptableFaceArea.center.dy;
    final double ovalWidth = acceptableFaceArea.width;
    final double ovalHeight = acceptableFaceArea.height;

    // Check if face center is within the oval
    final double faceCenterX = detectedFace.center.dx;
    final double faceCenterY = detectedFace.center.dy;

    // Calculate if point is inside oval using the equation of an ellipse
    final double normalizedX =
        pow(faceCenterX - ovalCenterX, 2) / pow(ovalWidth / 2, 2);
    final double normalizedY =
        pow(faceCenterY - ovalCenterY, 2) / pow(ovalHeight / 2, 2);
    final bool isInOval = normalizedX + normalizedY <= 1;

    // Check face size (adjust tolerance as needed)
    const double sizeTolerance = 0.2; // 20% tolerance
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
