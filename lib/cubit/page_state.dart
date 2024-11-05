// page_state.dart
part of 'page_cubit.dart';

@immutable
abstract class PageState extends Equatable {
  const PageState();

  @override
  List<Object?> get props => [];
}

class OnMainPage extends PageState {}
class OnRegisterPage extends PageState {}
class OnDataPage extends PageState {}