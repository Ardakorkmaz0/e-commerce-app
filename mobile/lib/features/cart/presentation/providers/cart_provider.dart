import 'package:ecommerce_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:ecommerce_mobile/features/cart/data/cart_repository.dart';
import 'package:ecommerce_mobile/features/cart/data/models/cart_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

class CartNotifier extends AsyncNotifier<Cart> {
  @override
  Future<Cart> build() async {
    // Watching the user empties the cart on sign-out instead of showing the
    // previous account's items.
    final user = ref.watch(authProvider).valueOrNull;
    if (user == null) {
      return Cart.empty;
    }
    return ref.read(cartRepositoryProvider).fetchCart();
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(cartRepositoryProvider).fetchCart(),
    );
  }

  // Each call replaces the state with the cart the server returned, so the
  // totals shown are always the ones it computed.

  Future<void> add({
    required int productId,
    int quantity = 1,
    int? variantId,
  }) async {
    state = AsyncData(
      await ref
          .read(cartRepositoryProvider)
          .addToCart(
            productId: productId,
            quantity: quantity,
            variantId: variantId,
          ),
    );
  }

  Future<void> setQuantity({required int itemId, required int quantity}) async {
    state = AsyncData(
      await ref
          .read(cartRepositoryProvider)
          .setQuantity(itemId: itemId, quantity: quantity),
    );
  }

  Future<void> remove(int itemId) async {
    state = AsyncData(await ref.read(cartRepositoryProvider).removeItem(itemId));
  }

  Future<void> clear() async {
    state = AsyncData(await ref.read(cartRepositoryProvider).clearCart());
  }
}

final cartProvider = AsyncNotifierProvider<CartNotifier, Cart>(
  CartNotifier.new,
);

/// Just the badge number, so widgets that only need the count do not
/// rebuild when a line total changes.
final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).valueOrNull?.itemCount ?? 0;
});
