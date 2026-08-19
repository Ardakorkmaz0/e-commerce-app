import 'package:dio/dio.dart';
import 'package:ecommerce_mobile/core/network/api_client.dart';
import 'package:ecommerce_mobile/core/storage/token_storage.dart';
import 'package:ecommerce_mobile/features/orders/data/models/order_model.dart';

class OrderRepository {
  OrderRepository({
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

  List<dynamic> _rows(dynamic data) {
    return data is Map<String, dynamic>
        ? data['results'] as List<dynamic>
        : data as List<dynamic>;
  }

  Future<List<Order>> fetchOrders() async {
    final response = await _apiClient.dio.get(
      'orders/',
      options: await _authOptions(),
    );
    return _rows(response.data)
        .map((item) => Order.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Order> fetchOrder(String orderNumber) async {
    final response = await _apiClient.dio.get(
      'orders/$orderNumber/',
      options: await _authOptions(),
    );
    return Order.fromJson(response.data as Map<String, dynamic>);
  }

  /// Turns the cart into an order and charges the card.
  ///
  /// [idempotencyKey] is generated once when the checkout screen opens, so
  /// a repeated tap returns the order already placed instead of opening a
  /// second one.
  Future<Order> placeOrder({
    required int addressId,
    required int paymentMethodId,
    required String idempotencyKey,
  }) async {
    final response = await _apiClient.dio.post(
      'orders/',
      data: <String, dynamic>{
        'address_id': addressId,
        'payment_method_id': paymentMethodId,
        'idempotency_key': idempotencyKey,
      },
      options: await _authOptions(),
    );
    return Order.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Order> cancel(String orderNumber) async {
    final response = await _apiClient.dio.post(
      'orders/$orderNumber/cancel/',
      options: await _authOptions(),
    );
    return Order.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Order> confirmDelivery(String orderNumber) async {
    final response = await _apiClient.dio.post(
      'orders/$orderNumber/delivered/',
      options: await _authOptions(),
    );
    return Order.fromJson(response.data as Map<String, dynamic>);
  }

  // ── Seller ────────────────────────────────────────────────────────

  Future<List<SellerOrder>> fetchSellerOrders() async {
    final response = await _apiClient.dio.get(
      'seller/orders/',
      options: await _authOptions(),
    );
    return _rows(response.data)
        .map((item) => SellerOrder.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Posts this seller's parcel; other sellers' lines are untouched.
  Future<void> ship(String orderNumber) async {
    await _apiClient.dio.post(
      'seller/orders/$orderNumber/ship/',
      options: await _authOptions(),
    );
  }
}

/// The API writes these for the shopper — "Your card was declined.",
/// "only 2 left" — so they are shown as they arrive.
String describeOrderError(Object error) {
  if (error is StateError) {
    return 'Please sign in again.';
  }

  if (error is DioException) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Could not connect to the server.';
    }
    if (error.response?.statusCode == 401) {
      return 'Please sign in again.';
    }
    if (error.response?.statusCode == 404) {
      return 'This order could not be found.';
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

  return 'The order could not be placed.';
}
