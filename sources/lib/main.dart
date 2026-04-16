import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const LanceurApp());
}

class LanceurApp extends StatelessWidget {
  const LanceurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lanceur',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}