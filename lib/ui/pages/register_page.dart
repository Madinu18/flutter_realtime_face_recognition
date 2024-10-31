part of 'pages.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class BoundingBoxPainter extends CustomPainter {
  final Rect? boundingBox;

  BoundingBoxPainter(this.boundingBox);

  @override
  void paint(Canvas canvas, Size size) {
    if (boundingBox != null) {
      final paint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRect(boundingBox!, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class _RegisterPageState extends State<RegisterPage> {
  Rect? boundingBox;
  XFile? capturedImage;
  XFile? croppedImage;
  Size? imageSize;
  late final CameraCubit _cameraCubit;
  late final MLServiceCubit _mlServiceCubit;

  @override
  void initState() {
    super.initState();
    _cameraCubit = context.read<CameraCubit>();
    _mlServiceCubit = context.read<MLServiceCubit>();
    _cameraCubit.initializeCamera();
  }

  @override
  void dispose() {
    _cameraCubit.close();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      await _cameraCubit.takePicture();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking picture: $e')),
        );
      }
    }
  }

  Future<void> _getImageSize(String imagePath) async {
    final File imageFile = File(imagePath);
    final Image image = Image.file(imageFile);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            imageSize = Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            );
          });
        }
      }),
    );
  }

  Future<void> _saveCroppedImage() async {
    try {
      if (capturedImage == null || boundingBox == null) {
        throw Exception('No image or bounding box available');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Processing image...')),
        );
      }

      final XFile? cropResult = await _cameraCubit.cropImage(capturedImage!, boundingBox!);

      if (cropResult == null) {
        throw Exception('Failed to crop image');
      }
      
      _mlServiceCubit.recognizeFace(cropResult);

      final success = await GallerySaver.saveImage(
        cropResult.path,
        albumName: 'Face Registration'
      );

      if (success ?? false) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          context.read<PageCubit>().goToMainPage();
        }
      } else {
        throw Exception('Failed to save image to gallery');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Face'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.read<PageCubit>().goToMainPage(),
        ),
      ),
      body: BlocListener<CameraCubit, CameraState>(
        listener: (context, state) async {
          if (state is CameraDetectedFaces) {
            setState(() {
              boundingBox = state.boundingBox;
            });
          }
          if (state is CameraCaptured) {
            setState(() {
              capturedImage = state.capturedImage;
            });
            if (capturedImage != null) {
              await _getImageSize(capturedImage!.path);
              _cameraCubit.faceDetect(capturedImage!);
            }
          }
        },
        child: BlocBuilder<CameraCubit, CameraState>(
          builder: (context, state) {
            if (state is CameraLoading || state is CameraCapturing) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (state is CameraReady) {
              return _buildCameraPreview(state.controller);
            }

            if ((state is CameraCaptured || state is CameraDetectedFaces) && 
                capturedImage != null && 
                imageSize != null) {
              return _buildCapturedImage(state);
            }

            if (state is CameraError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(state.errorMessage),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.read<CameraCubit>().initializeCamera(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            return const Center(child: Text('Initializing camera...'));
          },
        ),
      ),
    );
  }

  Widget _buildCameraPreview(CameraController controller) {
    if (!controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.of(context).size;
    final screenAspectRatio = size.width / size.height;
    final previewAspectRatio = controller.value.previewSize!.width / 
                              controller.value.previewSize!.height;

    var scale = screenAspectRatio < previewAspectRatio 
        ? size.height / (controller.value.previewSize!.height)
        : size.width / (controller.value.previewSize!.width);

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: scale,
            child: Center(
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(math.pi),
                child: CameraPreview(controller),
              ),
            ),
          ),
          // if (boundingBox != null)
          //   CustomPaint(
          //     painter: BoundingBoxPainter(boundingBox),
          //     size: size,
          //   ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _takePicture,
                  child: const Text(
                    'Take Picture',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapturedImage(CameraState state) {
    if (imageSize == null) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    final widthScale = size.width / imageSize!.width;
    final heightScale = size.height / imageSize!.height;
    final scale = math.min(widthScale, heightScale);

    final adjustedBoundingBox = boundingBox != null
        ? Rect.fromLTWH(
            boundingBox!.left * scale,
            boundingBox!.top * scale,
            boundingBox!.width * scale,
            boundingBox!.height * scale,
          )
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(capturedImage!.path),
          fit: BoxFit.cover,
        ),
        if (adjustedBoundingBox != null)
          CustomPaint(
            painter: BoundingBoxPainter(adjustedBoundingBox),
            size: size,
          ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () => context.read<CameraCubit>().initializeCamera(),
                    child: const Text('Retake', style: TextStyle(fontSize: 16)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: _saveCroppedImage,
                    child: const Text('Save', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}