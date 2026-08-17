import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:ecommerce_mobile/features/products/data/models/product_model.dart';
import 'package:ecommerce_mobile/features/products/presentation/providers/product_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Web equivalent: SellerRatingForm on the product detail page.
///
/// Five tappable stars. Tapping the score already given clears it, matching
/// the DELETE branch of the API.
class SellerRatingBar extends ConsumerStatefulWidget {
  const SellerRatingBar({super.key, required this.sellerId});

  final int sellerId;

  @override
  ConsumerState<SellerRatingBar> createState() => _SellerRatingBarState();
}

class _SellerRatingBarState extends ConsumerState<SellerRatingBar> {
  bool _saving = false;

  Future<void> _submit(int score, int? currentScore) async {
    setState(() => _saving = true);

    final repository = ref.read(productRepositoryProvider);
    try {
      if (score == currentScore) {
        await repository.clearSellerRating(widget.sellerId);
      } else {
        await repository.rateSeller(widget.sellerId, score);
      }
      ref.invalidate(sellerRatingProvider(widget.sellerId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save your rating.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final rating = ref.watch(sellerRatingProvider(widget.sellerId));

    // A seller cannot rate their own store, same rule as the web.
    if (user != null && user.id == widget.sellerId) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: Text(
          'This is your store. Sellers cannot rate their own store.',
          style: TextStyle(color: AppColors.mutedText, fontSize: 12),
        ),
      );
    }

    return rating.when(
      loading: () => const SizedBox(height: 40),
      error: (_, _) => const SizedBox.shrink(),
      data: (SellerRating data) {
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: <Widget>[
              Text(
                data.score == null ? 'Rate this seller' : 'Your rating',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              for (var star = 1; star <= 5; star++)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  tooltip: '$star',
                  onPressed:
                      _saving ? null : () => _submit(star, data.score),
                  icon: Icon(
                    (data.score ?? 0) >= star ? Icons.star : Icons.star_border,
                    size: 22,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
