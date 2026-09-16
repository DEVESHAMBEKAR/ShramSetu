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
  final double? latitude;
  final double? longitude;

  const CustomerAddress({
    required this.id,
    required this.addressLine,
    required this.area,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.isDefault,
    this.latitude,
    this.longitude,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  String get displayString {
    final parts = [
      if (area.isNotEmpty) area,
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
    ];
    return parts.join(', ');
  }

  CustomerAddress copyWith({
    String? id,
    String? addressLine,
    String? area,
    String? city,
    String? state,
    String? postalCode,
    bool? isDefault,
    double? latitude,
    double? longitude,
  }) {
    return CustomerAddress(
      id: id ?? this.id,
      addressLine: addressLine ?? this.addressLine,
      area: area ?? this.area,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      isDefault: isDefault ?? this.isDefault,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'address_line': addressLine,
    'area': area,
    'city': city,
    'state': state,
    'postal_code': postalCode,
    'is_default': isDefault,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };

  factory CustomerAddress.fromMap(Map<String, dynamic> map) {
    return CustomerAddress(
      id: map['id'] as String? ?? '',
      addressLine: map['address_line'] as String? ?? '',
      area: map['area'] as String? ?? '',
      city: map['city'] as String? ?? '',
      state: map['state'] as String? ?? '',
      postalCode: map['postal_code'] as String? ?? '',
      isDefault: map['is_default'] as bool? ?? false,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }
}

