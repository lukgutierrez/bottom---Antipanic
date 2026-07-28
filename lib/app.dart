import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/panic_home_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antipánico 911',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const PanicHomeScreen(),
    );
  }
}