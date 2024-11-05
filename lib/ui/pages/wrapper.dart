// wrapper.dart
part of "pages.dart";

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PageCubit, PageState>(
      builder: (context, state) {
        if (state is OnMainPage) {
          return BlocProvider(
            create: (context) => CameraCubit(),
            child: const MainPage(),
          );
        } else if (state is OnRegisterPage) {
          return const RegisterPage();
        } else if (state is OnDataPage){
          return const DataPage();
        }
        return Container(); // fallback
      },
    );
  }
}