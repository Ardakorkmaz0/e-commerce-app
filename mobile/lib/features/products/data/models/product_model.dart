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
    this.seller,
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
  final SellerSummary? seller;

  factory Product.fromJson(Map<String, dynamic> json) {
    final seller = json['seller'];
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String? ?? '',
      price: json['price']?.toString() ?? '0',
      stock: json['stock'] as int? ?? 0,
      inStock: json['in_stock'] as bool? ?? false,
      category: json['category'] as String? ?? '',
      categorySlug: json['category_slug'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      seller: seller is Map<String, dynamic>
          ? SellerSummary.fromJson(seller)
          : null,
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
