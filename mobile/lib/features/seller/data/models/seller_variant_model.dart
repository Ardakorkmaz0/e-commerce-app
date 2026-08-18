/// One choice a seller can build variants from, e.g. Colour: Red.
class SellerAttributeValue {
  const SellerAttributeValue({
    required this.id,
    required this.name,
    required this.swatchColor,
  });

  final int id;
  final String name;
  final String swatchColor;

  factory SellerAttributeValue.fromJson(Map<String, dynamic> json) {
    return SellerAttributeValue(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      swatchColor: json['swatch_color'] as String? ?? '',
    );
  }
}

/// An attribute with its values, plus the categories it applies to.
///
/// The categories are what lets the picker show Size and Colour for a shoe
/// but not for a graphics card.
class SellerAttribute {
  const SellerAttribute({
    required this.id,
    required this.name,
    required this.categoryIds,
    required this.values,
  });

  final int id;
  final String name;
  final List<int> categoryIds;
  final List<SellerAttributeValue> values;

  factory SellerAttribute.fromJson(Map<String, dynamic> json) {
    return SellerAttribute(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      categoryIds: (json['categories'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => item as int)
          .toList(),
      values: (json['values'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (item) => SellerAttributeValue.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// The seller's own view of a variant: everything the grid can edit.
class SellerVariant {
  const SellerVariant({
    required this.id,
    required this.sku,
    required this.optionLabel,
    required this.price,
    required this.stock,
    required this.description,
    required this.imageUrl,
    required this.imageDisplay,
    required this.isActive,
  });

  final int id;
  final String sku;
  final String optionLabel;

  /// Null means "same as the product price", which is a real state here
  /// rather than a missing value.
  final String? price;

  final int stock;
  final String description;
  final String imageUrl;

  /// What to draw: the variant's own picture, or the product's.
  final String imageDisplay;

  final bool isActive;

  factory SellerVariant.fromJson(Map<String, dynamic> json) {
    return SellerVariant(
      id: json['id'] as int,
      sku: json['sku'] as String? ?? '',
      optionLabel: json['option_label'] as String? ?? '',
      price: json['price']?.toString(),
      stock: json['stock'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      imageDisplay: json['image_display'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
