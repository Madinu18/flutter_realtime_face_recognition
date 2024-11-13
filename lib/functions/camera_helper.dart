part of 'functions.dart';

XFile cropImage(Map<String, dynamic> args) {
  XFile originalImage = args['originalImage'];
  Rect boundingBox = args['boundingBox'];
  try {
    final File imageFile = File(originalImage.path);
    final Uint8List imageBytes = imageFile.readAsBytesSync();
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

    final img.Image croppedImage = img.copyCrop(
      image,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );

    final Directory tempDir = Directory.systemTemp;
    final String tempPath = tempDir.path;
    final String croppedImagePath =
        '$tempPath/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final File croppedFile = File(croppedImagePath);
    croppedFile.writeAsBytesSync(img.encodeJpg(croppedImage));

    MSG.DBG("crop done");

    return XFile(croppedImagePath);
  } catch (e) {
    throw Exception("Error cropping image: $e");
  }
}
