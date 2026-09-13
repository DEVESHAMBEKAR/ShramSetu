export '../../../../core/models/booking_status.dart';
import '../../../../core/models/booking_status.dart';

enum VerificationStatus {
  notSubmitted,
  pending,
  approved,
  rejected,
}

class WorkerProfile {
  final String id;
  final String name;
  final String profileImage;
  final String phone;
  final List<String> skills;
  final String experience;
  final double rating;
  final int completedJobs;
  final double earnings;
  final bool isVerified;
  final VerificationStatus verificationStatus;
  final bool isAvailable;
  final String serviceLocation;
  final String guildName;
  final String guildId;

  WorkerProfile({
    required this.id,
    required this.name,
    required this.profileImage,
    required this.phone,
    required this.skills,
    required this.experience,
    required this.rating,
    required this.completedJobs,
    required this.earnings,
    required this.isVerified,
    required this.verificationStatus,
    required this.isAvailable,
    required this.serviceLocation,
    required this.guildName,
    required this.guildId,
  });

  WorkerProfile copyWith({
    String? id,
    String? name,
    String? profileImage,
    String? phone,
    List<String>? skills,
    String? experience,
    double? rating,
    int? completedJobs,
    double? earnings,
    bool? isVerified,
    VerificationStatus? verificationStatus,
    bool? isAvailable,
    String? serviceLocation,
    String? guildName,
    String? guildId,
  }) {
    return WorkerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      profileImage: profileImage ?? this.profileImage,
      phone: phone ?? this.phone,
      skills: skills ?? this.skills,
      experience: experience ?? this.experience,
      rating: rating ?? this.rating,
      completedJobs: completedJobs ?? this.completedJobs,
      earnings: earnings ?? this.earnings,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      isAvailable: isAvailable ?? this.isAvailable,
      serviceLocation: serviceLocation ?? this.serviceLocation,
      guildName: guildName ?? this.guildName,
      guildId: guildId ?? this.guildId,
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

