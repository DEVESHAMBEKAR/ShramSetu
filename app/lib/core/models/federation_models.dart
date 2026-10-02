/// Multi-federation data models for ShramSetu.
/// Supports state, district, city, and cooperative union partitioning.
class FederationModel {
  final String id;
  final String name;
  final String state;
  final String district;
  final String city;
  final String? registrationNo;
  final String? contactPhone;
  final String? contactEmail;
  final bool isActive;

  const FederationModel({
    required this.id,
    required this.name,
    this.state = 'Maharashtra',
    required this.district,
    required this.city,
    this.registrationNo,
    this.contactPhone,
    this.contactEmail,
    this.isActive = true,
  });

  factory FederationModel.fromJson(Map<String, dynamic> json) {
    return FederationModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Labour Cooperative Federation',
      state: json['state'] as String? ?? 'Maharashtra',
      district: json['district'] as String? ?? 'Pune',
      city: json['city'] as String? ?? 'Pune',
      registrationNo: json['registration_no'] as String?,
      contactPhone: json['contact_phone'] as String?,
      contactEmail: json['contact_email'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'state': state,
    'district': district,
    'city': city,
    if (registrationNo != null) 'registration_no': registrationNo,
    if (contactPhone != null) 'contact_phone': contactPhone,
    if (contactEmail != null) 'contact_email': contactEmail,
    'is_active': isActive,
  };

  /// Initial default federations available in the cooperative network.
  static const List<FederationModel> defaultFederations = [
    FederationModel(
      id: '11111111-0000-0000-0000-000000000001',
      name: 'Pune District Labour Cooperative Federation',
      state: 'Maharashtra',
      district: 'Pune',
      city: 'Pune',
      registrationNo: 'MH-PUN-COOP-2018-88',
      contactPhone: '+91 20 2553 4401',
    ),
    FederationModel(
      id: '22222222-0000-0000-0000-000000000002',
      name: 'Nashik District Artisans Cooperative Union',
      state: 'Maharashtra',
      district: 'Nashik',
      city: 'Nashik',
      registrationNo: 'MH-NSK-COOP-2020-14',
      contactPhone: '+91 253 257 8820',
    ),
    FederationModel(
      id: '33333333-0000-0000-0000-000000000003',
      name: 'Mumbai Metropolitan Labour Federation',
      state: 'Maharashtra',
      district: 'Mumbai City',
      city: 'Mumbai',
      registrationNo: 'MH-MUM-COOP-2016-09',
      contactPhone: '+91 22 2261 1140',
    ),
    FederationModel(
      id: '44444444-0000-0000-0000-000000000004',
      name: 'Chhatrapati Sambhajinagar Labour Federation',
      state: 'Maharashtra',
      district: 'Chhatrapati Sambhajinagar',
      city: 'Chhatrapati Sambhajinagar',
      registrationNo: 'MH-CSN-COOP-2021-32',
      contactPhone: '+91 240 233 4560',
    ),
    FederationModel(
      id: '55555555-0000-0000-0000-000000000005',
      name: 'Nagpur District Shramik Cooperative Union',
      state: 'Maharashtra',
      district: 'Nagpur',
      city: 'Nagpur',
      registrationNo: 'MH-NGP-COOP-2019-55',
      contactPhone: '+91 712 256 7890',
    ),
  ];
}
