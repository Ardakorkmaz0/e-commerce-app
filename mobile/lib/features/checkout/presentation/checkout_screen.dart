import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/addresses/data/models/delivery_address_model.dart';
import 'package:ecommerce_mobile/features/addresses/presentation/providers/address_provider.dart';
import 'package:ecommerce_mobile/features/cart/data/models/cart_model.dart';
import 'package:ecommerce_mobile/features/cart/presentation/providers/cart_provider.dart';
import 'package:ecommerce_mobile/features/payments/data/models/payment_method_model.dart';
import 'package:ecommerce_mobile/features/orders/data/order_repository.dart';
import 'package:ecommerce_mobile/features/orders/presentation/providers/order_provider.dart';
import 'package:ecommerce_mobile/features/payments/presentation/providers/payment_provider.dart';
import 'package:ecommerce_mobile/shared/widgets/gradient_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Web equivalent: `/checkout`
///
/// Nothing here writes an order. The last button shows what the order
/// *would* be and leaves the cart alone, so the screen can be walked end
/// to end while the order model is still to be built.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  int? _addressId;
  int? _cardId;

  /// Generated once when the screen opens, so a repeated tap returns the
  /// order already placed instead of opening a second one.
  final String _idempotencyKey = DateTime.now().microsecondsSinceEpoch
      .toRadixString(36);

  bool _placing = false;

  /// Falls back to the default, then to the first one, then to nothing.
  int? _pick<T>(List<T> items, bool Function(T) isDefault, int Function(T) id) {
    if (items.isEmpty) return null;
    for (final item in items) {
      if (isDefault(item)) return id(item);
    }
    return id(items.first);
  }

  Future<void> _place(int addressId, int cardId) async {
    setState(() => _placing = true);
    try {
      final order = await ref
          .read(orderRepositoryProvider)
          .placeOrder(
            addressId: addressId,
            paymentMethodId: cardId,
            idempotencyKey: _idempotencyKey,
          );

      // The badge, the cart and the order list have all moved on.
      ref.invalidate(cartProvider);
      ref.invalidate(ordersProvider);
      if (!mounted) return;

      context.pushReplacementNamed(
        'orderDetail',
        pathParameters: {'number': order.orderNumber},
        queryParameters: {'placed': '1'},
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeOrderError(error))));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider).valueOrNull ?? Cart.empty;
    final addresses =
        ref.watch(deliveryAddressesProvider).valueOrNull ??
        const <DeliveryAddress>[];
    final cards =
        ref.watch(paymentMethodsProvider).valueOrNull ??
        const <PaymentMethod>[];

    final usableCards = cards.where((card) => !card.isExpired).toList();

    // Chosen during build rather than in initState: the lists arrive from
    // the network, so there is nothing to pick from when the screen opens.
    final addressId =
        _addressId ??
        _pick(addresses, (a) => a.isDefault, (a) => a.id);
    final cardId =
        _cardId ?? _pick(usableCards, (c) => c.isDefault, (c) => c.id);

    final address = addresses.where((a) => a.id == addressId).firstOrNull;
    final card = usableCards.where((c) => c.id == cardId).firstOrNull;
    final ready = address != null && card != null && !cart.hasStockIssues;

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
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: cart.isEmpty
          ? Center(
              child: Text(
                'Your cart is empty.',
                style: TextStyle(color: context.mutedText),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: <Widget>[
                if (cart.hasStockIssues)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Some items are no longer available in the quantity you '
                      'chose. Adjust them in the cart before checking out.',
                      style: TextStyle(color: Color(0xFF92400E)),
                    ),
                  ),

                _Section(
                  step: 1,
                  title: 'Delivery address',
                  child: addresses.isEmpty
                      ? _Empty(
                          message: 'You have no saved addresses.',
                          actionLabel: 'Add an address',
                          onPressed: () => context.pushNamed('addressNew'),
                        )
                      : Column(
                          children: <Widget>[
                            for (final item in addresses)
                              _Choice(
                                selected: item.id == addressId,
                                title: item.label,
                                isDefault: item.isDefault,
                                body:
                                    '${item.recipientName} · '
                                    '${item.phoneNumber}\n'
                                    '${item.addressLine1}'
                                    '${item.addressLine2.isEmpty ? '' : ', ${item.addressLine2}'}\n'
                                    '${item.district}, ${item.city} '
                                    '${item.postalCode}',
                                onTap: () =>
                                    setState(() => _addressId = item.id),
                              ),
                          ],
                        ),
                ),

                _Section(
                  step: 2,
                  title: 'Payment method',
                  child: usableCards.isEmpty
                      ? _Empty(
                          message: cards.isEmpty
                              ? 'You have no saved cards.'
                              : 'Every saved card has expired.',
                          actionLabel: 'Add a card',
                          onPressed: () => context.pushNamed('paymentMethods'),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            for (final item in usableCards)
                              _Choice(
                                selected: item.id == cardId,
                                title:
                                    '${item.brandDisplay} ···· ${item.last4}',
                                isDefault: item.isDefault,
                                body:
                                    '${item.holderName} · expires '
                                    '${item.expMonth.toString().padLeft(2, '0')}'
                                    '/${item.expYear}',
                                onTap: () => setState(() => _cardId = item.id),
                              ),

                            // One option, but naming it is what a shopper
                            // looks for on this screen.
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.controlBackground,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  const Text(
                                    'Single payment',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      '${formatMoney(cart.total)} at once',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: context.mutedText,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),

                _Section(
                  step: 3,
                  title: 'Items (${cart.itemCount})',
                  child: Column(
                    children: <Widget>[
                      for (final item in cart.items) _ItemRow(item: item),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                _Summary(cart: cart),
                const SizedBox(height: 16),

                GradientButton(
                  label: _placing ? 'Placing...' : 'Place your order',
                  onPressed: ready && !_placing
                      ? () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => OrderPreviewSheet(
                            cart: cart,
                            address: address,
                            card: card,
                            onConfirm: () => _place(address.id, card.id),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  ready
                      ? 'You will see the whole order before anything is '
                            'charged.'
                      : cart.hasStockIssues
                      ? 'Fix the stock warnings above first.'
                      : address == null
                      ? 'Choose a delivery address first.'
                      : 'Choose a payment method first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.mutedText, fontSize: 12),
                ),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.step,
    required this.title,
    required this.child,
  });

  final int step;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.accent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$step',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.title,
    required this.body,
    required this.isDefault,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String body;
  final bool isDefault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? context.accent : context.borderColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? context.accent : context.mutedText,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (isDefault) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: context.controlBackground,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Default',
                            style: TextStyle(
                              color: context.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: TextStyle(
                      color: context.mutedText,
                      fontSize: 12,
                      height: 1.45,
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

class _Empty extends StatelessWidget {
  const _Empty({
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(message, style: TextStyle(color: context.mutedText)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: Text(actionLabel),
          onPressed: onPressed,
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 48,
              height: 48,
              color: AppColors.primary.withAlpha(20),
              child: item.imageUrl.isEmpty
                  ? Icon(
                      Icons.image_outlined,
                      color: AppColors.primary.withAlpha(100),
                    )
                  : Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.image_not_supported_outlined,
                        color: AppColors.primary.withAlpha(100),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (item.optionLabel.isNotEmpty)
                  Text(
                    item.optionLabel,
                    style: TextStyle(
                      color: context.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  '${formatMoney(item.unitPrice)} × ${item.quantity}',
                  style: TextStyle(color: context.mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            formatMoney(item.lineTotal),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    final remaining = double.tryParse(cart.freeShippingRemaining) ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.controlBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          _Line(
            label: 'Items (${cart.itemCount})',
            value: formatMoney(cart.subtotal),
          ),
          _Line(
            label: 'Delivery',
            value: cart.shipsFree ? 'Free' : formatMoney(cart.shipping),
            valueColor: cart.shipsFree ? const Color(0xFF15803D) : null,
          ),
          if (remaining > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Spend ${formatMoney(cart.freeShippingRemaining)} more for '
                'free delivery.',
                style: TextStyle(color: context.mutedText, fontSize: 12),
              ),
            ),
          const Divider(height: 20),
          _Line(label: 'Total', value: formatMoney(cart.total), bold: true),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

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
        children: <Widget>[
          Text(label, style: style),
          Text(value, style: style.copyWith(color: valueColor)),
        ],
      ),
    );
  }
}

/// What the order would look like, had it been saved.
class OrderPreviewSheet extends StatelessWidget {
  const OrderPreviewSheet({
    super.key,
    required this.cart,
    required this.address,
    required this.card,
    required this.onConfirm,
  });

  final Cart cart;
  final DeliveryAddress address;
  final PaymentMethod card;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Confirm your order',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.controlBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${formatMoney(cart.total)} will be charged to your '
                '${card.brandDisplay} ending ${card.last4} as a single '
                'payment.',
                style: TextStyle(color: context.mutedText, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),

            _Heading(text: 'SHIPS TO'),
            Text(
              '${address.recipientName}\n'
              '${address.addressLine1}'
              '${address.addressLine2.isEmpty ? '' : ', ${address.addressLine2}'}\n'
              '${address.district}, ${address.city} ${address.postalCode}',
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 14),

            _Heading(text: 'PAID WITH'),
            Text(
              '${card.brandDisplay} ···· ${card.last4}\nSingle payment',
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 14),

            _Heading(text: 'ITEMS'),
            for (final item in cart.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${item.name}'
                        '${item.optionLabel.isEmpty ? '' : ' — ${item.optionLabel}'}'
                        ' × ${item.quantity}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatMoney(item.lineTotal),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),

            const Divider(height: 24),
            _Line(label: 'Items', value: formatMoney(cart.subtotal)),
            _Line(
              label: 'Delivery',
              value: cart.shipsFree ? 'Free' : formatMoney(cart.shipping),
            ),
            _Line(
              label: 'Total',
              value: formatMoney(cart.total),
              bold: true,
            ),

            const SizedBox(height: 20),
            GradientButton(
              label: 'Confirm and pay',
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          color: context.mutedText,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
