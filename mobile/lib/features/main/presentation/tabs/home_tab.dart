import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

// Web equivalent: / (store home page) + search bar and cart icon from SiteNavbar
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  // TODO: replace with real categories from the backend
  static const List<String> _categories = <String>[
    'All',
    'Electronics',
    'Clothing',
    'Books',
    'Home',
    'Sports',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Mobile equivalent of the web navbar
      appBar: AppBar(
        title: const Text(
          'VADER',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        actions: <Widget>[
          // Web: navbar cart button with badge
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              IconButton(
                onPressed: () {}, // TODO: switch to cart tab
                icon: const Icon(Icons.shopping_cart_outlined),
                tooltip: 'Cart',
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '0',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          // ── Search bar ────────────────────────────────────────────────
          // Web: .site-search → search form with gradient button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: SearchBar(
                hintText: 'Search products...',
                leading: const Icon(Icons.search),
                padding: const WidgetStatePropertyAll<EdgeInsets>(
                  EdgeInsets.symmetric(horizontal: 16),
                ),
                overlayColor: WidgetStatePropertyAll<Color>(
                  AppColors.primary.withAlpha(20),
                ),
                elevation: const WidgetStatePropertyAll<double>(0),
                side: WidgetStatePropertyAll<BorderSide>(
                  BorderSide(color: AppColors.border),
                ),
                shape: WidgetStatePropertyAll<OutlinedBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),

          // ── Categories ────────────────────────────────────────────────
          // Web: navbar Categories link and /categories page
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 0, 8),
              child: Text(
                'Categories',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (BuildContext context, int index) {
                  final bool selected = index == 0;
                  return FilterChip(
                    label: Text(_categories[index]),
                    selected: selected,
                    onSelected: (_) {}, // TODO: apply category filter
                    selectedColor: AppColors.primary.withAlpha(30),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: selected ? AppColors.primary : null,
                      fontWeight: selected ? FontWeight.bold : null,
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Featured products ─────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Featured Products',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // TODO: replace with real product cards once the backend is ready
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
              children: List<Widget>.generate(6, (int index) {
                return _ProductCardPlaceholder(index: index);
              }),
            ),
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
    );
  }
}

// Skeleton card shown until real product data is available from the backend
class _ProductCardPlaceholder extends StatelessWidget {
  const _ProductCardPlaceholder({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Image area
          Expanded(
            child: Container(
              color: AppColors.primary.withAlpha(20),
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 48,
                  color: AppColors.primary.withAlpha(100),
                ),
              ),
            ),
          ),
          // Product info
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(60),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
