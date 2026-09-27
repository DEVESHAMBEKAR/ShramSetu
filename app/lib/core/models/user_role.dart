/// Centralized primary role representation for ShramSetu.
/// The backend (Supabase users.role) is the authoritative source of truth.
enum UserRole {
  customer,
  worker,
  admin;

  String toDbString() {
    switch (this) {
      case UserRole.customer:
        return 'CUSTOMER';
      case UserRole.worker:
        return 'WORKER';
      case UserRole.admin:
        return 'ADMIN';
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
      default:
        return null;
    }
  }

  bool get isCustomer => this == UserRole.customer;
  bool get isWorker => this == UserRole.worker;
  bool get isAdmin => this == UserRole.admin;

  String get displayName {
    switch (this) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.worker:
        return 'Worker Partner';
      case UserRole.admin:
        return 'Cooperative Administrator';
    }
  }
}
