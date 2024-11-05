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

class CirclePainter extends CustomPainter {
  final Offset center;
  final double radius;

  CirclePainter(this.center, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    // Create path for the entire screen
    final Path backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create oval rectangle
    final RRect ovalRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: radius * 1.5, // Make it wider
        height: radius * 2.0, // Make it taller
      ),
      Radius.circular(radius), // Adjust the corner radius as needed
    );

    // Create path for the oval
    final Path ovalPath = Path()..addRRect(ovalRect);

    // Create path for the dark overlay (everything except the oval)
    final Path overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      ovalPath,
    );

    // Draw the dark overlay
    final Paint overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawPath(overlayPath, overlayPaint);

    // Draw oval border
    final Paint borderPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRRect(ovalRect, borderPaint);

    // Add guide text
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    );
    const textSpan = TextSpan(
      text: 'Position your face within the oval',
      style: textStyle,
    );
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(
      maxWidth: size.width,
    );
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, center.dy - radius - 40),
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _RegisterPageState extends State<RegisterPage> {
  Rect? boundingBox;
  XFile? capturedImage;
  XFile? croppedImage;
  Size? imageSize;
  bool _isTextFieldFocused = false;
  bool _shouldShowButtons = true;
  late final CameraCubit _cameraCubit;
  late final MLServiceCubit _mlServiceCubit;

  List<double>? _output1;
  List<double>? _output2;
  double threshold = 90;
  int counter = 0;

  Timer? _timer;

  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    _cameraCubit = context.read<CameraCubit>();
    _mlServiceCubit = context.read<MLServiceCubit>();
    _cameraCubit.initializeCamera();
    super.initState();
    _startTimer();
  }

  void _onFocusChange(bool hasFocus) {
    setState(() {
      _isTextFieldFocused = hasFocus;

      if (!hasFocus) {
        Future.delayed(const Duration(milliseconds: 100), () {
          setState(() {
            _shouldShowButtons = true;
          });
        });
      } else {
        _shouldShowButtons = false;
      }
    });
  }

  @override
  void dispose() {
    // _cameraCubit.close();
    _stopTimer();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      _cameraCubit.takePicture();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking picture: $e')),
        );
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (counter < 5) {
        await _takePicture();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
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

  Future<void> _saveFaceData() async {
    try {
      // Validate inputs
      if (_nameController.text.isEmpty) {
        throw Exception('Please enter a name');
      }

      if (_output1 == null) {
        throw Exception('No face vector available');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saving face data...')),
        );
      }

      await DatabaseHelper.instance.insertFaceData(
        _nameController.text,
        _output1!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Face data saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.read<PageCubit>().goToMainPage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving face data: $e'),
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
      body: MultiBlocListener(
        listeners: [
          BlocListener<CameraCubit, CameraState>(
            listener: (context, state) async {
              if (state is CameraDetectedFaces) {
                setState(() {
                  boundingBox = state.boundingBox;
                });
              }
              if (state is CameraCaptured) {
                setState(() {
                  capturedImage = state.capturedImage;
                  _mlServiceCubit.getEmbeddedVector(capturedImage!);
                });
                if (capturedImage != null) {
                  await _getImageSize(capturedImage!.path);
                }
              }
              if (state is CameraFaceAlert) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
          ),
          BlocListener<MLServiceCubit, MLServiceState>(
            listener: (context, state) async {
              if (state is GetEmbeddedVectorSuccess && _output1 == null) {
                _output1 = state.output;
              } else if (state is GetEmbeddedVectorSuccess &&
                  _output1 != null) {
                _output2 = state.output;
                _mlServiceCubit.calculateCosineSimilarity(_output1!, _output2!);
              }

              if (state is SimmilarityValue) {
                if (state.value >= threshold) {
                  setState(() {
                    counter += 1;
                  });
                } else {
                  setState(() {
                    counter = 0;
                    _output1 = null;
                  });
                }
                MSG.DBG("Counter is $counter");
              }
            },
          )
        ],
        child: BlocBuilder<CameraCubit, CameraState>(
          builder: (context, state) {
            if (counter >= 5 && capturedImage != null) {
              return _buildCapturedImage();
            }

            if (state is CameraLoading || state is CameraCapturing) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (state is CameraReady) {
              return _buildCameraPreview(state.controller);
            }

            if (state is CameraError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(state.errorMessage),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          context.read<CameraCubit>().initializeCamera(),
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

    final ovalCenterX = size.width * 0.5;
    final ovalCenterY = size.height * 0.35;
    final ovalRadius = size.width * 0.46;

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
          CustomPaint(
            painter: CirclePainter(
              Offset(ovalCenterX, ovalCenterY),
              ovalRadius,
            ),
            size: size,
          ),
        ],
      ),
    );
  }

  Widget _buildCapturedImage() {
    _stopTimer();
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _isTextFieldFocused ? 250 : 300,
                height: _isTextFieldFocused ? 350 : 400,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(pi),
                  child: Image.file(
                    File(capturedImage!.path),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Focus(
                  onFocusChange: _onFocusChange,
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Enter face name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!_isTextFieldFocused && _shouldShowButtons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            capturedImage = null;
                            _isTextFieldFocused = false;
                            _shouldShowButtons = true;
                            counter = 0;
                            _nameController.clear();
                          });
                          _cameraCubit.initializeCamera();
                          _startTimer();
                        },
                        child: const Text('Retake',
                            style: TextStyle(fontSize: 16)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _saveFaceData,
                        child:
                            const Text('Save', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
