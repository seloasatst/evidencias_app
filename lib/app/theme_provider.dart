import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seloasa_evidencias/features/auth/data/token_storage.dart';

enum ThemeModeOption { light, dark, system }

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeModeOption>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeModeOption> {
  ThemeNotifier() : super(ThemeModeOption.system) {
    _loadTheme();
  }

  final _storage = TokenStorage();

  Future<void> _loadTheme() async {
    final saved = await _storage.getTheme();
    if (saved != null) {
      state = ThemeModeOption.values.firstWhere(
        (e) => e.toString() == saved,
        orElse: () => ThemeModeOption.system,
      );
    }
  }

  Future<void> setTheme(ThemeModeOption option) async {
    state = option;
    await _storage.saveTheme(option.toString());
  }
}
