// page_cubit.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

part 'page_state.dart';

class PageCubit extends Cubit<PageState> {
  PageCubit() : super(OnMainPage()); // Changed initial state name

  void goToRegisterPage() {
    emit(OnRegisterPage());
  }

  void goToMainPage() {  // Added method to return to main page
    emit(OnMainPage());
  }
}