import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/main/presentation/providers/tab_provider.dart';
import 'package:ecommerce_mobile/features/products/data/models/product_model.dart';
import 'package:ecommerce_mobile/features/products/presentation/providers/product_provider.dart';
import 'package:ecommerce_mobile/shared/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Web equivalent: / (store home page) + search bar and cart icon from SiteNavbar
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Only searches paginate here: the featured preview is capped at 8.
    if (ref.read(productQueryProvider).search.isEmpty) return;
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref
          .read(productListProvider(ref.read(productQueryProvider)).notifier)
          .loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(productQueryProvider);
    final categories = ref.watch(categoriesProvider);
    final products = ref.watch(productListProvider(query));
    final isSearching = query.search.isNotEmpty;

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
                onPressed: () => ref.read(selectedTabProvider.notifier).state =
                    MainTab.cart,
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
          controller: _scrollController,
          // Keeps pull-to-refresh working even when the preview is short
          // enough to fit the screen without scrolling.
          physics: const AlwaysScrollableScrollPhysics(),
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
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        isSearching
                            ? 'Results for "${query.search}"'
                            : 'Featured Products',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isSearching)
                      // Total from the API, not the number loaded so far.
                      Text(
                        '${products.valueOrNull?.total ?? 0} found',
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 12,
                        ),
                      )
                    else
                      // The featured list is a preview; the full catalogue
                      // lives in the Products tab.
                      TextButton(
                        onPressed: () =>
                            ref.read(selectedTabProvider.notifier).state =
                                MainTab.products,
                        child: const Text('See all'),
                      ),
                  ],
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

                // A search must show everything it matched, so the preview
                // cap only applies to the featured list.
                final preview = isSearching
                    ? state.items
                    : state.items.take(8).toList();

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

            if (isSearching)
              // Search results keep loading as the shopper scrolls.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: products.valueOrNull?.loadingMore ?? false
                        ? const CircularProgressIndicator()
                        : (products.valueOrNull?.hasNext ?? false)
                              ? const SizedBox.shrink()
                              : const Text(
                                  'That is everything.',
                                  style: TextStyle(
                                    color: AppColors.mutedText,
                                    fontSize: 12,
                                  ),
                                ),
                  ),
                ),
              )
            else
              // Dead end otherwise: the preview stops at 8 products with no
              // hint that the rest are one tab away.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                  child: OutlinedButton.icon(
                    onPressed: () => ref
                        .read(selectedTabProvider.notifier)
                        .state = MainTab.products,
                    icon: const Icon(Icons.grid_view_outlined, size: 18),
                    label: const Text('See all products'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
