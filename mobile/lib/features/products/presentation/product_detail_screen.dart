import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/products/data/models/product_model.dart';
import 'package:ecommerce_mobile/features/products/presentation/providers/product_provider.dart';
import 'package:ecommerce_mobile/features/products/presentation/seller_rating_bar.dart';
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

class _ProductDetailBody extends ConsumerWidget {
  const _ProductDetailBody({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Same category, current product removed — the web's "More in ..." row.
    final related = ref.watch(
      productListProvider(ProductQuery(category: product.categorySlug)),
    );

    return ListView(
      children: <Widget>[
        // Image, matching the tinted panel used by the product cards
        Container(
          height: 280,
          width: double.infinity,
          color: AppColors.primary.withAlpha(20),
          child: product.imageUrl.isEmpty
              ? Icon(
                  Icons.image_outlined,
                  size: 96,
                  color: AppColors.primary.withAlpha(100),
                )
              : Image.network(
                  product.imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.image_not_supported_outlined,
                    size: 96,
                    color: AppColors.primary.withAlpha(100),
                  ),
                ),
        ),

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
                    product.formattedPrice,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StockBadge(product: product),
                ],
              ),
              const SizedBox(height: 20),

              if (product.description.isNotEmpty) ...<Widget>[
                Text(
                  product.description,
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

              // TODO: enable once the cart API exists
              GradientButton(
                label: product.inStock
                    ? 'Add to cart (coming soon)'
                    : 'Out of stock',
                onPressed: null,
              ),
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
  const _StockBadge({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final inStock = product.inStock;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: inStock ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        inStock ? 'In stock · ${product.stock} left' : 'Out of stock',
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
