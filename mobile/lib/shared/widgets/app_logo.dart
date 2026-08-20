import 'package:flutter/material.dart';

/// The site logo, the same mark the web header and the launcher icon use.
///
/// The asset has a transparent surround, so it sits on the sign-in card
/// and on a dark background without carrying a pale square with it.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Read out as the brand rather than announced as a picture.
      semanticLabel: 'VADER',
    );
  }
}
