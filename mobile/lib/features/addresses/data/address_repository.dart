import 'package:dio/dio.dart';
import 'package:ecommerce_mobile/core/network/api_client.dart';
import 'package:ecommerce_mobile/core/storage/token_storage.dart';
import 'package:ecommerce_mobile/features/addresses/data/models/delivery_address_model.dart';

class AddressRepository {
  AddressRepository({
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

  Future<List<DeliveryAddress>> fetchAddresses() async {
    final response = await _apiClient.dio.get(
      'auth/addresses/',
      options: await _authOptions(),
    );
    return (response.data as List<dynamic>)
        .map((item) => DeliveryAddress.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DeliveryAddress> createAddress(DeliveryAddressInput input) async {
    final response = await _apiClient.dio.post(
      'auth/addresses/',
      data: input.toJson(),
      options: await _authOptions(),
    );
    return DeliveryAddress.fromJson(response.data as Map<String, dynamic>);
  }

  /// PATCH with the whole form, used by the edit screen. The web has had
  /// this since the start; mobile could only add and delete.
  Future<DeliveryAddress> updateAddress(
    int addressId,
    DeliveryAddressInput input,
  ) async {
    final response = await _apiClient.dio.patch(
      'auth/addresses/$addressId/',
      data: input.toJson(),
      options: await _authOptions(),
    );
    return DeliveryAddress.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DeliveryAddress> setDefaultAddress(int addressId) async {
    final response = await _apiClient.dio.patch(
      'auth/addresses/$addressId/',
      data: const <String, dynamic>{'is_default': true},
      options: await _authOptions(),
    );
    return DeliveryAddress.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteAddress(int addressId) async {
    await _apiClient.dio.delete(
      'auth/addresses/$addressId/',
      options: await _authOptions(),
    );
  }
}

String describeAddressError(Object error) {
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

    final messages = _flattenMessages(error.response?.data);
    if (messages.isNotEmpty) {
      return messages.join(' ');
    }
  }

  return 'Could not save the delivery address. Please try again.';
}

List<String> _flattenMessages(dynamic value) {
  if (value == null) return const <String>[];
  if (value is String) return <String>[value];
  if (value is List<dynamic>) {
    return value.expand<String>(_flattenMessages).toList();
  }
  if (value is Map<dynamic, dynamic>) {
    return value.values.expand<String>(_flattenMessages).toList();
  }
  return <String>[value.toString()];
}
