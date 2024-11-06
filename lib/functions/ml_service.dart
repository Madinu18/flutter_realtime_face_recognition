
part of 'functions.dart';

Interpreter? _interpreter;

  Future<void> loadModel() async {
    try {
      _interpreter =
          await Interpreter.fromAsset("assets/models/mobilefacenet.tflite");
      MSG.DBG('Model loaded successfully');
    } catch (e) {
      MSG.ERR("Error loading model: $e");
    }
  }

  Future<List<List<double>>> preprocessImage(String imagePath,
      {List<int> targetSize = const [112, 112]}) async {
    try {
      File imageFile = File(imagePath);
      Uint8List imageData = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageData);

      if (originalImage == null) {
        throw Exception("Failed to decode image");
      }

      img.Image resizedImage = img.copyResize(originalImage,
          width: targetSize[0], height: targetSize[1]);

      List<double> flattenedList = resizedImage.data!
          .expand((channel) => [channel.r, channel.g, channel.b])
          .map((value) => value.toDouble())
          .toList();
      Float32List float32Array = Float32List.fromList(flattenedList);

      int channels = 3;
      int height = targetSize[1];
      int width = targetSize[0];

      Float32List reshapedArray = Float32List(1 * height * width * channels);
      for (int c = 0; c < channels; c++) {
        for (int h = 0; h < height; h++) {
          for (int w = 0; w < width; w++) {
            int index = c * height * width + h * width + w;
            reshapedArray[index] =
                (float32Array[c * height * width + h * width + w] - 127.5) /
                    127.5;
          }
        }
      }

      List<List<double>> result = [reshapedArray.toList()];
      return result;
    } catch (e) {
      // MSG.ERR("Preprocessing error: $e");
      throw Exception("Failed to preprocess image: $e");
    }
  }

  Future<List<double>> runModelOnImage(List<List<double>> input) async {
    try {
      if (_interpreter == null) {
        throw Exception("Interpreter is not initialized");
      }

      var outputShape = [1, 192];
      var outputBuffer = List.filled(outputShape[0] * outputShape[1], 0.0);
      var outputTensor = outputBuffer.reshape(outputShape);

      _interpreter!.run(input[0].reshape([1, 112, 112, 3]), outputTensor);

      return outputTensor.first;
    } catch (e) {
      // MSG.ERR("Model inference error: $e");
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
    similarity = similarity * 100;

    MSG.DBG("Similarity is $similarity");
    
    return similarity;
  }

  Future<void> disposeModel() async {
    if (_interpreter != null) {
      _interpreter!.close();
      _interpreter = null;
    }
  }

  Future<List<double>> getEmbeddedVector(XFile img1) async {
    try {
      final List<List<double>> processedInput = await preprocessImage(img1.path);

      if (processedInput.isEmpty) {
        throw Exception("Image path was null");
        // return null;
      }

      final List<double> output = await runModelOnImage(processedInput);
      return output;

    } catch (e) {
      // MSG.ERR("Recognition error: $e");
      throw Exception("Recognition error: $e");
    }
  }
