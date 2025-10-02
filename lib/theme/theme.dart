import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData lightMode = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
  useMaterial3: true,
  textTheme: GoogleFonts.ubuntuTextTheme(),
  scaffoldBackgroundColor: Color(0xfff8f8ff),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xfff8f8ff),
  ),
);

ThemeData darkMode = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
  useMaterial3: true,
  textTheme: GoogleFonts.ubuntuTextTheme(),
  scaffoldBackgroundColor: Colors.black87,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.black87,
  ),
);