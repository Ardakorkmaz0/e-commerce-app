import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/cart/data/cart_repository.dart';
import 'package:ecommerce_mobile/features/cart/data/models/cart_model.dart';
import 'package:ecommerce_mobile/features/cart/presentation/providers/cart_provider.dart';
import 'package:ecommerce_mobile/features/main/presentation/providers/tab_provider.dart';
import 'package:ecommerce_mobile/shared/widgets/gradient_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Web equivalent: /cart
class CartTab extends ConsumerWidget {
  const CartTab({super.key});

  Future<void> _guard(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeCartError(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: <Widget>[
          if ((cart.valueOrNull?.items.isNotEmpty) ?? false)
            TextButton(
              onPressed: () => _guard(
                context,
                () => ref.read(cartProvider.notifier).clear(),
              ),
              child: const Text('Clear'),
            ),
        ],
      ),
      body: cart.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              describeCartError(error),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText),
            ),
          ),
        ),
        data: (Cart data) {
          if (data.isEmpty) {
            return _EmptyCart(
              onShop: () => ref.read(selectedTabProvider.notifier).state =
                  MainTab.products,
            );
          }

          return Column(
            children: <Widget>[
              if (data.hasStockIssues)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFFFEF3C7),
                  child: const Text(
                    'Some items are no longer available in the quantity you '
                    'chose. Adjust them before checking out.',
                    style: TextStyle(color: Color(0xFF92400E), fontSize: 12),
                  ),
                ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.read(cartProvider.notifier).reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: data.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _CartLine(
                      item: data.items[index],
                      onChangeQuantity: (quantity) => _guard(
                        context,
                        () => ref
                            .read(cartProvider.notifier)
                            .setQuantity(
                              itemId: data.items[index].id,
                              quantity: quantity,
                            ),
                      ),
                      onRemove: () => _guard(
                        context,
                        () => ref
                            .read(cartProvider.notifier)
                            .remove(data.items[index].id),
                      ),
                      onOpen: () => context.pushNamed(
                        'productDetail',
                        pathParameters: {'slug': data.items[index].slug},
                      ),
                    ),
                  ),
                ),
              ),

              _CartSummary(cart: data),
            ],
          );
        },
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({
    required this.item,
    required this.onChangeQuantity,
    required this.onRemove,
    required this.onOpen,
  });

  final CartItem item;
  final ValueChanged<int> onChangeQuantity;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    // Never offer more than the shop has, and never more than the API's cap.
    final maxQuantity = item.availableStock < 20 ? item.availableStock : 20;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            GestureDetector(
              onTap: onOpen,
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: item.imageUrl.isEmpty
                    ? Icon(
                        Icons.image_outlined,
                        color: AppColors.primary.withAlpha(100),
                      )
                    : Image.network(
                        item.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.primary.withAlpha(100),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  GestureDetector(
                    onTap: onOpen,
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  // Two lines of the same product only differ by this.
                  if (item.optionLabel.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      item.optionLabel,
                      style: TextStyle(
                        color: context.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    '${formatMoney(item.unitPrice)} each',
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                    ),
                  ),
                  if (item.hasStockIssue) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      'Only ${item.availableStock} left',
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),

                  Row(
                    children: <Widget>[
                      _QuantityStepper(
                        quantity: item.quantity,
                        maxQuantity: maxQuantity,
                        onChanged: onChangeQuantity,
                      ),
                      const Spacer(),
                      Text(
                        formatMoney(item.lineTotal),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close, size: 18),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.maxQuantity,
    required this.onChanged,
  });

  final int quantity;
  final int maxQuantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StepperButton(
            icon: Icons.remove,
            // One is the floor: removing the last unit is what the × does.
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            onPressed: quantity < maxQuantity
                ? () => onChanged(quantity + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 16,
          color: onPressed == null ? AppColors.border : AppColors.primary,
        ),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppColors.mutedText),
                ),
                const Spacer(),
                const Text('Subtotal', style: TextStyle(color: AppColors.mutedText)),
                const SizedBox(width: 8),
                Text(
                  formatMoney(cart.subtotal),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // TODO: enable once orders and the fake payment flow exist.
            const GradientButton(
              label: 'Checkout (coming soon)',
              onPressed: null,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onShop});

  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Browse the catalog and add something you like.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedText),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 220,
              child: GradientButton(label: 'Start shopping', onPressed: onShop),
            ),
          ],
        ),
      ),
    );
  }
}
