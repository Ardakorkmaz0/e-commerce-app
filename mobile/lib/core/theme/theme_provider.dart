import 'package:ecommerce_mobile/core/storage/settings_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final settingsStorageProvider = Provider<SettingsStorage>(
  (ref) => SettingsStorage(),
);

/// The app's theme choice: follow the device, or force light or dark.
///
/// Starts on [ThemeMode.system] and loads the stored preference in the
/// background. Reading storage is asynchronous, and blocking the first
/// frame on it would show a blank screen; starting on the device setting
/// means the brief initial state is already the right one for most people.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    final stored = await ref.read(settingsStorageProvider).readThemeMode();
    if (stored != state) {
      state = stored;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref.read(settingsStorageProvider).writeThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

String themeModeLabel(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'Light';
    case ThemeMode.dark:
      return 'Dark';
    case ThemeMode.system:
      return 'System default';
  }
}
