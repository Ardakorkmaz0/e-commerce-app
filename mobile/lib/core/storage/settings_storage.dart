import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small preferences store.
///
/// Reuses the secure storage already in the app rather than pulling in a
/// second preferences package for one value.
class SettingsStorage {
  SettingsStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _themeModeKey = 'theme_mode';

  final FlutterSecureStorage _storage;

  /// Defaults to [ThemeMode.system] so a fresh install follows the phone.
  Future<ThemeMode> readThemeMode() async {
    switch (await _storage.read(key: _themeModeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> writeThemeMode(ThemeMode mode) async {
    await _storage.write(key: _themeModeKey, value: mode.name);
  }
}
