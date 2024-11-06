part of 'camera_cubit.dart';

@immutable
abstract class CameraState {}

class CameraInitial extends CameraState {}

class CameraLoading extends CameraState {}

class CameraReady extends CameraState {
  final CameraController controller;

  CameraReady(this.controller);

  List<Object> get props => [controller];
}

class CameraCapturing extends CameraState {
  final CameraController controller;

  CameraCapturing(this.controller);

  List<Object> get props => [controller];
}

class CameraCaptured extends CameraState {
  final XFile capturedImage;

  CameraCaptured(this.capturedImage);

  List<Object> get props => [capturedImage];
}

class CameraError extends CameraState {
  final String errorMessage;

  CameraError(this.errorMessage);

  List<Object> get props => [errorMessage];
}

class CameraDetectedFaces extends CameraState {
  final Rect boundingBox;

  CameraDetectedFaces(this.boundingBox);

  List<Object> get props => [boundingBox];
}

class CameraFaceAlert extends CameraState {
  final String message;

  CameraFaceAlert(this.message);

  List<Object> get props => [message];
}

class OutputEmbeddedVector extends CameraState {
  final Future<List<double>> output;

  OutputEmbeddedVector(this.output);

  List<Object> get props => [output];
}