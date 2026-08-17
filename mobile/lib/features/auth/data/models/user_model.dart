class UserModel {
  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.isStaff,
    required this.isSeller,
    required this.isVerifiedSeller,
    required this.storeName,
  });

  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final bool isStaff;
  final bool isSeller;
  final bool isVerifiedSeller;
  final String storeName;

  // Converts the JSON response from GET /api/v1/auth/me/ into a UserModel
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      isStaff: json['is_staff'] as bool? ?? false,
      isSeller: json['is_seller'] as bool? ?? false,
      isVerifiedSeller: json['is_verified_seller'] as bool? ?? false,
      storeName: json['store_name'] as String? ?? '',
    );
  }

  // Returns "First Last" if available, falls back to username
  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isNotEmpty ? full : username;
  }
}
