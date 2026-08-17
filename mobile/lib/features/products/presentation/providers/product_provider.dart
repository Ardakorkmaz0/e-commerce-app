import 'package:ecommerce_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:ecommerce_mobile/features/products/data/models/facet_model.dart';
import 'package:ecommerce_mobile/features/products/data/models/product_model.dart';
import 'package:ecommerce_mobile/features/products/data/product_repository.dart';
// Flutter's foundation also exports a `Category` annotation, which would
// clash with the catalog's Category model.
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Reuses the ApiClient and TokenStorage already provided for auth, so the
// whole app shares one Dio instance and one base URL.
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(productRepositoryProvider).fetchCategories();
});

/// Sort options, matching the web's SortSelect.
const sortOptions = <String, String>{
  '': 'Newest',
  'oldest': 'Oldest',
  'price_asc': 'Price: low to high',
  'price_desc': 'Price: high to low',
  'name': 'Name: A to Z',
  'stock_desc': 'Most in stock',
};

/// Everything the catalog screens filter by. Immutable so Riverpod can use
/// it as a family key.
@immutable
class ProductQuery {
  const ProductQuery({
    this.category = '',
    this.search = '',
    this.sort = '',
    this.priceRange = '',
    this.availability = '',
    this.attributes = const <String, String>{},
  });

  final String category;
  final String search;
  final String sort;
  final String priceRange;
  final String availability;

  /// Attribute slug to a comma separated list of value slugs, exactly as it
  /// travels in the query string: {'brand': 'rtx,amd'}.
  final Map<String, String> attributes;

  ProductQuery copyWith({
    String? category,
    String? search,
    String? sort,
    String? priceRange,
    String? availability,
    Map<String, String>? attributes,
  }) {
    return ProductQuery(
      category: category ?? this.category,
      search: search ?? this.search,
      sort: sort ?? this.sort,
      priceRange: priceRange ?? this.priceRange,
      availability: availability ?? this.availability,
      attributes: attributes ?? this.attributes,
    );
  }

  /// Changing category invalidates attribute filters: they are scoped to a
  /// category, so keeping them would silently empty the list.
  ProductQuery withCategory(String value) {
    return ProductQuery(
      category: value,
      search: search,
      sort: sort,
      priceRange: priceRange,
      availability: availability,
    );
  }

  /// Everything except the category and search, which the toolbar shows.
  bool get hasFilters =>
      priceRange.isNotEmpty ||
      availability.isNotEmpty ||
      attributes.values.any((value) => value.isNotEmpty);

  int get activeFilterCount {
    var total = 0;
    if (priceRange.isNotEmpty) total++;
    if (availability.isNotEmpty) total++;
    for (final value in attributes.values) {
      total += value.split(',').where((item) => item.isNotEmpty).length;
    }
    return total;
  }

  /// Toggles one attribute value on or off, mirroring the web's checkboxes.
  ProductQuery toggleAttribute(String attributeSlug, String valueSlug) {
    final next = Map<String, String>.from(attributes);
    final selected = (next[attributeSlug] ?? '')
        .split(',')
        .where((item) => item.isNotEmpty)
        .toList();

    if (selected.contains(valueSlug)) {
      selected.remove(valueSlug);
    } else {
      selected.add(valueSlug);
    }

    if (selected.isEmpty) {
      next.remove(attributeSlug);
    } else {
      next[attributeSlug] = selected.join(',');
    }

    return copyWith(attributes: next);
  }

  bool isAttributeSelected(String attributeSlug, String valueSlug) {
    return (attributes[attributeSlug] ?? '').split(',').contains(valueSlug);
  }

  ProductQuery cleared() => ProductQuery(
        category: category,
        search: search,
        sort: sort,
      );

  @override
  bool operator ==(Object other) =>
      other is ProductQuery &&
      other.category == category &&
      other.search == search &&
      other.sort == sort &&
      other.priceRange == priceRange &&
      other.availability == availability &&
      mapEquals(other.attributes, attributes);

  @override
  int get hashCode => Object.hash(
        category,
        search,
        sort,
        priceRange,
        availability,
        Object.hashAll(
          attributes.entries.map((entry) => '${entry.key}=${entry.value}'),
        ),
      );
}

final productQueryProvider =
    StateProvider<ProductQuery>((ref) => const ProductQuery());

final facetsProvider =
    FutureProvider.family<Facets, ProductQuery>((ref, query) {
  return ref.watch(productRepositoryProvider).fetchFacets(
        category: query.category,
        search: query.search,
      );
});

/// A growing list of products for one filter set. Loads page by page so the
/// grid can keep appending as the shopper scrolls.
class ProductListState {
  const ProductListState({
    this.items = const <Product>[],
    this.total = 0,
    this.page = 0,
    this.hasNext = true,
    this.loadingMore = false,
  });

  final List<Product> items;
  final int total;
  final int page;
  final bool hasNext;
  final bool loadingMore;

  ProductListState copyWith({
    List<Product>? items,
    int? total,
    int? page,
    bool? hasNext,
    bool? loadingMore,
  }) {
    return ProductListState(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

class ProductListNotifier
    extends FamilyAsyncNotifier<ProductListState, ProductQuery> {
  @override
  Future<ProductListState> build(ProductQuery query) async {
    final page = await _fetch(query, 1);
    return ProductListState(
      items: page.results,
      total: page.count,
      page: 1,
      hasNext: page.hasNext,
    );
  }

  Future<ProductPage> _fetch(ProductQuery query, int page) {
    return ref.read(productRepositoryProvider).fetchProducts(
          category: query.category,
          search: query.search,
          sort: query.sort,
          priceRange: query.priceRange,
          availability: query.availability,
          attributes: query.attributes,
          page: page,
        );
  }

  /// Appends the next page. Safe to call repeatedly from a scroll listener:
  /// it returns immediately while a load is already running or exhausted.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasNext) return;

    state = AsyncData(current.copyWith(loadingMore: true));

    try {
      final next = await _fetch(arg, current.page + 1);
      state = AsyncData(
        current.copyWith(
          items: <Product>[...current.items, ...next.results],
          page: current.page + 1,
          hasNext: next.hasNext,
          loadingMore: false,
        ),
      );
    } catch (_) {
      // Keep what is already on screen; the next scroll can retry.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

final productListProvider = AsyncNotifierProvider.family<ProductListNotifier,
    ProductListState, ProductQuery>(ProductListNotifier.new);

/// A single product, used by the detail screen.
final productDetailProvider =
    FutureProvider.family<Product, String>((ref, slug) {
  return ref.watch(productRepositoryProvider).fetchProduct(slug);
});

/// This customer's rating for one seller, plus the public average.
final sellerRatingProvider =
    FutureProvider.family<SellerRating, int>((ref, sellerId) {
  return ref.watch(productRepositoryProvider).fetchSellerRating(sellerId);
});

/// The signed-in seller's own listings.
final sellerProductsProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).fetchSellerProducts();
});
