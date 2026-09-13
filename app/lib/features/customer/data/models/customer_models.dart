class ServiceCategory {
  final String id;
  final String name;
  final String iconData; // Storing the material symbol name

  const ServiceCategory({
    required this.id,
    required this.name,
    required this.iconData,
  });
}

class Worker {
  final String id;
  final String name;
  final String categoryId;
  final int rate;
  final double rating;
  final int reviewCount;
  final int jobsCompleted;
  final double distanceKm;
  final String experience;
  final String availability;
  final List<String> specializations;
  final String locationTag;
  final String imageUrl;
  final bool isUnionGold;
  final bool isCoopMaster;
  final String? customTag;
  
  // Profile specific fields
  final String? bio;
  final String? federationId;
  final String? insuranceAmount;
  final List<String> languages;
  final List<String> serviceAreas;

  const Worker({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.rate,
    required this.rating,
    required this.reviewCount,
    required this.jobsCompleted,
    required this.distanceKm,
    required this.experience,
    required this.availability,
    required this.specializations,
    required this.locationTag,
    required this.imageUrl,
    this.isUnionGold = false,
    this.isCoopMaster = false,
    this.customTag,
    this.bio,
    this.federationId,
    this.insuranceAmount,
    this.languages = const [],
    this.serviceAreas = const [],
  });
}
