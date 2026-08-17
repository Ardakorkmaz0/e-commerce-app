/// A saved card as the API describes it.
///
/// There is no card number here, and none in the database either. Only what
/// is safe to display survives tokenisation on the server.
class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.brand,
    required this.brandDisplay,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    required this.holderName,
    required this.isDefault,
    required this.isExpired,
  });

  final int id;
  final String brand;
  final String brandDisplay;
  final String last4;
  final int expMonth;
  final int expYear;
  final String holderName;
  final bool isDefault;
  final bool isExpired;

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] as int,
      brand: json['brand'] as String? ?? '',
      brandDisplay: json['brand_display'] as String? ?? '',
      last4: json['last4'] as String? ?? '',
      expMonth: json['exp_month'] as int? ?? 0,
      expYear: json['exp_year'] as int? ?? 0,
      holderName: json['holder_name'] as String? ?? '',
      isDefault: json['is_default'] as bool? ?? false,
      isExpired: json['is_expired'] as bool? ?? false,
    );
  }

  String get maskedNumber => '···· ···· ···· $last4';

  String get formattedExpiry =>
      '${expMonth.toString().padLeft(2, '0')} / $expYear';
}

/// What the add-card form sends. Built, posted and discarded — never held
/// in any provider or written to storage.
class PaymentMethodInput {
  const PaymentMethodInput({
    required this.cardNumber,
    required this.securityCode,
    required this.holderName,
    required this.expMonth,
    required this.expYear,
    required this.isDefault,
  });

  final String cardNumber;
  final String securityCode;
  final String holderName;
  final int expMonth;
  final int expYear;
  final bool isDefault;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'card_number': cardNumber,
    'security_code': securityCode,
    'holder_name': holderName,
    'exp_month': expMonth,
    'exp_year': expYear,
    'is_default': isDefault,
  };
}
