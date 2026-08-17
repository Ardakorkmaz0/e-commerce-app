import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/main/presentation/providers/tab_provider.dart';
import 'package:ecommerce_mobile/features/main/presentation/tabs/cart_tab.dart';
import 'package:ecommerce_mobile/features/main/presentation/tabs/home_tab.dart';
import 'package:ecommerce_mobile/features/main/presentation/tabs/products_tab.dart';
import 'package:ecommerce_mobile/features/main/presentation/tabs/profile_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Mobile equivalent of the web's SiteNavbar + store layout.
// Top navbar links (Home / Products / Cart / Account) → BottomNavigationBar
class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  // IndexedStack keeps all tabs alive in memory so scroll position
  // and state are preserved when switching between tabs.
  static const List<Widget> _tabs = <Widget>[
    HomeTab(),
    ProductsTab(),
    CartTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Held in a provider so the tabs themselves can switch (see tab_provider).
    final currentIndex = ref.watch(selectedTabProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (int index) {
          ref.read(selectedTabProvider.notifier).state = index;
        },
        // Highlight selected tab with the web's accent color
        indicatorColor: AppColors.primary.withAlpha(30),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view, color: AppColors.primary),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart, color: AppColors.primary),
            label: 'Cart',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
