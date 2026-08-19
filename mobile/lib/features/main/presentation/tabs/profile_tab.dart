import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/core/theme/theme_provider.dart';
import 'package:ecommerce_mobile/features/auth/data/models/user_model.dart';
import 'package:ecommerce_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Web equivalent: navbar account dropdown (Profile, My Orders, Sign out)
// Now uses ConsumerWidget to read real user data from authProvider
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch authProvider — rebuilds automatically when user data changes
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: authState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load profile.')),
        data: (UserModel? user) {
          if (user == null) return const Center(child: Text('Not signed in.'));
          return ListView(
            children: [
              _ProfileHeader(user: user),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('My Orders'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed('orders'),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Edit Profile'),
                trailing: const Icon(Icons.chevron_right),
                // push (not go) so the screen stacks and can be popped back
                onTap: () => context.pushNamed('editProfile'),
              ),
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Delivery addresses'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed('addresses'),
              ),
              const _AppearanceTile(),
              ListTile(
                leading: const Icon(Icons.credit_card_outlined),
                title: const Text('Payment methods'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed('paymentMethods'),
              ),
              // Sellers manage their catalog here, the same way they do at
              // /seller on the web. There is deliberately no Django admin
              // entry: the admin is an internal tool, not part of the app.
              if (user.isSeller)
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: const Text('My Products'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed('sellerProducts'),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Sign out',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) context.goNamed('signIn');
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primary.withAlpha(30),
            // Show the first letter of the username as the avatar
            child: Text(
              user.username.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName, // "First Last" or username if no name set
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.email,
                style: const TextStyle(color: AppColors.mutedText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Theme picker.
///
/// "System default" is the starting point, so the app follows the phone
/// unless the shopper deliberately overrides it.
class _AppearanceTile extends ConsumerWidget {
  const _AppearanceTile();

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final current = ref.read(themeModeProvider);

    final chosen = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Appearance',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // RadioGroup owns the selection; the tiles only declare values.
            // RadioListTile's own groupValue/onChanged are deprecated.
            RadioGroup<ThemeMode>(
              groupValue: current,
              onChanged: (value) => Navigator.of(sheetContext).pop(value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final mode in ThemeMode.values)
                    RadioListTile<ThemeMode>(
                      value: mode,
                      title: Text(themeModeLabel(mode)),
                      subtitle: mode == ThemeMode.system
                          ? const Text('Follow the device setting')
                          : null,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (chosen != null) {
      await ref.read(themeModeProvider.notifier).setThemeMode(chosen);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return ListTile(
      leading: Icon(
        switch (mode) {
          ThemeMode.light => Icons.light_mode_outlined,
          ThemeMode.dark => Icons.dark_mode_outlined,
          ThemeMode.system => Icons.brightness_auto_outlined,
        },
      ),
      title: const Text('Appearance'),
      subtitle: Text(themeModeLabel(mode)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _choose(context, ref),
    );
  }
}
