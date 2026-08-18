class SellerSummary {
  const SellerSummary({
    required this.id,
    required this.name,
    required this.isVerified,
    required this.rating,
    required this.ratingCount,
  });

  final int id;
  final String name;
  final bool isVerified;
  final double? rating;
  final int ratingCount;

  factory SellerSummary.fromJson(Map<String, dynamic> json) {
    return SellerSummary(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      isVerified: json['is_verified'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble(),
      ratingCount: json['rating_count'] as int? ?? 0,
    );
  }
}

/// Response of `/sellers/<id>/rating/`: the public average plus the score
/// this customer gave, which is null when they have not rated yet.
class SellerRating {
  const SellerRating({
    required this.sellerId,
    required this.score,
    required this.rating,
    required this.ratingCount,
  });

  final int sellerId;
  final int? score;
  final double? rating;
  final int ratingCount;

  factory SellerRating.fromJson(Map<String, dynamic> json) {
    return SellerRating(
      sellerId: json['seller_id'] as int,
      score: json['score'] as int?,
      rating: (json['rating'] as num?)?.toDouble(),
      ratingCount: json['rating_count'] as int? ?? 0,
    );
  }
}

class OptionValue {
  const OptionValue({
    required this.id,
    required this.name,
    required this.slug,
    required this.swatchColor,
  });

  final int id;
  final String name;
  final String slug;

  /// Hex like "#111827" when the value should render as a dot, else empty.
  final String swatchColor;

  factory OptionValue.fromJson(Map<String, dynamic> json) {
    return OptionValue(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      swatchColor: json['swatch_color'] as String? ?? '',
    );
  }
}

class OptionGroup {
  const OptionGroup({
    required this.name,
    required this.slug,
    required this.values,
  });

  final String name;
  final String slug;
  final List<OptionValue> values;

  bool get isColour => values.any((value) => value.swatchColor.isNotEmpty);

  factory OptionGroup.fromJson(Map<String, dynamic> json) {
    return OptionGroup(
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      values: (json['values'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => OptionValue.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// One photo in the gallery strip.
class ProductPhoto {
  const ProductPhoto({
    required this.id,
    required this.url,
    required this.alt,
    required this.variantId,
  });

  final int id;
  final String url;
  final String alt;

  /// Null for photos that stay on screen whichever variant is chosen.
  final int? variantId;

  factory ProductPhoto.fromJson(Map<String, dynamic> json) {
    return ProductPhoto(
      id: json['id'] as int,
      url: json['url'] as String? ?? '',
      alt: json['alt'] as String? ?? '',
      variantId: json['variant'] as int?,
    );
  }
}

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.optionValueIds,
    required this.optionLabel,
    required this.price,
    required this.stock,
    required this.inStock,
    required this.description,
    required this.imageUrl,
  });

  final int id;

  /// Sorted by the API, so a selection can be compared against it directly.
  final List<int> optionValueIds;

  final String optionLabel;
  final String price;
  final int stock;
  final bool inStock;
  final String description;
  final String imageUrl;

  String get formattedPrice {
    final amount = double.tryParse(price);
    return amount == null ? price : '\$${amount.toStringAsFixed(2)}';
  }

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] as int,
      optionValueIds: (json['option_value_ids'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => item as int)
          .toList(),
      optionLabel: json['option_label'] as String? ?? '',
      price: json['price']?.toString() ?? '0',
      stock: json['stock'] as int? ?? 0,
      inStock: json['in_stock'] as bool? ?? false,
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.price,
    required this.stock,
    required this.inStock,
    required this.category,
    required this.categorySlug,
    required this.imageUrl,
    this.categoryId,
    this.isActive = true,
    this.seller,
    this.hasVariants = false,
    this.variants = const <ProductVariant>[],
    this.optionGroups = const <OptionGroup>[],
    this.photos = const <ProductPhoto>[],
  });

  final int id;
  final String name;
  final String slug;
  final String description;

  // Kept as the string the API sends: the backend stores money as Decimal,
  // and parsing it to double here would reintroduce rounding error.
  final String price;

  final int stock;
  final bool inStock;
  final String category;
  final String categorySlug;
  final String imageUrl;

  /// Only present on the seller endpoint, which needs it for the category
  /// dropdown. The public catalog identifies categories by slug instead.
  final int? categoryId;

  final bool isActive;
  final SellerSummary? seller;

  // Only the detail endpoint fills these in.
  final bool hasVariants;
  final List<ProductVariant> variants;
  final List<OptionGroup> optionGroups;
  final List<ProductPhoto> photos;

  /// Parses both catalog shapes.
  ///
  /// `/products/` sends `category` as a display name plus `category_slug`,
  /// while `/seller/products/` sends `category` as the primary key plus
  /// `category_name`. Assuming one shape is what made the seller list fail.
  factory Product.fromJson(Map<String, dynamic> json) {
    final rawCategory = json['category'];
    final stock = json['stock'] as int? ?? 0;

    // The seller endpoint resolves an uploaded file into image_display and
    // leaves image_url holding the pasted link, which may be empty.
    final display = json['image_display'] as String? ?? '';
    final link = json['image_url'] as String? ?? '';

    final seller = json['seller'];

    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String? ?? '',
      price: json['price']?.toString() ?? '0',
      stock: stock,
      // Absent on the seller endpoint, so derive it there.
      inStock: json['in_stock'] as bool? ?? stock > 0,
      category: json['category_name'] as String? ??
          (rawCategory is String ? rawCategory : ''),
      categoryId: rawCategory is int ? rawCategory : null,
      categorySlug: json['category_slug'] as String? ?? '',
      imageUrl: display.isNotEmpty ? display : link,
      isActive: json['is_active'] as bool? ?? true,
      seller: seller is Map<String, dynamic>
          ? SellerSummary.fromJson(seller)
          : null,
      hasVariants: json['has_variants'] as bool? ?? false,
      variants: (json['variants'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => ProductVariant.fromJson(item as Map<String, dynamic>))
          .toList(),
      optionGroups: (json['option_groups'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => OptionGroup.fromJson(item as Map<String, dynamic>))
          .toList(),
      photos: (json['images'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => ProductPhoto.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Display form only — never use for arithmetic.
  String get formattedPrice {
    final amount = double.tryParse(price);
    return amount == null ? price : '\$${amount.toStringAsFixed(2)}';
  }
}

class Category {
  const Category({required this.id, required this.name, required this.slug});

  final int id;
  final String name;
  final String slug;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
    );
  }
}

/// One page of `/products/`, which is paginated by the backend.
class ProductPage {
  const ProductPage({
    required this.count,
    required this.results,
    required this.hasNext,
  });

  final int count;
  final List<Product> results;
  final bool hasNext;

  factory ProductPage.fromJson(Map<String, dynamic> json) {
    final results = (json['results'] as List<dynamic>? ?? <dynamic>[])
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();

    return ProductPage(
      count: json['count'] as int? ?? results.length,
      results: results,
      hasNext: json['next'] != null,
    );
  }
}
