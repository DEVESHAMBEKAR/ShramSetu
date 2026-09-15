# Booking State Machine

## Overview
The `BookingStatus` enum represents the single source of truth for the lifecycle of a job/booking within the ShramSetu application. It applies uniformly to Customers, Workers, and Admins.

## Defined States
```dart
enum BookingStatus {
  pending,      // Customer requested, waiting for worker
  accepted,     // Worker accepted the job
  onTheWay,     // Worker is travelling to the location
  arrived,      // Worker has arrived at the location
  inProgress,   // Work has started (OTP verified)
  completed,    // Work is finished and paid
  rejected,     // Worker declined the job
  cancelled;    // Customer or Admin cancelled the job
}
```

## Valid Transitions
The following transitions are enforced through the `canTransitionTo()` method in `BookingStatus`:

- `pending` -> `accepted` | `rejected` | `cancelled`
- `accepted` -> `onTheWay` | `cancelled`
- `onTheWay` -> `arrived`
- `arrived` -> `inProgress`
- `inProgress` -> `completed`

### Terminal States
Once a booking enters one of the following states, it cannot transition further:
- `completed`
- `rejected`
- `cancelled`

## Module Integration
- **Customer UI**: Views status updates from `pending` -> `accepted` -> `onTheWay` -> `arrived` -> `inProgress` -> `completed`.
- **Worker UI**: Actively drives the state machine forward (Accept -> Travel -> Arrive -> Start -> Complete).
- **Admin UI**: Monitors states across all active jobs, can forcefully cancel or complete if necessary for dispute resolution.
