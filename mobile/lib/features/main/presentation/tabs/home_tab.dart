import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/products/data/models/product_model.dart';
import 'package:ecommerce_mobile/features/products/presentation/providers/product_provider.dart';
import 'package:ecommerce_mobile/shared/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Web equivalent: / (store home page) + search bar and cart icon from SiteNavbar
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(productQueryProvider);
    final categories = ref.watch(categoriesProvider);
    final products = ref.watch(productListProvider(query));

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
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          ref.invalidate(productListProvider(query));
        },
        child: CustomScrollView(
          slivers: <Widget>[
            // ── Search bar ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SearchBar(
                  hintText: 'Search products...',
                  leading: const Icon(Icons.search),
                  onSubmitted: (value) {
                    ref.read(productQueryProvider.notifier).state =
                        query.copyWith(search: value.trim());
                  },
                  onChanged: (value) {
                    // Clearing the box restores the full list without
                    // needing to submit.
                    if (value.isEmpty && query.search.isNotEmpty) {
                      ref.read(productQueryProvider.notifier).state =
                          query.copyWith(search: '');
                    }
                  },
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
                child: categories.when(
                  loading: () => const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (_, _) => const Center(
                    child: Text('Could not load categories.'),
                  ),
                  data: (List<Category> items) {
                    // "All" is a UI-only entry that clears the filter.
                    final labels = <String?>[null, ...items.map((c) => c.slug)];
                    final names = <String>['All', ...items.map((c) => c.name)];

                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: names.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final slug = labels[index] ?? '';
                        final selected = query.category == slug;
                        return FilterChip(
                          label: Text(names[index]),
                          selected: selected,
                          onSelected: (_) {
                            // withCategory drops attribute filters: they are
                            // scoped to a category and would empty the list.
                            ref.read(productQueryProvider.notifier).state =
                                query.withCategory(slug);
                          },
                          selectedColor: AppColors.primary.withAlpha(30),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: selected ? AppColors.primary : null,
                            fontWeight: selected ? FontWeight.bold : null,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // ── Products ──────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  query.search.isEmpty
                      ? 'Featured Products'
                      : 'Results for "${query.search}"',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            products.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Could not load products.')),
              ),
              data: (ProductListState state) {
                if (state.items.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('No products found.')),
                  );
                }

                // The home tab shows a preview; the Products tab has the
                // full, infinitely scrolling list.
                final preview = state.items.take(8).toList();

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                    children: preview
                        .map(
                          (product) => ProductCard(
                            product: product,
                            onTap: () => context.pushNamed(
                              'productDetail',
                              pathParameters: {'slug': product.slug},
                            ),
                          ),
                        )
                        .toList(),
                  ),
                );
              },
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
          ],
        ),
      ),
    );
  }
}
