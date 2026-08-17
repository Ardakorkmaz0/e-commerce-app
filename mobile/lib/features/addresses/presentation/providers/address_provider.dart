import 'package:ecommerce_mobile/features/addresses/data/address_repository.dart';
import 'package:ecommerce_mobile/features/addresses/data/models/delivery_address_model.dart';
import 'package:ecommerce_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final deliveryAddressRepositoryProvider = Provider<AddressRepository>((ref) {
  return AddressRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

class DeliveryAddressesNotifier extends AsyncNotifier<List<DeliveryAddress>> {
  @override
  Future<List<DeliveryAddress>> build() async {
    // Watching the user prevents one account's addresses from remaining in
    // memory after sign-out or after another account signs in.
    final user = ref.watch(authProvider).valueOrNull;
    if (user == null) {
      return const <DeliveryAddress>[];
    }
    return ref.read(deliveryAddressRepositoryProvider).fetchAddresses();
  }

  Future<void> reload() async {
    state = const AsyncLoading<List<DeliveryAddress>>();
    state = await AsyncValue.guard(
      () => ref.read(deliveryAddressRepositoryProvider).fetchAddresses(),
    );
  }

  Future<DeliveryAddress> createAddress(DeliveryAddressInput input) async {
    final repository = ref.read(deliveryAddressRepositoryProvider);
    final created = await repository.createAddress(input);
    state = AsyncData(await repository.fetchAddresses());
    return created;
  }

  Future<DeliveryAddress> updateAddress(
    int addressId,
    DeliveryAddressInput input,
  ) async {
    final repository = ref.read(deliveryAddressRepositoryProvider);
    final updated = await repository.updateAddress(addressId, input);
    state = AsyncData(await repository.fetchAddresses());
    return updated;
  }

  Future<void> setDefaultAddress(int addressId) async {
    final repository = ref.read(deliveryAddressRepositoryProvider);
    await repository.setDefaultAddress(addressId);
    state = AsyncData(await repository.fetchAddresses());
  }

  Future<void> deleteAddress(int addressId) async {
    final repository = ref.read(deliveryAddressRepositoryProvider);
    await repository.deleteAddress(addressId);
    state = AsyncData(await repository.fetchAddresses());
  }
}

final deliveryAddressesProvider =
    AsyncNotifierProvider<DeliveryAddressesNotifier, List<DeliveryAddress>>(
      DeliveryAddressesNotifier.new,
    );

final selectedDeliveryAddressProvider = Provider<DeliveryAddress?>((ref) {
  final addresses = ref.watch(deliveryAddressesProvider).valueOrNull;
  if (addresses == null || addresses.isEmpty) {
    return null;
  }

  for (final address in addresses) {
    if (address.isDefault) {
      return address;
    }
  }

  // The backend always promotes a default, but this keeps the UI usable if
  // it receives legacy data without one.
  return addresses.first;
});
