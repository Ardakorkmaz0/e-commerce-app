import 'package:ecommerce_mobile/features/products/data/models/product_model.dart';
import 'package:ecommerce_mobile/features/products/presentation/variant_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Trimmed copy of a real `/products/<slug>/` response, so a change to the
/// field names on either side breaks this test rather than the app.
Map<String, dynamic> productJson() => <String, dynamic>{
  'id': 1,
  'name': 'PlayStation 5',
  'slug': 'playstation-5',
  'description': 'Base description.',
  'price': '649.00',
  'stock': 10,
  'in_stock': true,
  'category': 'Consoles',
  'category_slug': 'consoles',
  'image_url': 'https://example.com/base.png',
  'has_variants': true,
  'option_groups': <dynamic>[
    {
      'name': 'Colour',
      'slug': 'colour',
      'values': <dynamic>[
        {'id': 1, 'name': 'White', 'slug': 'white', 'swatch_color': '#F8FAFC'},
        {'id': 2, 'name': 'Black', 'slug': 'black', 'swatch_color': '#111827'},
      ],
    },
    {
      'name': 'Storage',
      'slug': 'storage',
      'values': <dynamic>[
        {'id': 3, 'name': '1 TB', 'slug': '1-tb', 'swatch_color': ''},
        {'id': 4, 'name': '2 TB', 'slug': '2-tb', 'swatch_color': ''},
      ],
    },
  ],
  'variants': <dynamic>[
    {
      'id': 10,
      'option_value_ids': <dynamic>[1, 3],
      'option_label': 'White / 1 TB',
      'price': '649.00',
      'stock': 0,
      'in_stock': false,
      'description': '',
      'image_url': 'https://example.com/white.png',
    },
    {
      'id': 11,
      'option_value_ids': <dynamic>[2, 4],
      'option_label': 'Black / 2 TB',
      'price': '899.00',
      'stock': 3,
      'in_stock': true,
      'description': 'The roomy one.',
      'image_url': '',
    },
  ],
};

void main() {
  test('parses option groups and variants', () {
    final product = Product.fromJson(productJson());

    expect(product.hasVariants, isTrue);
    expect(product.optionGroups.length, 2);
    expect(product.optionGroups.first.isColour, isTrue);
    expect(product.optionGroups.last.isColour, isFalse);
    expect(product.variants.length, 2);
    expect(product.variants.last.formattedPrice, r'$899.00');
  });

  test('matches a selection to its variant regardless of order', () {
    final product = Product.fromJson(productJson());

    final match = findVariant(product.variants, <String, int>{
      'storage': 4,
      'colour': 2,
    });

    expect(match?.id, 11);
  });

  test('returns null for a combination that was never built', () {
    final product = Product.fromJson(productJson());

    final match = findVariant(product.variants, <String, int>{
      'colour': 1,
      'storage': 4,
    });

    expect(match, isNull);
  });

  test('opens on the first combination that is in stock', () {
    final product = Product.fromJson(productJson());

    // White / 1 TB comes first but is sold out, so Black / 2 TB wins.
    expect(initialSelection(product), <String, int>{
      'colour': 2,
      'storage': 4,
    });
  });

  test('reads swatch colours and rejects anything else', () {
    expect(parseSwatch('#111827'), const Color(0xFF111827));
    expect(parseSwatch(''), isNull);
    expect(parseSwatch('red'), isNull);
  });
}
