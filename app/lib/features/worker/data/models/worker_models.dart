export '../../../../core/models/booking_status.dart';
import '../../../../core/models/booking_status.dart';

enum VerificationStatus {
  notSubmitted,
  pending,
  underReview,
  changesRequired,
  approved,
  rejected,
  suspended;

  String get label {
    switch (this) {
      case VerificationStatus.notSubmitted:
        return 'Not Submitted';
      case VerificationStatus.pending:
        return 'Pending Verification';
      case VerificationStatus.underReview:
        return 'Under Review';
      case VerificationStatus.changesRequired:
        return 'Changes Required';
      case VerificationStatus.approved:
        return 'Approved';
      case VerificationStatus.rejected:
        return 'Rejected';
      case VerificationStatus.suspended:
        return 'Suspended';
    }
  }

  static VerificationStatus fromDb(String? status) {
    if (status == null) return VerificationStatus.pending;
    final clean = status.trim().toUpperCase();
    switch (clean) {
      case 'ACTIVE':
      case 'APPROVED':
        return VerificationStatus.approved;
      case 'UNDER_REVIEW':
        return VerificationStatus.underReview;
      case 'CHANGES_REQUIRED':
        return VerificationStatus.changesRequired;
      case 'REJECTED':
        return VerificationStatus.rejected;
      case 'SUSPENDED':
        return VerificationStatus.suspended;
      case 'NOT_SUBMITTED':
        return VerificationStatus.notSubmitted;
      case 'PENDING_VERIFICATION':
      case 'PENDING':
      default:
        return VerificationStatus.pending;
    }
  }

  String toDb() {
    switch (this) {
      case VerificationStatus.approved:
        return 'ACTIVE';
      case VerificationStatus.underReview:
        return 'UNDER_REVIEW';
      case VerificationStatus.changesRequired:
        return 'CHANGES_REQUIRED';
      case VerificationStatus.rejected:
        return 'REJECTED';
      case VerificationStatus.suspended:
        return 'SUSPENDED';
      case VerificationStatus.notSubmitted:
        return 'NOT_SUBMITTED';
      case VerificationStatus.pending:
        return 'PENDING_VERIFICATION';
    }
  }
}

class WorkerVerificationHistoryItem {
  final String id;
  final String workerId;
  final String? adminId;
  final String? adminName;
  final String? previousStatus;
  final String newStatus;
  final String action;
  final String? remarks;
  final DateTime createdAt;

  WorkerVerificationHistoryItem({
    required this.id,
    required this.workerId,
    this.adminId,
    this.adminName,
    this.previousStatus,
    required this.newStatus,
    required this.action,
    this.remarks,
    required this.createdAt,
  });

