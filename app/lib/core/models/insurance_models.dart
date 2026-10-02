/// Typed models for Worker Welfare & Group Insurance Profile in ShramSetu.
/// NOTE: External insurance provider integration pending. This represents
/// the authoritative cooperative registry and federation administration record layer.
library;

enum InsuranceStatus {
  active,
  pending,
  expired,
  suspended;

  String toDbString() => name.toUpperCase();

  static InsuranceStatus fromDbString(String? val) {
    if (val == null) return InsuranceStatus.pending;
    switch (val.trim().toUpperCase()) {
      case 'ACTIVE': return InsuranceStatus.active;
      case 'EXPIRED': return InsuranceStatus.expired;
      case 'SUSPENDED': return InsuranceStatus.suspended;
      case 'PENDING':
      default:
        return InsuranceStatus.pending;
    }
  }

  String get displayLabel {
    switch (this) {
      case InsuranceStatus.active: return 'Active Policy';
      case InsuranceStatus.pending: return 'Under Verification';
      case InsuranceStatus.expired: return 'Policy Expired';
      case InsuranceStatus.suspended: return 'Suspended';
    }
  }
}

enum InsuranceVerificationStatus {
  verified,
  pending,
  rejected;

  String toDbString() => name.toUpperCase();

  static InsuranceVerificationStatus fromDbString(String? val) {
    if (val == null) return InsuranceVerificationStatus.pending;
    switch (val.trim().toUpperCase()) {
      case 'VERIFIED': return InsuranceVerificationStatus.verified;
      case 'REJECTED': return InsuranceVerificationStatus.rejected;
      case 'PENDING':
      default:
        return InsuranceVerificationStatus.pending;
    }
  }
}

class WorkerInsuranceModel {
  final String id;
  final String workerId;
  final String providerName;
  final String policyNumber;
  final String coverageType;
  final double coverageAmount;
  final DateTime startDate;
  final DateTime expiryDate;
  final InsuranceStatus status;
  final InsuranceVerificationStatus verificationStatus;
  final String? adminRemarks;
  final String? claimSupportPhone;
  final String? claimInstructions;
  final bool isExternalIntegrationPending;

  WorkerInsuranceModel({
    String? id,
    required this.workerId,
    this.providerName = 'National Insurance Co. / Union Group Policy',
    required this.policyNumber,
    this.coverageType = 'Accidental & Health Insurance',
    this.coverageAmount = 500000.0,
    DateTime? startDate,
    DateTime? expiryDate,
    DateTime? validUntil,
    this.status = InsuranceStatus.active,
    this.verificationStatus = InsuranceVerificationStatus.verified,
    this.adminRemarks,
    this.claimSupportPhone,
    this.claimInstructions,
    this.isExternalIntegrationPending = true,
  })  : id = id ?? 'ins-$workerId',
        startDate = startDate ?? DateTime.now().subtract(const Duration(days: 30)),
        expiryDate = expiryDate ?? validUntil ?? DateTime.now().add(const Duration(days: 335));

  DateTime get validUntil => expiryDate;

  /// Returns masked policy number (e.g., 'POL-••••-4921') to protect worker sensitive data.
  String get maskedPolicyNumber {
    if (policyNumber.length <= 4) return policyNumber;
    final last4 = policyNumber.substring(policyNumber.length - 4);
    return 'POL-••••-$last4';
  }

  bool get isExpired => DateTime.now().isAfter(expiryDate);

  factory WorkerInsuranceModel.fromJson(Map<String, dynamic> json) {
    final status = InsuranceStatus.fromDbString(json['status'] as String?);
    final verStatus = InsuranceVerificationStatus.fromDbString(json['verification_status'] as String?);
    final amt = (json['coverage_amount'] as num?)?.toDouble() ?? 500000.0;

    DateTime start;
    try {
      start = DateTime.parse(json['start_date'] as String);
    } catch (_) {
      start = DateTime.now().subtract(const Duration(days: 30));
    }

    DateTime expiry;
    try {
      expiry = DateTime.parse(json['expiry_date'] as String);
    } catch (_) {
      expiry = DateTime.now().add(const Duration(days: 335));
    }

    return WorkerInsuranceModel(
      id: json['id'] as String? ?? '',
      workerId: json['worker_id'] as String? ?? '',
      providerName: json['provider_name'] as String? ?? 'National Insurance Co. / Union Group Policy',
      policyNumber: json['policy_number'] as String? ?? 'NIC-GRP-0000',
      coverageType: json['coverage_type'] as String? ?? 'Accidental & Health Insurance',
      coverageAmount: amt,
      startDate: start,
      expiryDate: expiry,
      status: status,
      verificationStatus: verStatus,
      adminRemarks: json['admin_remarks'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'worker_id': workerId,
    'provider_name': providerName,
    'policy_number': policyNumber,
    'coverage_type': coverageType,
    'coverage_amount': coverageAmount,
    'start_date': startDate.toIso8601String().split('T').first,
    'expiry_date': expiryDate.toIso8601String().split('T').first,
    'status': status.toDbString(),
    'verification_status': verificationStatus.toDbString(),
    if (adminRemarks != null) 'admin_remarks': adminRemarks,
  };
}
