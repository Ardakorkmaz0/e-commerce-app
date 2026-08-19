import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/cart/data/models/cart_model.dart';
import 'package:ecommerce_mobile/features/orders/data/models/order_model.dart';
import 'package:ecommerce_mobile/features/orders/data/order_repository.dart';
import 'package:ecommerce_mobile/features/orders/presentation/order_widgets.dart';
import 'package:ecommerce_mobile/features/orders/presentation/providers/order_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Web equivalent: `/myorders`
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('main');
            }
          },
        ),
        title: const Text(
          'My Orders',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              describeOrderError(error),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText),
            ),
          ),
        ),
        data: (List<Order> items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: context.mutedText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'You have no orders yet.',
                    style: TextStyle(color: context.mutedText),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(ordersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _OrderCard(order: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final failed = order.status == 'pending' && order.lastPaymentError.isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.pushNamed(
          'orderDetail',
          pathParameters: {'number': order.orderNumber},
        ),
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              color: context.controlBackground,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          formatOrderDate(order.createdAt),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${order.orderNumber} · '
                          '${formatMoney(order.total)}',
                          style: TextStyle(
                            color: context.mutedText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OrderStatusBadge(
                    status: order.status,
                    label: order.statusDisplay,
                    paymentFailed: failed,
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                children: <Widget>[
                  // Two is enough to recognise the order; the rest are a
                  // tap away on the detail screen.
                  for (final line in order.items.take(2))
                    OrderLineRow(line: line),
                  if (order.items.length > 2)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'and ${order.items.length - 2} more',
                          style: TextStyle(
                            color: context.mutedText,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
