import 'package:flutter/material.dart';

import 'core/auth/screens/login_screen.dart';

void main() => runApp(const MyFapApp());

class MyFapApp extends StatelessWidget {
  const MyFapApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MyFAP Demo',
    theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
    home: const LoginScreen(),
  );
}
