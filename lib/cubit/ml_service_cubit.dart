import 'package:bloc/bloc.dart';
import 'package:camera/camera.dart';
import 'package:flutter_real_time_face_recognition/utils/utils.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';

part 'ml_service_state.dart';

class MLServiceCubit extends Cubit<MLServiceState> {
  Interpreter? _interpreter;
  MLServiceCubit() : super(MLServiceInitial());

  Future<void> loadModel() async {
    emit(MLServiceLoading());
    try {
      _interpreter = await Interpreter.fromAsset("assets/models/mobilefacenet.tflite");
      print('Model loaded successfully');
      emit(MLServiceLoaded());
    } catch (e) {
      print("Error loading model: $e");
      emit(MLServiceError("Failed to load model: $e"));
    }
  }

  Future<List<List<double>>> preprocessImage(String imagePath,
      {List<int> targetSize = const [112, 112]}) async {
    try {
      // Read image file as bytes
      File imageFile = File(imagePath);
      Uint8List imageData = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageData);

      if (originalImage == null) {
        throw Exception("Failed to decode image");
      }

      // Resize the image
      img.Image resizedImage = img.copyResize(originalImage,
          width: targetSize[0], height: targetSize[1]);

      // Convert to Float32List for better performance
      List<double> flattenedList = resizedImage.data!
          .expand((channel) => [channel.r, channel.g, channel.b])
          .map((value) => value.toDouble())
          .toList();
      Float32List float32Array = Float32List.fromList(flattenedList);

      // Define dimensions
      int channels = 3;
      int height = targetSize[1];  // 112
      int width = targetSize[0];   // 112

      // Create reshaped array with normalization
      Float32List reshapedArray = Float32List(1 * height * width * channels);
      for (int c = 0; c < channels; c++) {
        for (int h = 0; h < height; h++) {
          for (int w = 0; w < width; w++) {
            int index = c * height * width + h * width + w;
            reshapedArray[index] =
                (float32Array[c * height * width + h * width + w] - 127.5) / 127.5;
          }
        }
      }

      // Convert Float32List to List<List<double>> and maintain the shape
      List<List<double>> result = [reshapedArray.toList()];
      return result;

    } catch (e) {
      MSG.ERR("Preprocessing error: $e");
      throw Exception("Failed to preprocess image: $e");
    }
  }

  Future<void> recognizeFace(XFile img1) async {
    emit(MLServicePredicting());
    try {
      // Preprocess image
      final List<List<double>> processedInput = await preprocessImage(img1.path);
      
      if (processedInput.isEmpty) {
        emit(MLServicePredictionFailure("Failed to preprocess images."));
        return;
      }

      final List<double> output = await runModelOnImage(processedInput);

      MSG.DBG("Processing completed");
      MSG.DBG("Model output shape: ${output.length}");
      MSG.DBG("First few embeddings: ${output.take(5).toList()}");

      emit(MLServicePredictionSuccess(output));

    } catch (e) {
      MSG.ERR("Recognition error: $e");
      emit(MLServiceError("Prediction error: $e"));
    }
  }

  Future<List<double>> runModelOnImage(List<List<double>> input) async {
    try {
      if (_interpreter == null) {
        throw Exception("Interpreter is not initialized");
      }

      // Prepare output tensor - assuming output shape is [1, 192]
      var outputShape = [1, 192];
      var outputBuffer = List.filled(outputShape[0] * outputShape[1], 0.0);
      var outputTensor = outputBuffer.reshape(outputShape);

      // Run inference
      _interpreter!.run(input[0].reshape([1, 112, 112, 3]), outputTensor);
      
      return outputTensor[0];

    } catch (e) {
      MSG.ERR("Model inference error: $e");
      throw Exception("Failed to run model inference: $e");
    }
  }

  double calculateCosineSimilarity(List<double> vector1, List<double> vector2) {
    if (vector1.length != vector2.length) {
      throw Exception("Vectors must have the same length");
    }

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < vector1.length; i++) {
      dotProduct += vector1[i] * vector2[i];
      norm1 += vector1[i] * vector1[i];
      norm2 += vector2[i] * vector2[i];
    }

    double similarity = dotProduct / (sqrt(norm1) * sqrt(norm2));
    return similarity * 100; // Convert to percentage
  }

  @override
  Future<void> close() async {
    await disposeModel();
    return super.close();
  }

  Future<void> disposeModel() async {
    if (_interpreter != null) {
      _interpreter!.close();
      _interpreter = null;
    }
  }
}