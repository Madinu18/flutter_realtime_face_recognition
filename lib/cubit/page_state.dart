// page_state.dart
part of 'page_cubit.dart';

@immutable
abstract class PageState extends Equatable {
  const PageState();

  @override
  List<Object?> get props => [];
}

class OnMainPage extends PageState {} // Changed from MainPage
class OnRegisterPage extends PageState {} // Changed from GoToRegisterPage