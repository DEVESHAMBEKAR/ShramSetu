/// Typed model for the authenticated customer's profile + default address and federation assignment.
class CustomerProfile {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String? avatarUrl;
  final CustomerAddress? defaultAddress;
  final String? federationId;
  final String? federationName;

  const CustomerProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.avatarUrl,
    this.defaultAddress,
    this.federationId,
    this.federationName,
  });

  /// A profile is considered complete when:
  /// 1. full_name is non-empty, not a phone number, and is NOT the auto-generated placeholder ('User XXXX')
  /// 2. Customer has at least one saved address
  bool get isComplete {
    final cleanName = fullName.trim();
    final isPhone = RegExp(r'^\+?\d{10,13}$').hasMatch(cleanName);
    final nameOk = cleanName.isNotEmpty &&
        !isPhone &&
        !cleanName.toLowerCase().startsWith('user ') &&
        cleanName.toLowerCase() != 'ananya' &&
        cleanName.toLowerCase() != 'demo user' &&
        cleanName.toLowerCase() != 'test user';
    return nameOk && defaultAddress != null;
  }

  CustomerProfile copyWith({
    String? fullName,
    String? phone,
    String? email,
    String? avatarUrl,
    CustomerAddress? defaultAddress,
    String? federationId,
    String? federationName,
  }) {
    return CustomerProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      defaultAddress: defaultAddress ?? this.defaultAddress,
      federationId: federationId ?? this.federationId,
      federationName: federationName ?? this.federationName,
    );
  }

  factory CustomerProfile.fromMap(
    Map<String, dynamic> map, {
    CustomerAddress? defaultAddress,
    String? federationName,
  }) {
    final fedId = (map['federation_id'] ?? map['federation_ref_id']) as String?;
    return CustomerProfile(
      id: map['id'] as String,
      fullName: map['full_name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      defaultAddress: defaultAddress,
      federationId: fedId,
      federationName: federationName ?? map['federation_name'] as String?,
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
  final String? district;
  final String? federationId;

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
    this.district,
    this.federationId,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  String get displayString {
    final parts = [
      if (area.isNotEmpty) area,
      if (city.isNotEmpty) city,
      if (district != null && district!.isNotEmpty && district != city) district!,
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
    String? district,
    String? federationId,
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
      district: district ?? this.district,
      federationId: federationId ?? this.federationId,
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
    if (district != null) 'district': district,
    if (federationId != null) 'federation_id': federationId,
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
      district: map['district'] as String?,
      federationId: map['federation_id'] as String?,
    );
  }
}
