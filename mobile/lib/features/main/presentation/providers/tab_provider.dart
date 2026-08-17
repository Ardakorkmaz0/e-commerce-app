import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which bottom-navigation tab is showing.
///
/// Lifted out of MainScreen so other tabs can navigate: the home tab's
/// "See all" link and its cart icon both switch tabs rather than pushing a
/// new screen, which would hide the bottom bar.
final selectedTabProvider = StateProvider<int>((ref) => 0);

abstract final class MainTab {
  static const int home = 0;
  static const int products = 1;
  static const int cart = 2;
  static const int profile = 3;
}
