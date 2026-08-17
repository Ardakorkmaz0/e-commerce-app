import 'package:dio/dio.dart';
import 'package:ecommerce_mobile/core/network/api_client.dart';
import 'package:ecommerce_mobile/core/storage/token_storage.dart';
import 'package:ecommerce_mobile/features/payments/data/models/payment_method_model.dart';

class PaymentRepository {
  PaymentRepository({
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

  Future<List<PaymentMethod>> fetchPaymentMethods() async {
    final response = await _apiClient.dio.get(
      'auth/payment-methods/',
      options: await _authOptions(),
    );
    return (response.data as List<dynamic>)
        .map((item) => PaymentMethod.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Posts the card once. The server validates it, keeps the brand, the
  /// last four digits and a token, and the number is never sent back or
  /// written to the device.
  Future<PaymentMethod> addPaymentMethod(PaymentMethodInput input) async {
    final response = await _apiClient.dio.post(
      'auth/payment-methods/',
      data: input.toJson(),
      options: await _authOptions(),
    );
    return PaymentMethod.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PaymentMethod> setDefaultPaymentMethod(int methodId) async {
    final response = await _apiClient.dio.patch(
      'auth/payment-methods/$methodId/',
      data: const <String, dynamic>{'is_default': true},
      options: await _authOptions(),
    );
    return PaymentMethod.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deletePaymentMethod(int methodId) async {
    await _apiClient.dio.delete(
      'auth/payment-methods/$methodId/',
      options: await _authOptions(),
    );
  }
}

/// Turns an API failure into one readable line, preferring the server's own
/// field message so card validation errors reach the shopper intact.
String describePaymentError(Object error) {
  if (error is StateError) {
    return 'Your session has expired. Please sign in again.';
  }

  if (error is DioException) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Could not connect to the server. Please try again.';
    }

    if (error.response?.statusCode == 401) {
      return 'Your session has expired. Please sign in again.';
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

  return 'Could not save this card. Please try again.';
}
