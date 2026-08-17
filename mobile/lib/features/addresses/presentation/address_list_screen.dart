import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/addresses/data/address_repository.dart';
import 'package:ecommerce_mobile/features/addresses/data/models/delivery_address_model.dart';
import 'package:ecommerce_mobile/features/addresses/presentation/providers/address_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AddressListScreen extends ConsumerStatefulWidget {
  const AddressListScreen({super.key});

  @override
  ConsumerState<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends ConsumerState<AddressListScreen> {
  int? _selectingAddressId;

  Future<void> _selectAddress(DeliveryAddress address) async {
    if (address.isDefault || _selectingAddressId != null) {
      return;
    }

    setState(() => _selectingAddressId = address.id);
    try {
      await ref
          .read(deliveryAddressesProvider.notifier)
          .setDefaultAddress(address.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${address.label} is now your default address.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeAddressError(error))));
    } finally {
      if (mounted) {
        setState(() => _selectingAddressId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(deliveryAddressesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Delivery addresses',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
      ),
      body: addresses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _AddressError(
          message: describeAddressError(error),
          onRetry: () => ref.invalidate(deliveryAddressesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return _EmptyAddresses(
              onAdd: () => context.pushNamed('addressNew'),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(deliveryAddressesProvider.notifier).reload(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final address = items[index];
                final selecting = _selectingAddressId == address.id;
                return Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: address.isDefault || _selectingAddressId != null
                        ? null
                        : () => _selectAddress(address),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: selecting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    address.isDefault
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: address.isDefault
                                        ? AppColors.primary
                                        : AppColors.mutedText,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        address.label,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    if (address.isDefault)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withAlpha(
                                            24,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                        child: const Text(
                                          'Default',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    // Edit and delete, which the web has had
                                    // from the start. Tucked into a menu so
                                    // the row still reads as one tap target
                                    // for choosing the address.
                                    _AddressMenu(address: address),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  address.recipientName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  address.formattedAddress,
                                  style: const TextStyle(
                                    color: AppColors.mutedText,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  address.phoneNumber,
                                  style: const TextStyle(
                                    color: AppColors.mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: (addresses.valueOrNull?.isNotEmpty ?? false)
          ? FloatingActionButton.extended(
              onPressed: () => context.pushNamed('addressNew'),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add address'),
            )
          : null,
    );
  }
}

/// Edit and delete for one address.
class _AddressMenu extends ConsumerWidget {
  const _AddressMenu({required this.address});

  final DeliveryAddress address;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('"${address.label}" will be removed from your account.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(deliveryAddressesProvider.notifier)
          .deleteAddress(address.id);
    } catch (error) {
      if (!context.mounted) return;
      // The backend refuses to remove the only default address, and that
      // message is worth showing rather than swallowing.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeAddressError(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Address actions',
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (value) {
        if (value == 'edit') {
          context.pushNamed(
            'addressEdit',
            pathParameters: {'id': address.id.toString()},
            extra: address,
          );
        } else {
          _delete(context, ref);
        }
      },
      itemBuilder: (context) => const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}

class _EmptyAddresses extends StatelessWidget {
  const _EmptyAddresses({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.location_off_outlined,
              size: 64,
              color: AppColors.mutedText,
            ),
            const SizedBox(height: 16),
            Text(
              'No delivery addresses yet.',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add an address to choose where your orders will be delivered.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedText),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add delivery address'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressError extends StatelessWidget {
  const _AddressError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
