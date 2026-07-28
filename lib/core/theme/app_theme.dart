import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primaryRed = Color(0xFFB71C1C);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkAppBar = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2C2C2C);
  static const Color darkContainer = Color(0xFF252525);
  static const Color whatsappGreen = Color(0xFF128C7E);
  static const Color orange = Color(0xFFFF9800);

  // Text styles
  static const TextStyle titleStyle = TextStyle(
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
    color: Colors.white,
  );

  static const TextStyle subtitleStyle = TextStyle(
    color: Colors.grey,
    fontSize: 12,
  );

  static const TextStyle contactNameStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 16,
    color: Colors.white,
  );

  static const TextStyle contactNumberStyle = TextStyle(
    color: Colors.white70,
    fontSize: 13,
  );

  // Theme data
  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.red[700],
        scaffoldBackgroundColor: darkBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: darkAppBar,
          elevation: 0,
          centerTitle: true,
        ),
      );
}
