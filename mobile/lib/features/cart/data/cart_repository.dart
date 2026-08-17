import 'package:dio/dio.dart';
import 'package:ecommerce_mobile/core/network/api_client.dart';
import 'package:ecommerce_mobile/core/storage/token_storage.dart';
import 'package:ecommerce_mobile/features/cart/data/models/cart_model.dart';

class CartRepository {
  CartRepository({required ApiClient apiClient, required TokenStorage tokenStorage})
    : _apiClient = apiClient,
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

  // Every endpoint returns the whole cart, so one response keeps the badge,
  // the totals and the lines in step without a follow-up request.

  Future<Cart> fetchCart() async {
    final response = await _apiClient.dio.get(
      'cart/',
      options: await _authOptions(),
    );
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  /// [variantId] is required for products with options and rejected for the
  /// rest, so it is only sent when the caller actually picked one.
  Future<Cart> addToCart({
    required int productId,
    int quantity = 1,
    int? variantId,
  }) async {
    final response = await _apiClient.dio.post(
      'cart/items/',
      data: <String, dynamic>{
        'product_id': productId,
        'quantity': quantity,
        if (variantId != null) 'variant_id': variantId,
      },
      options: await _authOptions(),
    );
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Cart> setQuantity({required int itemId, required int quantity}) async {
    final response = await _apiClient.dio.patch(
      'cart/items/$itemId/',
      data: <String, dynamic>{'quantity': quantity},
      options: await _authOptions(),
    );
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Cart> removeItem(int itemId) async {
    final response = await _apiClient.dio.delete(
      'cart/items/$itemId/',
      options: await _authOptions(),
    );
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Cart> clearCart() async {
    final response = await _apiClient.dio.delete(
      'cart/',
      options: await _authOptions(),
    );
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }
}

/// The API explains stock problems in `detail`; show that rather than a
/// generic apology.
String describeCartError(Object error) {
  if (error is StateError) {
    return 'Please sign in to use your cart.';
  }

  if (error is DioException) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Could not connect to the server.';
    }
    if (error.response?.statusCode == 401) {
      return 'Please sign in to use your cart.';
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

  return 'Could not update your cart.';
}
