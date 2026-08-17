import 'package:dio/dio.dart';
import 'package:ecommerce_mobile/core/network/api_client.dart';
import 'package:ecommerce_mobile/core/storage/token_storage.dart';
import 'package:ecommerce_mobile/features/products/data/models/facet_model.dart';
import 'package:ecommerce_mobile/features/products/data/models/product_model.dart';

class ProductRepository {
  ProductRepository({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
  })  : _apiClient = apiClient,
        _tokenStorage = tokenStorage;

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  /// Seller and rating endpoints need the customer's JWT.
  Future<Options> _authOptions() async {
    final token = await _tokenStorage.readAccessToken();
    if (token == null) {
      throw StateError('Not authenticated');
    }
    return Options(headers: <String, String>{'Authorization': 'Bearer $token'});
  }

  // ── Public catalog ────────────────────────────────────────────────

  /// GET /products/ — the catalog is public, so no token is attached.
  Future<ProductPage> fetchProducts({
    String? category,
    String? search,
    String? sort,
    String? priceRange,
    String? availability,
    Map<String, String> attributes = const <String, String>{},
    int page = 1,
  }) async {
    final response = await _apiClient.dio.get(
      'products/',
      queryParameters: <String, dynamic>{
        'page': page,
        if (category != null && category.isNotEmpty) 'category': category,
        if (search != null && search.isNotEmpty) 'q': search,
        if (sort != null && sort.isNotEmpty) 'sort': sort,
        if (priceRange != null && priceRange.isNotEmpty)
          'price_range': priceRange,
        if (availability != null && availability.isNotEmpty)
          'availability': availability,
        ...attributes,
      },
    );
    return ProductPage.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET `/products/<slug>/`
  Future<Product> fetchProduct(String slug) async {
    final response = await _apiClient.dio.get('products/$slug/');
    return Product.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /categories/
  Future<List<Category>> fetchCategories() async {
    final response = await _apiClient.dio.get('categories/');
    return (response.data as List<dynamic>)
        .map((item) => Category.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// GET /facets/ — describes the filter sheet for the current category.
  Future<Facets> fetchFacets({String? category, String? search}) async {
    final response = await _apiClient.dio.get(
      'facets/',
      queryParameters: <String, dynamic>{
        if (category != null && category.isNotEmpty) 'category': category,
        if (search != null && search.isNotEmpty) 'q': search,
      },
    );
    return Facets.fromJson(response.data as Map<String, dynamic>);
  }

  // ── Seller panel ──────────────────────────────────────────────────

  /// GET /seller/products/ — only the signed-in seller's own listings.
  Future<List<Product>> fetchSellerProducts() async {
    final response = await _apiClient.dio.get(
      'seller/products/',
      options: await _authOptions(),
    );
    final data = response.data;
    // This endpoint is unpaginated, but tolerate either shape.
    final items = data is Map<String, dynamic>
        ? data['results'] as List<dynamic>
        : data as List<dynamic>;
    return items
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> createProduct(Map<String, dynamic> payload) async {
    await _apiClient.dio.post(
      'seller/products/',
      data: payload,
      options: await _authOptions(),
    );
  }

  Future<void> updateProduct(String slug, Map<String, dynamic> payload) async {
    await _apiClient.dio.patch(
      'seller/products/$slug/',
      data: payload,
      options: await _authOptions(),
    );
  }

  Future<void> deleteProduct(String slug) async {
    await _apiClient.dio.delete(
      'seller/products/$slug/',
      options: await _authOptions(),
    );
  }

  // ── Seller ratings ────────────────────────────────────────────────

  /// GET `/sellers/<id>/rating/` — the seller's average plus this user's own.
  Future<SellerRating> fetchSellerRating(int sellerId) async {
    final response = await _apiClient.dio.get(
      'sellers/$sellerId/rating/',
      options: await _authOptions(),
    );
    return SellerRating.fromJson(response.data as Map<String, dynamic>);
  }

  /// PUT is an idempotent upsert: rating again replaces the old score.
  Future<SellerRating> rateSeller(int sellerId, int score) async {
    final response = await _apiClient.dio.put(
      'sellers/$sellerId/rating/',
      data: <String, dynamic>{'score': score},
      options: await _authOptions(),
    );
    return SellerRating.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> clearSellerRating(int sellerId) async {
    await _apiClient.dio.delete(
      'sellers/$sellerId/rating/',
      options: await _authOptions(),
    );
  }
}
