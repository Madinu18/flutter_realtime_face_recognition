import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cubit/cubit.dart';
import 'ui/pages/pages.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await availableCameras();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Real Time Face Recognition',
        home: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => PageCubit(),
              lazy: true,
            ),
            BlocProvider(
                create: (context) => CameraCubit(),
                lazy: true,
              ),
            BlocProvider(
                create: (context) => MLServiceCubit()..loadModel(),
                lazy: false,
              ),
          ],
          child: const Wrapper(),
        ));
  }
}
