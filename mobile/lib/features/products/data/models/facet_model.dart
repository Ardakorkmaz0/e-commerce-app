class FacetValue {
  const FacetValue({
    required this.name,
    required this.slug,
    required this.count,
  });

  final String name;
  final String slug;
  final int count;

  factory FacetValue.fromJson(Map<String, dynamic> json) {
    return FacetValue(
      name: json['name'] as String,
      slug: json['slug'] as String,
      count: json['count'] as int? ?? 0,
    );
  }
}

/// One attribute group in the filter sheet, e.g. Brand with RTX and AMD.
class Facet {
  const Facet({required this.name, required this.slug, required this.values});

  final String name;
  final String slug;
  final List<FacetValue> values;

  factory Facet.fromJson(Map<String, dynamic> json) {
    return Facet(
      name: json['name'] as String,
      slug: json['slug'] as String,
      values: (json['values'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => FacetValue.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PriceRange {
  const PriceRange({
    required this.slug,
    required this.label,
    required this.count,
  });

  final String slug;
  final String label;
  final int count;

  factory PriceRange.fromJson(Map<String, dynamic> json) {
    return PriceRange(
      slug: json['slug'] as String,
      label: json['label'] as String,
      count: json['count'] as int? ?? 0,
    );
  }
}

class AvailabilityCounts {
  const AvailabilityCounts({
    required this.inStock,
    required this.lowStock,
    required this.outOfStock,
  });

  final int inStock;
  final int lowStock;
  final int outOfStock;

  factory AvailabilityCounts.fromJson(Map<String, dynamic> json) {
    return AvailabilityCounts(
      inStock: json['in_stock'] as int? ?? 0,
      lowStock: json['low_stock'] as int? ?? 0,
      outOfStock: json['out_of_stock'] as int? ?? 0,
    );
  }
}

/// The whole filter panel description from GET /facets/.
class Facets {
  const Facets({
    required this.attributes,
    required this.priceRanges,
    required this.availability,
    required this.minPrice,
    required this.maxPrice,
  });

  final List<Facet> attributes;
  final List<PriceRange> priceRanges;
  final AvailabilityCounts availability;
  final String minPrice;
  final String maxPrice;

  static const empty = Facets(
    attributes: <Facet>[],
    priceRanges: <PriceRange>[],
    availability: AvailabilityCounts(inStock: 0, lowStock: 0, outOfStock: 0),
    minPrice: '',
    maxPrice: '',
  );

  factory Facets.fromJson(Map<String, dynamic> json) {
    final price = json['price'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return Facets(
      attributes: (json['attributes'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => Facet.fromJson(item as Map<String, dynamic>))
          .toList(),
      priceRanges: (price['ranges'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => PriceRange.fromJson(item as Map<String, dynamic>))
          .toList(),
      availability: AvailabilityCounts.fromJson(
        json['availability'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      minPrice: price['min']?.toString() ?? '',
      maxPrice: price['max']?.toString() ?? '',
    );
  }
}
