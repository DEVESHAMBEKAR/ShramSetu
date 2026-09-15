# Step 5: Worker Profile and Booking Flow

This document outlines the implementation plan for the Worker Profile and Booking Flow based on the Stitch UI prototype.

## Proposed Changes

### Data Models
- **[MODIFY]** `lib/features/customer/data/models/customer_models.dart`: Expand the `Worker` model to include details found in the Profile screen (e.g., federation ID, bio, tools, insurance bond, languages).
- **[NEW]** `lib/features/booking/data/models/booking_models.dart`: `Booking` model (`id`, `customerId`, `workerId`, `serviceId`, `serviceName`, `workerName`, `scheduledDate`, `scheduledTime`, `address`, `amount`, `status`). Booking status enum: `PENDING`, `CONFIRMED`, `COMPLETED`, `CANCELLED`.

### State Management
- **[NEW]** `lib/features/booking/presentation/providers/booking_flow_state.dart`: Create a temporary in-memory state object to hold `selectedService`, `selectedWorker`, `selectedDate`, `selectedTime`, `selectedAddress` as the user navigates the booking flow.

### Screens
- **[NEW]** `lib/features/customer/presentation/screens/worker_profile_screen.dart`: The detail view replicating `sharmsetu_worker_profile_rahul_patil`.
  - Profile header with badges
  - Micro-interaction tabs (About, Services & Pricing, Reviews, Tools)
  - Bottom sticky action bar with "Book Now"
- **[NEW]** `lib/features/booking/presentation/screens/booking_date_time_screen.dart`: A new UI using the existing design system for selecting a date and time slot.
  - Mock availability (e.g., Today, Tomorrow)
- **[NEW]** `lib/features/booking/presentation/screens/booking_details_screen.dart`: Replicates `sharmsetu_booking_escrow_payment`.
  - Booking Summary, Cooperative Escrow Guarantee, Pricing Breakdown, Payment Modes, Sticky Pay Action Bar.
- **[NEW]** `lib/features/booking/presentation/screens/booking_confirmation_screen.dart`: A minimal success screen showing confirmation details and a button to return home.

### Navigation Updates
- Tapping a worker on `WorkerDiscoveryScreen` → `WorkerProfileScreen`.
- Tapping "Book Now" on `WorkerProfileScreen` → `BookingDateTimeScreen`.
- Confirming date/time → `BookingDetailsScreen`.
- Confirming payment/booking → `BookingConfirmationScreen` → `CustomerHomeScreen`.

## Verification Plan
- Unit test booking model and flow state.
- Visually verify `WorkerProfileScreen` against the prototype.
- Ensure the End-to-End flow works without Supabase or real backend.
- Run `flutter analyze` and `flutter test`.
