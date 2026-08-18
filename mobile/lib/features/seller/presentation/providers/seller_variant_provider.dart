import 'package:ecommerce_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:ecommerce_mobile/features/seller/data/models/seller_variant_model.dart';
import 'package:ecommerce_mobile/features/seller/data/seller_variant_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sellerVariantRepositoryProvider = Provider<SellerVariantRepository>((ref) {
  return SellerVariantRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

/// The variants of one of the seller's own products.
final sellerVariantsProvider =
    FutureProvider.family<List<SellerVariant>, String>((ref, slug) {
      return ref.watch(sellerVariantRepositoryProvider).fetchVariants(slug);
    });

/// Every attribute; the screen narrows it to the product's category.
///
/// Kept whole rather than per-category because the list is small and one
/// fetch serves both the picker and any product the seller opens next.
final sellerAttributesProvider = FutureProvider<List<SellerAttribute>>((ref) {
  return ref.watch(sellerVariantRepositoryProvider).fetchAttributes();
});

/// The extra photos of one of the seller's own products.
final sellerImagesProvider =
    FutureProvider.family<List<SellerImage>, String>((ref, slug) {
      return ref.watch(sellerVariantRepositoryProvider).fetchImages(slug);
    });
