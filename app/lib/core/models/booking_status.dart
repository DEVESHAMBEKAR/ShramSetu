enum BookingStatus {
  pending,
  accepted,
  onTheWay,
  arrived,
  inProgress,
  completed,
  rejected,
  cancelled;

  bool canTransitionTo(BookingStatus nextState) {
    switch (this) {
      case BookingStatus.pending:
        return nextState == BookingStatus.accepted ||
            nextState == BookingStatus.rejected ||
            nextState == BookingStatus.cancelled;
      case BookingStatus.accepted:
        return nextState == BookingStatus.onTheWay ||
            nextState == BookingStatus.cancelled;
      case BookingStatus.onTheWay:
        return nextState == BookingStatus.arrived;
      case BookingStatus.arrived:
        return nextState == BookingStatus.inProgress;
      case BookingStatus.inProgress:
        return nextState == BookingStatus.completed;
      case BookingStatus.completed:
      case BookingStatus.rejected:
      case BookingStatus.cancelled:
        return false;
    }
  }

  String get label {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.accepted:
        return 'Accepted';
      case BookingStatus.onTheWay:
        return 'On the way';
      case BookingStatus.arrived:
        return 'Arrived';
      case BookingStatus.inProgress:
        return 'In progress';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.rejected:
        return 'Rejected';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  String toDbString() => name;

  static BookingStatus fromDbString(String? val) {
    if (val == null) return BookingStatus.pending;
    final clean = val.trim().toLowerCase();
    switch (clean) {
      case 'accepted':
        return BookingStatus.accepted;
      case 'ontheway':
        return BookingStatus.onTheWay;
      case 'arrived':
        return BookingStatus.arrived;
      case 'inprogress':
        return BookingStatus.inProgress;
      case 'completed':
        return BookingStatus.completed;
      case 'rejected':
        return BookingStatus.rejected;
      case 'cancelled':
      case 'canceled':
        return BookingStatus.cancelled;
      case 'pending':
      default:
        return BookingStatus.pending;
    }
  }
}
