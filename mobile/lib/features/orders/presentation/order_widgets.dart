import 'package:ecommerce_mobile/core/theme/app_theme.dart';
import 'package:ecommerce_mobile/features/cart/data/models/cart_model.dart';
import 'package:ecommerce_mobile/features/orders/data/models/order_model.dart';
import 'package:flutter/material.dart';

/// "19 August 2026" — the date is all an order list needs.
String formatOrderDate(DateTime? value) {
  if (value == null) return '';
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final local = value.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

String formatOrderMoment(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${formatOrderDate(value)}, $hour:$minute';
}

/// The status pill.
///
/// A pending order says *why* it is pending: "Payment failed" is what the
/// shopper needs to read, not the word "pending".
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({
    super.key,
    required this.status,
    required this.label,
    this.paymentFailed = false,
  });

  final String status;
  final String label;
  final bool paymentFailed;

  static const _tones = <String, (Color, Color)>{
    'paid': (Color(0xFFDBEAFE), Color(0xFF1D4ED8)),
    'shipped': (Color(0xFFFEF3C7), Color(0xFFB45309)),
    'delivered': (Color(0xFFD1FAE5), Color(0xFF047857)),
    'cancelled': (Color(0xFFFEE2E2), Color(0xFFB91C1C)),
    'pending': (Color(0xFFFEE2E2), Color(0xFFB91C1C)),
  };

  @override
  Widget build(BuildContext context) {
    final tone = _tones[status] ?? _tones['paid']!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tone.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        paymentFailed ? 'Payment failed' : label,
        style: TextStyle(
          color: tone.$2,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// One line of an order, shown the same way wherever it appears.
class OrderLineRow extends StatelessWidget {
  const OrderLineRow({super.key, required this.line, this.onTap});

  final OrderLine line;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 48,
                height: 48,
                color: AppColors.primary.withAlpha(20),
                child: line.imageUrl.isEmpty
                    ? Icon(
                        Icons.image_outlined,
                        color: AppColors.primary.withAlpha(100),
                      )
                    : Image.network(
                        line.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.primary.withAlpha(100),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    line.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (line.optionLabel.isNotEmpty)
                    Text(
                      line.optionLabel,
                      style: TextStyle(
                        color: context.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    '${formatMoney(line.unitPrice)} × ${line.quantity}'
                    '${line.sellerName.isEmpty ? '' : ' · ${line.sellerName}'}',
                    style: TextStyle(color: context.mutedText, fontSize: 12),
                  ),
                  if (line.isShipped)
                    const Text(
                      'Shipped',
                      style: TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              formatMoney(line.lineTotal),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