  factory WorkerVerificationHistoryItem.fromJson(Map<String, dynamic> json) {
    return WorkerVerificationHistoryItem(
      id: json['id'] as String? ?? '',
      workerId: json['worker_id'] as String? ?? '',
      adminId: json['admin_id'] as String?,
      adminName: json['admin_name'] as String?,
      previousStatus: json['previous_status'] as String?,
      newStatus: json['new_status'] as String? ?? 'PENDING',
      action: json['action'] as String? ?? 'REVIEW',
      remarks: json['remarks'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'worker_id': workerId,
    'admin_id': adminId,
    'admin_name': adminName,
    'previous_status': previousStatus,
    'new_status': newStatus,
    'action': action,
    'remarks': remarks,
    'created_at': createdAt.toIso8601String(),
  };

  String? get reviewedBy => adminName;
}

class WorkerProfile {
  final String id;
  final String name;
  final String profileImage;
  final String phone;
  final List<String> skills;
  final String experience;
  final double rating;
  final int reviewCount;
  final int completedJobs;
  final double earnings;
  final bool isVerified;
  final VerificationStatus verificationStatus;
  final bool isAvailable;
  final String serviceLocation;
  final String guildName;
  final String guildId;
  final double? latitude;
  final double? longitude;
  final DateTime? locationUpdatedAt;
  
  // 20-field registration extensions
  final String? dob;
  final String? gender;
  final String? address;
  final String? city;
  final String? district;
  final String? pinCode;
  final String? trade;
  final String? primarySkill;
  final String? skillLevel;
  final String? membershipId;
  final String? verificationRemarks;
  final String? bio;
  final bool declarationAccepted;
  final DateTime? registeredAt;

  String get federationName => guildName;
  String? get pincode => pinCode;

  WorkerProfile({
    required this.id,
    required this.name,
    required this.profileImage,
    required this.phone,
    required this.skills,
    required this.experience,
    required this.rating,
    this.reviewCount = 0,
    required this.completedJobs,
    required this.earnings,
    required this.isVerified,
    required this.verificationStatus,
    required this.isAvailable,
    required this.serviceLocation,
    required this.guildName,
    required this.guildId,
    this.latitude,
    this.longitude,
    this.locationUpdatedAt,
    this.dob,
    this.gender,
    this.address,
    this.city,
    this.district,
    this.pinCode,
    this.trade,
    this.primarySkill,
    this.skillLevel,
    this.membershipId,
    this.verificationRemarks,
    this.bio,
    this.declarationAccepted = true,
    this.registeredAt,
  });

  bool get hasLocation => latitude != null && longitude != null;

  WorkerProfile copyWith({
    String? id,
    String? name,
    String? profileImage,
    String? phone,
    List<String>? skills,
    String? experience,
    double? rating,
    int? reviewCount,
    int? completedJobs,
    double? earnings,
    bool? isVerified,
    VerificationStatus? verificationStatus,
    bool? isAvailable,
    String? serviceLocation,
    String? guildName,
    String? guildId,
    double? latitude,
    double? longitude,
    DateTime? locationUpdatedAt,
    String? dob,
    String? gender,
    String? address,
    String? city,
    String? district,
    String? pinCode,
    String? trade,
    String? primarySkill,
    String? skillLevel,
    String? membershipId,
    String? verificationRemarks,
    String? bio,
    bool? declarationAccepted,
    DateTime? registeredAt,
  }) {
    return WorkerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      profileImage: profileImage ?? this.profileImage,
      phone: phone ?? this.phone,
      skills: skills ?? this.skills,
      experience: experience ?? this.experience,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      completedJobs: completedJobs ?? this.completedJobs,
      earnings: earnings ?? this.earnings,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      isAvailable: isAvailable ?? this.isAvailable,
      serviceLocation: serviceLocation ?? this.serviceLocation,
      guildName: guildName ?? this.guildName,
      guildId: guildId ?? this.guildId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      city: city ?? this.city,
      district: district ?? this.district,
      pinCode: pinCode ?? this.pinCode,
      trade: trade ?? this.trade,
      primarySkill: primarySkill ?? this.primarySkill,
      skillLevel: skillLevel ?? this.skillLevel,
      membershipId: membershipId ?? this.membershipId,
      verificationRemarks: verificationRemarks ?? this.verificationRemarks,
      bio: bio ?? this.bio,
      declarationAccepted: declarationAccepted ?? this.declarationAccepted,
      registeredAt: registeredAt ?? this.registeredAt,
    );
  }
}

class JobRequest {
  final String id;
  final String customerId;
  final String customerName;
  final String customerLocation;
  final String customerPhone;
  final String serviceName;
  final String date;
  final String time;
  final double baseAmount;
  final double laborAllowance;
  final BookingStatus status;
  final String? distanceKm;
  final String createdAt;

  double get totalAmount => baseAmount + laborAllowance;

  JobRequest({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerLocation,
    required this.customerPhone,
    required this.serviceName,
    required this.date,
    required this.time,
    required this.baseAmount,
    required this.laborAllowance,
    required this.status,
    this.distanceKm,
    required this.createdAt,
  });

  JobRequest copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerLocation,
    String? customerPhone,
    String? serviceName,
    String? date,
    String? time,
    double? baseAmount,
    double? laborAllowance,
    BookingStatus? status,
    String? distanceKm,
    String? createdAt,
  }) {
    return JobRequest(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerLocation: customerLocation ?? this.customerLocation,
      customerPhone: customerPhone ?? this.customerPhone,
      serviceName: serviceName ?? this.serviceName,
      date: date ?? this.date,
      time: time ?? this.time,
      baseAmount: baseAmount ?? this.baseAmount,
      laborAllowance: laborAllowance ?? this.laborAllowance,
      status: status ?? this.status,
      distanceKm: distanceKm ?? this.distanceKm,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

