# Backend Integration Map

Based on the UI elements, this is the mapping of planned backend entities to the screens that require them.

## Entity Mapping

### `users` (Auth & Profile)
- Required by: Customer Login, Onboarding, Worker KYC, Admin Console.

### `workers`
- Required by: Worker Dashboard, Worker Profile, Customer Home, Service Discovery, Admin Console, Active Bookings, Payment Escrow.

### `services`
- Required by: Customer Home, Service Discovery, Admin Console.

### `skills` & `worker_skills`
- Required by: Worker Profile, Worker KYC, Service Discovery.

### `worker_verification` (KYC/Guild)
- Required by: Worker KYC, Admin Console, Worker Profile, Escrow Payment.

### `availability`
- Required by: Customer Home (to show active/available workers), Service Discovery.

### `addresses` (Locations)
- Required by: Customer Home, Customer Tracking (Live GPS).

### `bookings`
- Required by: Customer Active Orders, Customer Live Tracking, Worker Job Detail, Admin Console, Payment Escrow, Rating/Review.

### `payments` (Escrow/Wallet)
- Required by: Booking Escrow Payment, Worker Earnings Welfare, Admin Console.

### `reviews`
- Required by: Customer Rating Review, Worker Profile.

### `notifications`
- Required by: Header notification bells on Customer Home, Worker Dashboard.

## External API Integration Points

1. **Supabase Auth**: Replaces static OTP flow in `sharmsetu_customer_mobile_otp_login`.
2. **Supabase PostgreSQL**: Replaces all mock data (Workers, Bookings, Users).
3. **Supabase Storage**: Hosts profile images, KYC documents (currently using Google placeholders).
4. **Supabase Realtime**: Powers live status updates in `sharmsetu_customer_live_booking_tracking`.
5. **Google Maps/location**: Replaces static map images in `sharmsetu_customer_live_booking_tracking` and distance strings.
6. **Razorpay Test Mode**: Connects to the "Pay via UPI" button in `sharmsetu_booking_escrow_payment`.
7. **Firebase Cloud Messaging**: Push notifications for job requests and tracking.
8. **FairMatch AI API**: Used in `sharmsetu_service_discovery_workers` to order the worker list.
9. **Demand Forecasting API**: Used in `sharmsetu_worker_home_dashboard` to show high-demand areas.
