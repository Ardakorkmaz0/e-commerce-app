import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/cart/data/models/cart_model.dart';
import 'package:ecommerce_mobile/features/orders/data/models/order_model.dart';
import 'package:ecommerce_mobile/features/orders/data/order_repository.dart';
import 'package:ecommerce_mobile/features/orders/presentation/order_widgets.dart';
import 'package:ecommerce_mobile/features/orders/presentation/providers/order_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Web equivalent: `/seller/orders`
///
/// Only this seller's lines, plus the address needed to post them. The
/// customer's account, their other orders and their other addresses stay
/// out of reach, which is the rule the rest of the seller panel follows.
class SellerOrdersScreen extends ConsumerWidget {
  const SellerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(sellerOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('sellerProducts');
            }
          },
        ),
        title: const Text(
          'Orders',
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
        data: (List<SellerOrder> items) {
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
                    'Nobody has bought anything from you yet.',
                    style: TextStyle(color: context.mutedText),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(sellerOrdersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _SellerOrderCard(order: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _SellerOrderCard extends ConsumerStatefulWidget {
  const _SellerOrderCard({required this.order});

  final SellerOrder order;

  @override
  ConsumerState<_SellerOrderCard> createState() => _SellerOrderCardState();
}

class _SellerOrderCardState extends ConsumerState<_SellerOrderCard> {
  bool _busy = false;

  Future<void> _ship() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(orderRepositoryProvider)
          .ship(widget.order.orderNumber);
      ref.invalidate(sellerOrdersProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeOrderError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
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
                        '${order.orderNumber} · your total '
                        '${formatMoney(order.sellerTotal)}',
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
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final line in order.items) OrderLineRow(line: line),

                const Divider(height: 20),
                Text(
                  'SHIP TO',
                  style: TextStyle(
                    color: context.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.recipientName}\n${order.phoneNumber}\n'
                  '${order.addressLine1}'
                  '${order.addressLine2.isEmpty ? '' : ', ${order.addressLine2}'}\n'
                  '${order.district}, ${order.city} ${order.postalCode}',
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 10),

                if (order.status == 'cancelled')
                  Text(
                    'Cancelled by the customer.',
                    style: TextStyle(color: context.mutedText, fontSize: 12),
                  )
                else if (order.hasSomethingToShip)
                  FilledButton.icon(
                    icon: const Icon(Icons.local_shipping_outlined, size: 18),
                    label: Text(_busy ? 'Saving...' : 'Mark as shipped'),
                    onPressed: _busy ? null : _ship,
                  )
                else
                  Text(
                    'Your parcel has gone out.',
                    style: TextStyle(color: context.mutedText, fontSize: 12),
                  ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
