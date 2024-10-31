// main_page.dart
part of 'pages.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  @override
  void initState() {
    super.initState();
    context.read<CameraCubit>().initializeCamera();
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
        ],
      ),
      body: BlocBuilder<CameraCubit, CameraState>(
        builder: (context, state) {
          if (state is CameraLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is CameraReady) {
            return Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: state.controller.value.previewSize!.height,
                  height: state.controller.value.previewSize!.width,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(math.pi), // Mirror the camera preview
                    child: CameraPreview(state.controller),
                  ),
                ),
              ),
            );
          } else if (state is CameraError) {
            return Center(child: Text(state.errorMessage));
          }
          return const Center(child: Text('Initialize camera'));
        },
      ),
    );
  }
}
