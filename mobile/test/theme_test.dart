import 'package:ecommerce_mobile/app/app.dart';
import 'package:ecommerce_mobile/core/storage/settings_storage.dart';
import 'package:ecommerce_mobile/core/storage/token_storage.dart';
import 'package:ecommerce_mobile/core/theme/theme_provider.dart';
import 'package:ecommerce_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Secure storage has no platform implementation under `flutter test`.
class _SignedOutStorage implements TokenStorage {
  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<bool> readRemember() async => false;

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
    bool remember = true,
  }) async {}

  @override
  Future<void> clearTokens() async {}
}

/// Reports a stored preference without touching the platform.
class _FakeSettingsStorage implements SettingsStorage {
  _FakeSettingsStorage(this.stored);

  ThemeMode stored;

  @override
  Future<ThemeMode> readThemeMode() async => stored;

  @override
  Future<void> writeThemeMode(ThemeMode mode) async {
    stored = mode;
  }
}

Future<Brightness> pumpAppWith(
  WidgetTester tester,
  ThemeMode stored, {
  Brightness platform = Brightness.light,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        tokenStorageProvider.overrideWithValue(_SignedOutStorage()),
        settingsStorageProvider.overrideWithValue(_FakeSettingsStorage(stored)),
      ],
      child: MediaQuery(
        // Stands in for the device's own light/dark setting.
        data: MediaQueryData(platformBrightness: platform),
        child: const EcommerceApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final context = tester.element(find.byType(Scaffold).first);
  return Theme.of(context).brightness;
}

void main() {
  testWidgets('follows the device when set to system', (tester) async {
    final brightness = await pumpAppWith(
      tester,
      ThemeMode.system,
      platform: Brightness.dark,
    );
    expect(brightness, Brightness.dark);
  });

  testWidgets('a stored dark choice overrides a light device', (tester) async {
    final brightness = await pumpAppWith(
      tester,
      ThemeMode.dark,
      platform: Brightness.light,
    );
    expect(brightness, Brightness.dark);
  });

  testWidgets('a stored light choice overrides a dark device', (tester) async {
    final brightness = await pumpAppWith(
      tester,
      ThemeMode.light,
      platform: Brightness.dark,
    );
    expect(brightness, Brightness.light);
  });
}
