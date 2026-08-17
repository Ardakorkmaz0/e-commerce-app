import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/addresses/presentation/providers/address_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SelectedAddressButton extends ConsumerWidget {
  const SelectedAddressButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(deliveryAddressesProvider);
    final selected = ref.watch(selectedDeliveryAddressProvider);

    final label = addresses.when(
      loading: () => 'Loading delivery address...',
      error: (_, _) => 'Delivery address unavailable',
      data: (_) => selected == null
          ? 'Add delivery address'
          : 'Deliver to ${selected.label} · ${selected.locationLabel}',
    );

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: () => context.pushNamed('addresses'),
        child: Container(
          width: double.infinity,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.location_on_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
