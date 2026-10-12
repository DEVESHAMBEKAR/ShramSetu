/// Centralized primary role representation for ShramSetu.
/// The backend (Supabase users.role) is the authoritative source of truth.
enum UserRole {
  customer,
  worker,
  admin,
  superAdmin,
  federationAdmin;

  String toDbString() {
    switch (this) {
      case UserRole.customer:
        return 'CUSTOMER';
      case UserRole.worker:
        return 'WORKER';
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.superAdmin:
        return 'SUPER_ADMIN';
      case UserRole.federationAdmin:
        return 'FEDERATION_ADMIN';
    }
  }

  static UserRole? fromString(String? val) {
    if (val == null) return null;
    final clean = val.trim().toUpperCase();
    switch (clean) {
      case 'CUSTOMER':
        return UserRole.customer;
      case 'WORKER':
        return UserRole.worker;
      case 'ADMIN':
        return UserRole.admin;
      case 'SUPER_ADMIN':
        return UserRole.superAdmin;
      case 'FEDERATION_ADMIN':
        return UserRole.federationAdmin;
      default:
        return null;
    }
  }

  bool get isCustomer => this == UserRole.customer;
  bool get isWorker => this == UserRole.worker;
  bool get isAdmin => this == UserRole.admin || this == UserRole.superAdmin || this == UserRole.federationAdmin;
  bool get isSuperAdmin => this == UserRole.superAdmin;
  bool get isFederationAdmin => this == UserRole.federationAdmin;

  String get displayName {
    switch (this) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.worker:
        return 'Worker Partner';
      case UserRole.admin:
        return 'Cooperative Administrator';
      case UserRole.superAdmin:
        return 'Super Administrator';
      case UserRole.federationAdmin:
        return 'Federation Administrator';
    }
  }
}
