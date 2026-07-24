import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz/feature/auth/controller/auth_vm.dart';
import 'package:quiz/feature/auth/view/login_page.dart';
import 'package:quiz/feature/home/controller/webSocket_vm.dart';
import 'package:quiz/feature/home/view/home_page.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthVm>();

    if (auth.isLoggedIn == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

   if (auth.isLoggedIn! && auth.token != null) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<WebsocketVm>().connect(auth.token!);
  });
  return const HomePage();
}

    return const LogPage();
  }
}