import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/cart/data/models/cart_model.dart';
import 'package:ecommerce_mobile/features/orders/data/models/order_model.dart';
import 'package:ecommerce_mobile/features/orders/data/order_repository.dart';
import 'package:ecommerce_mobile/features/orders/presentation/order_widgets.dart';
import 'package:ecommerce_mobile/features/orders/presentation/providers/order_provider.dart';
import 'package:ecommerce_mobile/shared/widgets/gradient_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Web equivalent: `/myorders/<number>`
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderNumber,
    this.justPlaced = false,
  });

  final String orderNumber;

  /// True right after checkout, which is when the receipt banner shows.
  final bool justPlaced;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderDetailProvider(orderNumber));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('orders');
            }
          },
        ),
        title: Text(
          orderNumber,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: order.when(
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
        data: (Order item) =>
            _Body(order: item, justPlaced: justPlaced),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.order, required this.justPlaced});

  final Order order;
  final bool justPlaced;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(orderDetailProvider(widget.order.orderNumber));
      ref.invalidate(ordersProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeOrderError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text(
          'The whole order is cancelled and the stock goes back to the shop.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Cancel order',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _run(
      () => ref
          .read(orderRepositoryProvider)
          .cancel(widget.order.orderNumber),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final failed = order.status == 'pending' && order.lastPaymentError.isNotEmpty;

    // Only the moments that happened, in the order they happened.
    final timeline = <(String, DateTime?)>[
      ('Placed', order.createdAt),
      ('Paid', order.paidAt),
      ('Shipped', order.shippedAt),
      ('Delivered', order.deliveredAt),
      ('Cancelled', order.cancelledAt),
    ].where((step) => step.$2 != null).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        if (widget.justPlaced)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Thanks — your order is in.',
                  style: TextStyle(
                    color: Color(0xFF065F46),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${formatMoney(order.total)} was charged to your '
                  '${order.cardBrand} ending ${order.cardLast4}.',
                  style: const TextStyle(color: Color(0xFF065F46)),
                ),
              ],
            ),
          ),

        if (failed)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'This order has not been paid for. ${order.lastPaymentError} '
              'Nothing was charged and no stock was taken — start again from '
              'the cart with a different card.',
              style: const TextStyle(color: Color(0xFF991B1B)),
            ),
          ),

        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                formatOrderDate(order.createdAt),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            OrderStatusBadge(
              status: order.status,
              label: order.statusDisplay,
              paymentFailed: failed,
            ),
          ],
        ),
        const SizedBox(height: 16),

        _Panel(
          title: 'Items',
          child: Column(
            children: <Widget>[
              for (final line in order.items)
                OrderLineRow(
                  line: line,
                  // The product may be gone; the link then shows the
                  // detail screen's own "could not load" state.
                  onTap: line.slug.isEmpty
                      ? null
                      : () => context.pushNamed(
                          'productDetail',
                          pathParameters: {'slug': line.slug},
                        ),
                ),
            ],
          ),
        ),

        _Panel(
          title: 'Summary',
          child: Column(
            children: <Widget>[
              _Line(
                label: 'Items (${order.itemCount})',
                value: formatMoney(order.subtotal),
              ),
              _Line(
                label: 'Delivery',
                value: order.shipsFree ? 'Free' : formatMoney(order.shipping),
              ),
              const Divider(height: 20),
              _Line(
                label: 'Total',
                value: formatMoney(order.total),
                bold: true,
              ),
            ],
          ),
        ),

        _Panel(
          title: 'Ships to',
          child: Text(
            '${order.recipientName}\n${order.phoneNumber}\n'
            '${order.addressLine1}'
            '${order.addressLine2.isEmpty ? '' : ', ${order.addressLine2}'}\n'
            '${order.district}, ${order.city} ${order.postalCode}',
            style: const TextStyle(height: 1.5),
          ),
        ),

        _Panel(
          title: 'Paid with',
          child: Text(
            '${order.cardBrand} ···· ${order.cardLast4}\nSingle payment',
            style: const TextStyle(height: 1.5),
          ),
        ),

        _Panel(
          title: 'Progress',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final step in timeline)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        step.$1,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        formatOrderMoment(step.$2),
                        style: TextStyle(
                          color: context.mutedText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        if (order.status == 'shipped')
          GradientButton(
            label: _busy ? 'Saving...' : 'I have received this',
            onPressed: _busy
                ? null
                : () => _run(
                    () => ref
                        .read(orderRepositoryProvider)
                        .confirmDelivery(order.orderNumber),
                  ),
          )
        else if (order.status == 'paid' && order.isCancellable)
          OutlinedButton(
            onPressed: _busy ? null : _confirmCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(_busy ? 'Cancelling...' : 'Cancel this order'),
          )
        else if (order.status == 'paid' && order.hasShippedLines)
          // Spelled out rather than left as a dead button: one seller
          // posting their parcel closes it for the whole order.
          Text(
            'Part of this order has already been shipped, so it can no '
            'longer be cancelled.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedText, fontSize: 12),
          ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: context.mutedText,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 16 : 14,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
