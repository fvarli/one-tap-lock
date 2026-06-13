import 'package:flutter/material.dart';

import 'home_page.dart';

void main() {
  runApp(const OneTapLockApp());
}

class OneTapLockApp extends StatelessWidget {
  const OneTapLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'One Tap Lock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}
