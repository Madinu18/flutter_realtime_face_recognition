import 'dart:io';
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

  Future<void> takePicture() async {
    if (state is CameraReady) {
      final controller = (state as CameraReady).controller;
      emit(CameraCapturing(controller));
      try {
        final image = await controller.takePicture();
        emit(CameraCaptured(image));
      } catch (e) {
        emit(CameraError("Failed to capture image: $e"));
      }
    }
  }

  Future<void> faceDetect(XFile img) async {
    File file = File(img.path);

    final InputImage inputImage = InputImage.fromFile(file);

    final options = FaceDetectorOptions();
    final faceDetector = FaceDetector(options: options);

    final List<Face> faces = await faceDetector.processImage(inputImage);

    if (faces.isNotEmpty) {
      final boundingBox = faces[0].boundingBox;
      boundingBoxValue = boundingBox;
      emit(CameraDetectedFaces(boundingBox));
    }
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
        x:cropX,
        y:cropY,
        width:cropWidth,
        height:cropHeight,
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

  @override
  Future<void> close() {
    _controller?.dispose();
    return super.close();
  }
}
