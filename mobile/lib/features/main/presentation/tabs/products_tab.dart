import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/products/presentation/filter_sheet.dart';
import 'package:ecommerce_mobile/features/products/presentation/providers/product_provider.dart';
import 'package:ecommerce_mobile/shared/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Web equivalent: /products page, including its filter panel and sorting.
class ProductsTab extends ConsumerStatefulWidget {
  const ProductsTab({super.key});

  @override
  ConsumerState<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends ConsumerState<ProductsTab> {
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
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Start the next page before the shopper reaches the very bottom.
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(productListProvider(ref.read(productQueryProvider)).notifier)
          .loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Shares the filter state with the home tab, so a category picked there
    // is still applied here.
    final query = ref.watch(productQueryProvider);
    final listing = ref.watch(productListProvider(query));
    final filterCount = query.activeFilterCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Products',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: <Widget>[
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              IconButton(
                tooltip: 'Filters',
                icon: const Icon(Icons.tune),
                onPressed: () => FilterSheet.show(context),
              ),
              if (filterCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$filterCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
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
      body: listing.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load products.')),
        data: (ProductListState state) {
          if (state.items.isEmpty) {
            return _EmptyResults(
              onClear: query.hasFilters
                  ? () => ref.read(productQueryProvider.notifier).state =
                        query.cleared()
                  : null,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(productListProvider(query));
              ref.invalidate(facetsProvider(query));
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: <Widget>[
                        Text(
                          '${state.total} product${state.total == 1 ? '' : 's'}',
                          style: const TextStyle(color: AppColors.mutedText),
                        ),
                        const Spacer(),
                        if (query.hasFilters)
                          TextButton(
                            onPressed: () =>
                                ref.read(productQueryProvider.notifier).state =
                                    query.cleared(),
                            child: const Text('Clear filters'),
                          ),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                    children: state.items
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
                ),

                // Spinner while the next page arrives, nothing once the
                // catalog is exhausted.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Center(
                      child: state.loadingMore
                          ? const CircularProgressIndicator()
                          : state.hasNext
                              ? const SizedBox.shrink()
                              : Text(
                                  'That is everything.',
                                  style: TextStyle(
                                    color: AppColors.mutedText,
                                    fontSize: 12,
                                  ),
                                ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({this.onClear});

  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No products matched your filters.',
            style: TextStyle(color: AppColors.mutedText),
          ),
          if (onClear != null) ...<Widget>[
            const SizedBox(height: 12),
            TextButton(onPressed: onClear, child: const Text('Clear filters')),
          ],
        ],
      ),
    );
  }
}
