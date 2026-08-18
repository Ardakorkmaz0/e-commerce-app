import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/cart/data/cart_repository.dart';
import 'package:ecommerce_mobile/features/cart/presentation/providers/cart_provider.dart';
import 'package:ecommerce_mobile/features/main/presentation/providers/tab_provider.dart';
import 'package:ecommerce_mobile/features/products/data/models/product_model.dart';
import 'package:ecommerce_mobile/features/products/presentation/product_gallery.dart';
import 'package:ecommerce_mobile/features/products/presentation/providers/product_provider.dart';
import 'package:ecommerce_mobile/features/products/presentation/seller_rating_bar.dart';
import 'package:ecommerce_mobile/features/products/presentation/variant_picker.dart';
import 'package:ecommerce_mobile/shared/widgets/gradient_button.dart';
import 'package:ecommerce_mobile/shared/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Web equivalent: /products/<slug>
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailProvider(slug));

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
        title: Text(
          product.valueOrNull?.category ?? 'Product',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: product.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load this product.')),
        data: (Product item) => _ProductDetailBody(product: item),
      ),
    );
  }
}

class _ProductDetailBody extends ConsumerStatefulWidget {
  const _ProductDetailBody({required this.product});

  final Product product;

  @override
  ConsumerState<_ProductDetailBody> createState() => _ProductDetailBodyState();
}

class _ProductDetailBodyState extends ConsumerState<_ProductDetailBody> {
  /// Option group slug -> chosen value id. Empty for products without
  /// options, which keeps every read below falling back to the product.
  late Map<String, int> _selection;

  @override
  void initState() {
    super.initState();
    _selection = widget.product.variants.isEmpty
        ? <String, int>{}
        : initialSelection(widget.product);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    // Same category, current product removed — the web's "More in ..." row.
    final related = ref.watch(
      productListProvider(ProductQuery(category: product.categorySlug)),
    );

    // Null while the shopper is on a combination that was never built.
    final variant = product.hasVariants
        ? findVariant(product.variants, _selection)
        : null;

    // The variant's own picture leads, then the cover, then the gallery.
    final photos = buildPhotoStrip(product, variant);

    // Falls back to the product, so a variant that leaves its description
    // blank simply inherits the product's.
    final description = (variant?.description.isNotEmpty ?? false)
        ? variant!.description
        : product.description;

    return ListView(
      children: <Widget>[
        ProductGallery(photos: photos, alt: product.name),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                product.category.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                product.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: <Widget>[
                  Text(
                    // No variant chosen yet means no single price to show.
                    product.hasVariants
                        ? (variant?.formattedPrice ?? 'Choose an option')
                        : product.formattedPrice,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: variant == null && product.hasVariants ? 18 : 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StockBadge(product: product, variant: variant),
                ],
              ),
              const SizedBox(height: 20),

              if (product.hasVariants) ...<Widget>[
                VariantOptions(
                  product: product,
                  selection: _selection,
                  onChanged: (groupSlug, valueId) {
                    setState(() => _selection[groupSlug] = valueId);
                  },
                ),
                const SizedBox(height: 2),
              ],

              if (description.isNotEmpty) ...<Widget>[
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              if (product.seller != null) ...<Widget>[
                _SellerPanel(seller: product.seller!),
                SellerRatingBar(sellerId: product.seller!.id),
              ],

              const SizedBox(height: 24),

              _AddToCartButton(product: product, variant: variant),
            ],
          ),
        ),

        // ── More in this category ──────────────────────────────────
        related.maybeWhen(
          orElse: () => const SizedBox.shrink(),
          data: (ProductListState state) {
            final others = state.items
                .where((item) => item.id != product.id)
                .take(6)
                .toList();
            if (others.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    'More in ${product.category}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  height: 250,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: others.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => SizedBox(
                      width: 160,
                      child: ProductCard(
                        product: others[index],
                        // replace, not push: avoids stacking detail screens
                        // as the shopper hops between related items.
                        onTap: () => context.replaceNamed(
                          'productDetail',
                          pathParameters: {'slug': others[index].slug},
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.product, this.variant});

  final Product product;

  /// Null either because the product has no options, or because the current
  /// combination was never built.
  final ProductVariant? variant;

  @override
  Widget build(BuildContext context) {
    if (product.hasVariants && variant == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'Unavailable combination',
          style: TextStyle(
            color: Color(0xFFB91C1C),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final inStock = variant?.inStock ?? product.inStock;
    final stock = variant?.stock ?? product.stock;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: inStock ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        inStock ? 'In stock · $stock left' : 'Out of stock',
        style: TextStyle(
          color: inStock ? const Color(0xFF047857) : const Color(0xFFB91C1C),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SellerPanel extends StatelessWidget {
  const _SellerPanel({required this.seller});

  final SellerSummary seller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Sold by',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        seller.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (seller.isVerified) ...<Widget>[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (seller.rating == null)
            const Text(
              'New seller',
              style: TextStyle(color: AppColors.mutedText, fontSize: 12),
            )
          else
            Row(
              children: <Widget>[
                const Icon(Icons.star, size: 16, color: Color(0xFFF59E0B)),
                const SizedBox(width: 4),
                Text(
                  seller.rating!.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${seller.ratingCount})',
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Adds the product, with a quantity stepper for more than one.
///
/// Errors come straight from the API, which is the only place that knows
/// the current stock.
class _AddToCartButton extends ConsumerStatefulWidget {
  const _AddToCartButton({required this.product, this.variant});

  final Product product;
  final ProductVariant? variant;

  @override
  ConsumerState<_AddToCartButton> createState() => _AddToCartButtonState();
}

class _AddToCartButtonState extends ConsumerState<_AddToCartButton> {
  int _quantity = 1;
  bool _adding = false;

  Future<void> _add() async {
    setState(() => _adding = true);
    try {
      await ref
          .read(cartProvider.notifier)
          .add(
            productId: widget.product.id,
            quantity: _quantity,
            variantId: widget.variant?.id,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Added to your cart.'),
          action: SnackBarAction(
            label: 'View cart',
            onPressed: () {
              ref.read(selectedTabProvider.notifier).state = MainTab.cart;
              if (context.mounted) context.goNamed('main');
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeCartError(error))));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  /// Variants carry their own stock, so a quantity that was fine for the
  /// previous one has to be pulled back down when the shopper switches.
  @override
  void didUpdateWidget(_AddToCartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final max = _maxQuantity;
    if (_quantity > max) {
      setState(() => _quantity = max < 1 ? 1 : max);
    }
  }

  int get _maxQuantity {
    final stock = widget.variant?.stock ?? widget.product.stock;
    return stock < 20 ? stock : 20;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.product.hasVariants && widget.variant == null) {
      return const GradientButton(
        label: 'Unavailable combination',
        onPressed: null,
      );
    }

    final inStock = widget.variant?.inStock ?? widget.product.inStock;
    if (!inStock) {
      return const GradientButton(label: 'Out of stock', onPressed: null);
    }

    final maxQuantity = _maxQuantity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text('Quantity', style: TextStyle(color: AppColors.mutedText)),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.remove, size: 18),
                    onPressed: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                  ),
                  Text(
                    '$_quantity',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: _quantity < maxQuantity
                        ? () => setState(() => _quantity++)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GradientButton(
          label: _adding ? 'Adding...' : 'Add to cart',
          onPressed: _adding ? null : _add,
        ),
      ],
    );
  }
}
