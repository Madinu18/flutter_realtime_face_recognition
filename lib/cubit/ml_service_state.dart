part of 'ml_service_cubit.dart';

abstract class MLServiceState {}

class MLServiceInitial extends MLServiceState {}

class MLServiceLoading extends MLServiceState {}

class MLServiceLoaded extends MLServiceState {}

class MLServicePredicting extends MLServiceState {}

class MLServicePredictionSuccess extends MLServiceState {
  final List<double> similarity;

  MLServicePredictionSuccess(this.similarity);
}

class MLServicePredictionFailure extends MLServiceState {
  final String message;

  MLServicePredictionFailure(this.message);
}

class MLServiceError extends MLServiceState {
  final String message;

  MLServiceError(this.message);
}
