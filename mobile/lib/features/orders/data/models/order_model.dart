/// One line as it was bought.
///
/// Every field is the copy taken at checkout, so a product that has since
/// been renamed, repriced or deleted still reads the way the shopper
/// remembers it. [slug] may 404 for exactly that reason.
class OrderLine {
  const OrderLine({
    required this.id,
    required this.name,
    required this.slug,
    required this.optionLabel,
    required this.sellerName,
    required this.imageUrl,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    required this.shippedAt,
  });

  final int id;
  final String name;
  final String slug;
  final String optionLabel;
  final String sellerName;
  final String imageUrl;
  final String unitPrice;
  final int quantity;
  final String lineTotal;
  final DateTime? shippedAt;

  bool get isShipped => shippedAt != null;

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    final shipped = json['shipped_at'] as String?;
    return OrderLine(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      optionLabel: json['option_label'] as String? ?? '',
      sellerName: json['seller_name'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      unitPrice: json['unit_price']?.toString() ?? '0',
      quantity: json['quantity'] as int? ?? 0,
      lineTotal: json['line_total']?.toString() ?? '0',
      shippedAt: shipped == null ? null : DateTime.tryParse(shipped),
    );
  }
}

class Order {
  const Order({
    required this.orderNumber,
    required this.status,
    required this.statusDisplay,
    required this.subtotal,
    required this.shipping,
    required this.total,
    required this.itemCount,
    required this.items,
    required this.recipientName,
    required this.phoneNumber,
    required this.addressLine1,
    required this.addressLine2,
    required this.district,
    required this.city,
    required this.postalCode,
    required this.cardBrand,
    required this.cardLast4,
    required this.isCancellable,
    required this.lastPaymentError,
    required this.createdAt,
    required this.paidAt,
    required this.shippedAt,
    required this.deliveredAt,
    required this.cancelledAt,
  });

  final String orderNumber;

  /// pending / paid / shipped / delivered / cancelled
  final String status;
  final String statusDisplay;

  final String subtotal;
  final String shipping;
  final String total;
  final int itemCount;
  final List<OrderLine> items;

  final String recipientName;
  final String phoneNumber;
  final String addressLine1;
  final String addressLine2;
  final String district;
  final String city;
  final String postalCode;

  final String cardBrand;
  final String cardLast4;

  final bool isCancellable;

  /// Why an unpaid order is still unpaid; empty otherwise.
  final String lastPaymentError;

  final DateTime? createdAt;
  final DateTime? paidAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;

  bool get shipsFree => (double.tryParse(shipping) ?? 0) == 0;

  /// Set once any seller has posted their parcel, which is what closes
  /// cancelling for the whole order.
  bool get hasShippedLines => items.any((item) => item.isShipped);

  static DateTime? _at(Map<String, dynamic> json, String key) {
    final raw = json[key] as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      orderNumber: json['order_number'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      statusDisplay: json['status_display'] as String? ?? '',
      subtotal: json['subtotal']?.toString() ?? '0.00',
      shipping: json['shipping']?.toString() ?? '0.00',
      total: json['total']?.toString() ?? '0.00',
      itemCount: json['item_count'] as int? ?? 0,
      items: (json['items'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => OrderLine.fromJson(item as Map<String, dynamic>))
          .toList(),
      recipientName: json['recipient_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      addressLine1: json['address_line_1'] as String? ?? '',
      addressLine2: json['address_line_2'] as String? ?? '',
      district: json['district'] as String? ?? '',
      city: json['city'] as String? ?? '',
      postalCode: json['postal_code'] as String? ?? '',
      cardBrand: json['card_brand'] as String? ?? '',
      cardLast4: json['card_last4'] as String? ?? '',
      isCancellable: json['is_cancellable'] as bool? ?? false,
      lastPaymentError: json['last_payment_error'] as String? ?? '',
      createdAt: _at(json, 'created_at'),
      paidAt: _at(json, 'paid_at'),
      shippedAt: _at(json, 'shipped_at'),
      deliveredAt: _at(json, 'delivered_at'),
      cancelledAt: _at(json, 'cancelled_at'),
    );
  }
}

/// One order narrowed to a single seller's lines.
class SellerOrder {
  const SellerOrder({
    required this.orderNumber,
    required this.status,
    required this.statusDisplay,
    required this.items,
    required this.sellerTotal,
    required this.recipientName,
    required this.phoneNumber,
    required this.addressLine1,
    required this.addressLine2,
    required this.district,
    required this.city,
    required this.postalCode,
    required this.createdAt,
  });

  final String orderNumber;
  final String status;
  final String statusDisplay;
  final List<OrderLine> items;
  final String sellerTotal;

  final String recipientName;
  final String phoneNumber;
  final String addressLine1;
  final String addressLine2;
  final String district;
  final String city;
  final String postalCode;

  final DateTime? createdAt;

  bool get hasSomethingToShip =>
      status != 'cancelled' && items.any((item) => !item.isShipped);

  factory SellerOrder.fromJson(Map<String, dynamic> json) {
    final created = json['created_at'] as String?;
    return SellerOrder(
      orderNumber: json['order_number'] as String? ?? '',
      status: json['status'] as String? ?? 'paid',
      statusDisplay: json['status_display'] as String? ?? '',
      items: (json['items'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => OrderLine.fromJson(item as Map<String, dynamic>))
          .toList(),
      sellerTotal: json['seller_total']?.toString() ?? '0.00',
      recipientName: json['recipient_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      addressLine1: json['address_line_1'] as String? ?? '',
      addressLine2: json['address_line_2'] as String? ?? '',
      district: json['district'] as String? ?? '',
      city: json['city'] as String? ?? '',
      postalCode: json['postal_code'] as String? ?? '',
      createdAt: created == null ? null : DateTime.tryParse(created),
    );
  }
}
