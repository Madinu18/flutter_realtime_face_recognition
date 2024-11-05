// page_cubit.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

part 'page_state.dart';

class PageCubit extends Cubit<PageState> {
  PageCubit() : super(OnMainPage());

  void goToRegisterPage() {
    emit(OnRegisterPage());
  }

  void goToMainPage() {
    emit(OnMainPage());
  }

  void goToDataPage(){
    emit(OnDataPage());
  }
}