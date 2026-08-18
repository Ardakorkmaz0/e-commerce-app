import 'package:dio/dio.dart';
import 'package:ecommerce_mobile/core/network/api_client.dart';
import 'package:ecommerce_mobile/core/storage/token_storage.dart';
import 'package:ecommerce_mobile/features/seller/data/models/seller_variant_model.dart';

/// Everything under `/seller/products/<slug>/variants/`.
///
/// The product comes from the URL on the server side too, so a slug that
/// belongs to another seller simply 404s rather than leaking anything.
class SellerVariantRepository {
  SellerVariantRepository({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
  }) : _apiClient = apiClient,
       _tokenStorage = tokenStorage;

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<Options> _authOptions() async {
    final token = await _tokenStorage.readAccessToken();
    if (token == null) {
      throw StateError('Not authenticated');
    }
    return Options(headers: <String, String>{'Authorization': 'Bearer $token'});
  }

  /// Every attribute with its values, so the picker can be narrowed to the
  /// product's category on the device.
  Future<List<SellerAttribute>> fetchAttributes() async {
    final response = await _apiClient.dio.get('attributes/');
    final data = response.data;
    final items = data is Map<String, dynamic>
        ? data['results'] as List<dynamic>
        : data as List<dynamic>;
    return items
        .map((item) => SellerAttribute.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<SellerVariant>> fetchVariants(String slug) async {
    final response = await _apiClient.dio.get(
      'seller/products/$slug/variants/',
      options: await _authOptions(),
    );
    final data = response.data;
    final items = data is Map<String, dynamic>
        ? data['results'] as List<dynamic>
        : data as List<dynamic>;
    return items
        .map((item) => SellerVariant.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Builds every combination of [valueIds] that does not exist yet.
  ///
  /// Returns how many rows were created, so the screen can say what
  /// happened instead of silently refreshing.
  Future<int> generate(String slug, List<int> valueIds) async {
    final response = await _apiClient.dio.post(
      'seller/products/$slug/variants/generate/',
      data: <String, dynamic>{'value_ids': valueIds},
      options: await _authOptions(),
    );
    final data = response.data as Map<String, dynamic>;
    return data['created'] as int? ?? 0;
  }

  /// Adds one option the seller typed, creating its group when they typed
  /// a new one. Sellers cannot reach the Django admin, so this is the only
  /// way for them to say "this shoe also comes in 45".
  ///
  /// Returns true when a new value was created, false when one with the
  /// same name already existed and was reused.
  Future<bool> addOption(
    String slug, {
    int? attributeId,
    String attributeName = '',
    required String name,
    String swatchColor = '',
  }) async {
    final response = await _apiClient.dio.post(
      'seller/products/$slug/options/',
      data: <String, dynamic>{
        if (attributeId != null) 'attribute_id': attributeId,
        'attribute_name': attributeName,
        'name': name,
        'swatch_color': swatchColor,
      },
      options: await _authOptions(),
    );
    final data = response.data as Map<String, dynamic>;
    return data['created'] as bool? ?? false;
  }

  /// [price] and [description] are nullable overrides: an empty box means
  /// "use the product's", which has to travel as null, not "".
  Future<void> update(
    String slug,
    int variantId, {
    required String? price,
    required int stock,
    required String description,
    required String imageUrl,
    required bool isActive,
  }) async {
    await _apiClient.dio.patch(
      'seller/products/$slug/variants/$variantId/',
      data: <String, dynamic>{
        'price': price,
        'stock': stock,
        'description': description,
        'image_url': imageUrl,
        'is_active': isActive,
      },
      options: await _authOptions(),
    );
  }

  Future<void> remove(String slug, int variantId) async {
    await _apiClient.dio.delete(
      'seller/products/$slug/variants/$variantId/',
      options: await _authOptions(),
    );
  }
}

/// The API explains what was wrong in the field errors; show that rather
/// than a generic apology.
String describeVariantError(Object error) {
  if (error is StateError) {
    return 'Please sign in again.';
  }

  if (error is DioException) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Could not connect to the server.';
    }
    if (error.response?.statusCode == 403) {
      return 'You need a seller account to do this.';
    }
    if (error.response?.statusCode == 404) {
      return 'This product is not yours.';
    }

    final data = error.response?.data;
    if (data is Map) {
      final messages = data.values
          .expand((value) => value is List ? value : <dynamic>[value])
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .join(' ');
      if (messages.isNotEmpty) return messages;
    }
  }

  return 'Could not save the variant.';
}
