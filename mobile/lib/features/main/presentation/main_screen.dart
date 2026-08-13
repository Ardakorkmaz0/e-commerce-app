import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/main/presentation/tabs/cart_tab.dart';
import 'package:ecommerce_mobile/features/main/presentation/tabs/home_tab.dart';
import 'package:ecommerce_mobile/features/main/presentation/tabs/products_tab.dart';
import 'package:ecommerce_mobile/features/main/presentation/tabs/profile_tab.dart';
import 'package:flutter/material.dart';

// Mobile equivalent of the web's SiteNavbar + store layout.
// Top navbar links (Home / Categories / Products / Account) → BottomNavigationBar
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // IndexedStack keeps all tabs alive in memory so scroll position
  // and state are preserved when switching between tabs.
  static const List<Widget> _tabs = <Widget>[
    HomeTab(),
    ProductsTab(),
    CartTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() => _currentIndex = index);
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
