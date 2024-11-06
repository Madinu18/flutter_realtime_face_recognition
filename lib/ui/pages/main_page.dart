// main_page.dart
part of 'pages.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late final CameraCubit _cameraCubit;
  late final MLServiceCubit _mlServiceCubit;
  XFile? capturedImage;
  List<double>? output;
  Map<String, dynamic>? data;

  String matchedUserName = "";
  double similarityPercentage = 0.0;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cameraCubit = context.read<CameraCubit>();
    // _mlServiceCubit = context.read<MLServiceCubit>();
    loadModel();
    _cameraCubit.initializeCamera();
    _startTimer();
  }

  @override
  void dispose() {
    _cameraCubit.close();
    _stopTimer();
    disposeModel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _takePicture();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
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

  Future<void> _deleteAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete all data?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.deleteAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data deleted successfully.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting data: $e')),
        );
      }
    }
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
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 6), // This pushes the content down
                if (matchedUserName.isNotEmpty) ...[
                  Text(
                    matchedUserName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Similarity: ${similarityPercentage.toStringAsFixed(2)}%',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
                const Spacer(
                    flex:
                        1), // This creates space between the text and the button
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 12,
                      ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Page'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => context.read<PageCubit>().goToRegisterPage(),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () =>
                context.read<PageCubit>().goToDataPage(), //_deleteAllData,
          ),
        ],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<CameraCubit, CameraState>(
            listener: (context, state) async {
              if (state is CameraCaptured) {
                setState(() {
                  capturedImage = state.capturedImage;
                });
                await _mlServiceCubit.getEmbeddedVector(capturedImage!);
              }
              if (state is CameraFaceAlert) {
                matchedUserName = "";
                similarityPercentage = 0.0;
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
              if (state is GetEmbeddedVectorSuccess) {
                output = state.output;
                MSG.DBG("Embedded Vector = $output");
                var allFaceData =
                    await DatabaseHelper.instance.getAllFaceData();
                MSG.DBG("All Face Data: $allFaceData");
                if (allFaceData.isNotEmpty && output != null) {
                  data =
                      (await DatabaseHelper.instance.findMatchingFace(output!));

                  if (data != null) {
                    MSG.DBG("Output is ${data?['user']}");
                    if (data?['user'] is User) {
                      User matchedUser = data?['user'];
                      matchedUserName = matchedUser.name;
                    }
                    similarityPercentage = data?['confidence'];
                  } else {
                    matchedUserName = "Face is Not Registered";
                    similarityPercentage = 0.0;
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('There is no face in database'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          )
        ],
        child: BlocBuilder<CameraCubit, CameraState>(
          builder: (context, state) {
            if (state is CameraLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is CameraReady) {
              return _buildCameraPreview(state.controller);
            } else if (state is CameraError) {
              return Center(child: Text(state.errorMessage));
            }
            return const Center(child: Text('Initialize camera'));
          },
        ),
      ),
    );
  }
}
