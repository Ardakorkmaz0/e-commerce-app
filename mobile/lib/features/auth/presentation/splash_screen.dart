import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Startup gate.
///
/// The app used to open straight onto the sign-in screen, which made the
/// stored session pointless: a remembered user still had to sign in. This
/// waits for [authProvider] to resolve, then sends them to the right place.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<Object?>>(authProvider, (previous, next) {
      // Navigation cannot happen during build, so it is driven from the
      // listener once the session has been restored or ruled out.
      next.whenOrNull(
        data: (user) => context.goNamed(user != null ? 'main' : 'signIn'),
        error: (_, _) => context.goNamed('signIn'),
      );
    });

    // Handles the case where the provider already resolved before this
    // screen mounted, so the listener above never fires.
    final auth = ref.read(authProvider);
    if (!auth.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.goNamed(auth.valueOrNull != null ? 'main' : 'signIn');
        }
      });
    }

    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.shopping_bag_outlined,
              size: 72,
              color: AppColors.primary,
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
