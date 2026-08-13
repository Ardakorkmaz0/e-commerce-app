import 'package:ecommerce_mobile/app/router.dart';
import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class EcommerceApp extends StatelessWidget {
  const EcommerceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Vader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(), // web'in #4f46e5 indigo teması
      routerConfig: appRouter,
    );
  }
}
