import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/payments/data/models/payment_method_model.dart';
import 'package:ecommerce_mobile/features/payments/data/payment_repository.dart';
import 'package:ecommerce_mobile/features/payments/presentation/providers/payment_provider.dart';
import 'package:ecommerce_mobile/features/payments/presentation/widgets/card_brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Web equivalent: /profile/payment-methods
class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    PaymentMethod method,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove card?'),
        content: Text(
          '${method.brandDisplay} ending ${method.last4} will be removed.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(paymentMethodsProvider.notifier)
          .deletePaymentMethod(method.id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describePaymentError(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payment methods',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.goNamed('main'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed('paymentMethodNew'),
        icon: const Icon(Icons.add_card_outlined),
        label: const Text('Add card'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: methods.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              describePaymentError(error),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText),
            ),
          ),
        ),
        data: (List<PaymentMethod> items) {
          return RefreshIndicator(
            onRefresh: () => ref.read(paymentMethodsProvider.notifier).reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: <Widget>[
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: <Widget>[
                        Icon(
                          Icons.credit_card_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No cards saved yet.',
                          style: TextStyle(color: AppColors.mutedText),
                        ),
                      ],
                    ),
                  )
                else
                  ...items.map(
                    (method) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PaymentCardTile(
                        method: method,
                        onDelete: () => _delete(context, ref, method),
                        onMakeDefault: () => ref
                            .read(paymentMethodsProvider.notifier)
                            .setDefaultPaymentMethod(method.id),
                      ),
                    ),
                  ),

                const SizedBox(height: 8),
                const _SecurityNote(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PaymentCardTile extends StatelessWidget {
  const _PaymentCardTile({
    required this.method,
    required this.onDelete,
    required this.onMakeDefault,
  });

  final PaymentMethod method;
  final VoidCallback onDelete;
  final VoidCallback onMakeDefault;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            CardBrandMark(brand: method.brand),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${method.brandDisplay} ···· ${method.last4}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (method.isExpired)
                        const _Badge(text: 'Expired', danger: true)
                      else if (method.isDefault)
                        const _Badge(text: 'Default'),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${method.holderName} · Expires ${method.formattedExpiry}',
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Card actions',
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) =>
                  value == 'delete' ? onDelete() : onMakeDefault(),
              itemBuilder: (context) => <PopupMenuEntry<String>>[
                if (!method.isDefault && !method.isExpired)
                  const PopupMenuItem<String>(
                    value: 'default',
                    child: Text('Make default'),
                  ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Remove', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.danger = false});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: danger ? const Color(0xFFB91C1C) : const Color(0xFF047857),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.lock_outline, size: 15, color: AppColors.mutedText),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'Your card number is never stored. Only the brand, the last four '
            'digits and the expiry are kept, alongside a token used for '
            'charges.',
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
