/// Typed model for the authenticated customer's profile + default address.
class CustomerProfile {
  final String id;
  final String fullName;
  final String phone;
  final String? avatarUrl;
  final CustomerAddress? defaultAddress;

  const CustomerProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    this.avatarUrl,
    this.defaultAddress,
  });

  /// A profile is considered complete when:
  /// 1. full_name is non-empty and is NOT the auto-generated placeholder ('User XXXX')
  /// 2. Customer has at least one saved address
  bool get isComplete {
    final nameOk = fullName.trim().isNotEmpty && !fullName.startsWith('User ');
    return nameOk && defaultAddress != null;
  }

  CustomerProfile copyWith({
    String? fullName,
    String? avatarUrl,
    CustomerAddress? defaultAddress,
  }) {
    return CustomerProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      defaultAddress: defaultAddress ?? this.defaultAddress,
    );
  }

  factory CustomerProfile.fromMap(Map<String, dynamic> map, {CustomerAddress? defaultAddress}) {
    return CustomerProfile(
      id: map['id'] as String,
      fullName: map['full_name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      avatarUrl: map['avatar_url'] as String?,
      defaultAddress: defaultAddress,
    );
  }
}

/// Typed model for a customer address row.
class CustomerAddress {
  final String id;
  final String addressLine;
  final String area;
  final String city;
  final String state;
  final String postalCode;
  final bool isDefault;

  const CustomerAddress({
    required this.id,
    required this.addressLine,
    required this.area,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.isDefault,
  });

  String get displayString {
    final parts = [
      if (area.isNotEmpty) area,
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
    ];
    return parts.join(', ');
  }

  factory CustomerAddress.fromMap(Map<String, dynamic> map) {
    return CustomerAddress(
      id: map['id'] as String,
      addressLine: map['address_line'] as String? ?? '',
      area: map['area'] as String? ?? '',
      city: map['city'] as String? ?? '',
      state: map['state'] as String? ?? '',
      postalCode: map['postal_code'] as String? ?? '',
      isDefault: map['is_default'] as bool? ?? false,
    );
  }
}
