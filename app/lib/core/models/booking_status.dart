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
}
