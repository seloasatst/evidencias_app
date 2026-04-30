import 'package:flutter/material.dart';

ThemeData appTheme() {
  final seed = const Color(0xFFFF6A00);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: seed),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
  );
}
