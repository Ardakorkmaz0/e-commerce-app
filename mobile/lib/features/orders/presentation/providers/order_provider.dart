import 'package:ecommerce_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:ecommerce_mobile/features/orders/data/models/order_model.dart';
import 'package:ecommerce_mobile/features/orders/data/order_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

/// The signed-in shopper's own orders.
///
/// Watches the user so signing out empties the list rather than leaving
/// the previous account's orders on screen.
final ordersProvider = FutureProvider<List<Order>>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null) {
    return <Order>[];
  }
  return ref.read(orderRepositoryProvider).fetchOrders();
});

final orderDetailProvider = FutureProvider.family<Order, String>((
  ref,
  orderNumber,
) {
  return ref.watch(orderRepositoryProvider).fetchOrder(orderNumber);
});

/// Orders containing something this seller sold, their lines only.
final sellerOrdersProvider = FutureProvider<List<SellerOrder>>((ref) {
  return ref.watch(orderRepositoryProvider).fetchSellerOrders();
});
