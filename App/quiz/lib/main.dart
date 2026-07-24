import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz/app/wrapper.dart';
import 'package:quiz/feature/auth/controller/auth_vm.dart';
import 'package:quiz/feature/auth/view/LogIn_page.dart';
import 'package:quiz/feature/auth/view/signup_page.dart';
import 'package:quiz/feature/home/controller/home_vm.dart';
import 'package:quiz/feature/home/controller/webSocket_vm.dart';
import 'package:quiz/feature/home/view/home_page.dart';
import 'package:quiz/feature/leaderboard/view/leaderboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthVm(),
        ),
        ChangeNotifierProvider(create:(_)=>WebsocketVm()), 
        ChangeNotifierProvider(create: (_)=>HomeVm()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: "/",
      routes: {
        "/": (context) =>  Wrapper(),
        "/home": (context) => const HomePage(),
        "/log_in":(context)=> const LogPage(),
        "/sign_up" :(context)=> const SignupPage(),
        "/leaderboard": (context) => const LeaderboardPage(),
  
      },
    );
  }
}