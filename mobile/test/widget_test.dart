import 'package:ecommerce_mobile/app/app.dart';
import 'package:ecommerce_mobile/core/storage/token_storage.dart';
import 'package:ecommerce_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for secure storage, which has no platform implementation under
/// `flutter test`. Reports no stored session so the startup gate resolves
/// immediately and sends the app to the sign-in screen.
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

void main() {
  testWidgets('starts on the sign-in screen when no session is stored', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          tokenStorageProvider.overrideWithValue(_SignedOutStorage()),
        ],
        child: const EcommerceApp(),
      ),
    );

    // The app opens on the splash gate, which routes on once the session
    // check finishes; settling lets that navigation run.
    await tester.pumpAndSettle();

    expect(find.text('VADER'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
  });
}
