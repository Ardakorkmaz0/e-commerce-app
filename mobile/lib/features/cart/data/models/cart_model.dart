class CartItem {
  const CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.slug,
    required this.optionLabel,
    required this.imageUrl,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.availableStock,
    required this.hasStockIssue,
  });

  final int id;
  final int productId;
  final String name;
  final String slug;

  /// "White / 2 controllers / 1 TB", empty for products without options.
  final String optionLabel;

  final String imageUrl;
  final int quantity;

  // Money stays a string, as it comes from the backend's Decimal columns.
  final String unitPrice;
  final String lineTotal;

  final int availableStock;
  final bool hasStockIssue;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as int,
      productId: json['product_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      optionLabel: json['option_label'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      unitPrice: json['unit_price']?.toString() ?? '0',
      lineTotal: json['line_total']?.toString() ?? '0',
      availableStock: json['available_stock'] as int? ?? 0,
      hasStockIssue: json['has_stock_issue'] as bool? ?? false,
    );
  }
}

class Cart {
  const Cart({
    required this.items,
    required this.itemCount,
    required this.subtotal,
    required this.shipping,
    required this.total,
    required this.freeShippingRemaining,
    required this.freeShippingThreshold,
    required this.hasStockIssues,
  });

  final List<CartItem> items;
  final int itemCount;

  // Every amount is worked out by the server, so the checkout screen shows
  // these rather than adding anything up itself.
  final String subtotal;
  final String shipping;
  final String total;

  /// '0.00' once delivery is free.
  final String freeShippingRemaining;
  final String freeShippingThreshold;

  final bool hasStockIssues;

  bool get shipsFree => (double.tryParse(shipping) ?? 0) == 0;

  static const empty = Cart(
    items: <CartItem>[],
    itemCount: 0,
    subtotal: '0.00',
    shipping: '0.00',
    total: '0.00',
    freeShippingRemaining: '0.00',
    freeShippingThreshold: '0.00',
    hasStockIssues: false,
  );

  bool get isEmpty => items.isEmpty;

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      items: (json['items'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      itemCount: json['item_count'] as int? ?? 0,
      subtotal: json['subtotal']?.toString() ?? '0.00',
      shipping: json['shipping']?.toString() ?? '0.00',
      total: json['total']?.toString() ?? '0.00',
      freeShippingRemaining:
          json['free_shipping_remaining']?.toString() ?? '0.00',
      freeShippingThreshold:
          json['free_shipping_threshold']?.toString() ?? '0.00',
      hasStockIssues: json['has_stock_issues'] as bool? ?? false,
    );
  }
}

/// Display only — never used for arithmetic.
String formatMoney(String amount) {
  final value = double.tryParse(amount);
  return value == null ? amount : '\$${value.toStringAsFixed(2)}';
}
