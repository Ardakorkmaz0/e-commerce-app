import 'package:ecommerce_mobile/app/router.dart';
import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/core/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EcommerceApp extends ConsumerWidget {
  const EcommerceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Both themes are always supplied; themeMode decides which is used, and
    // ThemeMode.system hands that decision to the device.
    return MaterialApp.router(
      title: 'Vader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: appRouter,
    );
  }
}
