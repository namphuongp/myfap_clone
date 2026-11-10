import 'package:flutter/material.dart';

import 'core/auth/screens/login_screen.dart';

void main() => runApp(const MyFapApp());

class MyFapApp extends StatelessWidget {
  const MyFapApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'MyFAP',
    theme: ThemeData(
      colorSchemeSeed: const Color(0xFF7047EB),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFFAF9FD),
    ),
    home: const LoginScreen(),
  );
}
