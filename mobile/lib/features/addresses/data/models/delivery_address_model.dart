class DeliveryAddress {
  const DeliveryAddress({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phoneNumber,
    required this.addressLine1,
    required this.addressLine2,
    required this.district,
    required this.city,
    required this.postalCode,
    required this.countryCode,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String label;
  final String recipientName;
  final String phoneNumber;
  final String addressLine1;
  final String addressLine2;
  final String district;
  final String city;
  final String postalCode;
  final String countryCode;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      id: (json['id'] as num).toInt(),
      label: json['label'] as String? ?? '',
      recipientName: json['recipient_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      addressLine1: json['address_line_1'] as String? ?? '',
      addressLine2: json['address_line_2'] as String? ?? '',
      district: json['district'] as String? ?? '',
      city: json['city'] as String? ?? '',
      postalCode: json['postal_code'] as String? ?? '',
      countryCode: json['country_code'] as String? ?? 'TR',
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }

  String get locationLabel {
    final parts = <String>[
      district,
      city,
    ].where((part) => part.trim().isNotEmpty).toList();
    return parts.join(', ');
  }

  String get formattedAddress {
    return <String>[
      addressLine1,
      if (addressLine2.isNotEmpty) addressLine2,
      locationLabel,
      if (postalCode.isNotEmpty) postalCode,
      countryCode,
    ].where((part) => part.trim().isNotEmpty).join(', ');
  }
}

class DeliveryAddressInput {
  const DeliveryAddressInput({
    required this.label,
    required this.recipientName,
    required this.phoneNumber,
    required this.addressLine1,
    required this.addressLine2,
    required this.district,
    required this.city,
    required this.postalCode,
    required this.countryCode,
    required this.isDefault,
  });

  final String label;
  final String recipientName;
  final String phoneNumber;
  final String addressLine1;
  final String addressLine2;
  final String district;
  final String city;
  final String postalCode;
  final String countryCode;
  final bool isDefault;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'label': label,
      'recipient_name': recipientName,
      'phone_number': phoneNumber,
      'address_line_1': addressLine1,
      'address_line_2': addressLine2,
      'district': district,
      'city': city,
      'postal_code': postalCode,
      'country_code': countryCode.toUpperCase(),
      'is_default': isDefault,
    };
  }
}
