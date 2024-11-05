part of 'ml_service_cubit.dart';

abstract class MLServiceState {}

class MLServiceInitial extends MLServiceState {}

class MLServiceLoading extends MLServiceState {}

class MLServiceLoaded extends MLServiceState {}

class MLServicePredicting extends MLServiceState {}

class GetEmbeddedVectorSuccess extends MLServiceState {
  final List<double> output;

  GetEmbeddedVectorSuccess(this.output);
}

class GetEmbeddedVectorFailure extends MLServiceState {
  final String message;

  GetEmbeddedVectorFailure(this.message);
}

class MLServiceError extends MLServiceState {
  final String message;

  MLServiceError(this.message);
}

class SimmilarityValue extends MLServiceState {
  final double value;

  SimmilarityValue(this.value);

  List<Object> get props => [value];
}
