# ShramSetu — Feature Connection Matrix

This matrix documents the end-to-end connectivity of every feature across UI, State, Repository, Service, Supabase, Realtime, Notifications, Web, and Mobile targets.

## Status Legend
- **VERIFIED**: End-to-end connected and functionally verified in code and tests.
- **CONNECTED**: Fully integrated in code across layers; mock/sandbox fallback available.
- **FALLBACK**: Platform-specific graceful degradation (e.g. web mock/js fallback).

---

## Complete Feature Matrix

| Feature | UI | State | Repository | Service | Supabase | Realtime | Notification | Web | Mobile | Tested |
|---|---|---|---|---|---|---|---|---|---|---|
| **Customer Auth (OTP)** | `CustomerLoginScreen` | `_isOtpSent`, `_isLoading` | `IAuthRepository` | `MockAuthService` / Supabase Auth | `auth.users` | N/A | SMS OTP via Fast2SMS / Mock | **VERIFIED** | **VERIFIED** | **VERIFIED** (Tests 1-4) |
| **Worker Auth (OTP)** | `WorkerLoginScreen` | `_isOtpSent`, `_isLoading` | `IAuthRepository` | `MockAuthService` / Supabase Auth | `auth.users` | N/A | SMS OTP via Fast2SMS / Mock | **VERIFIED** | **VERIFIED** | **VERIFIED** |
| **Admin Login** | `AdminLoginScreen` | `_isLoading`, `_errorMessage` | `IAuthRepository` | Supabase Password Auth | `auth.users` (`role='ADMIN'`) | N/A | N/A | **VERIFIED** | **VERIFIED** | **VERIFIED** |
| **Role Detection & Route Guards** | `SplashScreen`, `AppNavGuards` | Role State | `IUserRepository` | Auth Service | `public.users.role` | N/A | N/A | **VERIFIED** | **VERIFIED** | **VERIFIED** |
| **Customer Profile Onboarding** | `CustomerProfileOnboardingScreen` | Form State, `_isSaving` | `IUserRepository` | User Service | `public.users`, `public.addresses` | N/A | N/A | **VERIFIED** | **VERIFIED** | **VERIFIED** (Test 5) |
| **Service Categories Discovery** | `CustomerHomeScreen` | `_categories` | `ICustomerRepository` | Category Service | `public.services` | N/A | N/A | **VERIFIED** | **VERIFIED** | **VERIFIED** |
| **FairMatch Worker Ranking** | `WorkerDiscoveryScreen` | `_workers`, `_recommended` | `IFairMatchRepository` | `FairMatchService` & Engine | `rpc/fairmatch_v1_recommend` | N/A | N/A | **VERIFIED** | **VERIFIED** | **VERIFIED** (FairMatch Suite) |
| **Worker Profile View** | `WorkerProfileScreen` | `worker` | `ICustomerRepository` | Customer Service | `public.workers` | N/A | N/A | **VERIFIED** | **VERIFIED** | **VERIFIED** |
| **Address & Geolocation** | `MapLocationPickerScreen`, Home | `_latitude`, `_longitude` | `IUserRepository` | `LocationService` (Haversine) | `public.addresses` (PostGIS) | N/A | N/A | **VERIFIED** (HTML5 Geolocation) | **VERIFIED** (GPS) | **VERIFIED** |
| **Date & Time Slot Selection** | `BookingDateTimeScreen` | `selectedDate`, `selectedTime` | `bookingFlowState` | Booking Flow | N/A | N/A | N/A | **VERIFIED** | **VERIFIED** | **VERIFIED** |
| **Booking Creation & Checkout** | `BookingDetailsScreen` | `_isSubmitting`, `_pendingBookingId` | `ICustomerRepository` | Shared Store / Supabase | `public.bookings` | Event Emitted | Worker Push | **VERIFIED** | **VERIFIED** | **VERIFIED** |
| **Razorpay Payment Escrow** | `BookingDetailsScreen` | `_paymentMode` | `IPaymentRepository` | Payment Service | `public.payments` | State Update | Escrow Push | **VERIFIED** (Web Fallback) | **VERIFIED** (Razorpay SDK) | **VERIFIED** (Payment Suite) |
| **Escrow Status State Machine** | `BookingDetailsScreen`, Live Tracking | Escrow State | `IPaymentRepository` | Payment Service | `public.payments.escrow_status` | Realtime Broadcast | Worker Payment Push | **VERIFIED** | **VERIFIED** | **VERIFIED** (Idempotency Suite) |
| **Worker Job Dispatch & Notification** | `WorkerJobRequestsScreen` | `_jobsFuture`, `_jobsSub` | `IWorkerRepository` | Shared Store / Supabase Realtime | `public.bookings` | **VERIFIED** (CDC Broadcast) | `booking_requested` | **VERIFIED** | **VERIFIED** | **VERIFIED** |
| **Worker State Transition (Journey)** | `WorkerJobDetailScreen` | Job Step Timeline | `IWorkerRepository` | Shared Store / Supabase | `public.bookings.status` | **VERIFIED** (CDC Broadcast) | `booking_status` | **VERIFIED** | **VERIFIED** | **VERIFIED** |
| **Customer Live Tracking** | `CustomerLiveTrackingScreen` | `_bookingData`, `_bookingSub` | `ICustomerRepository` | Shared Store / Supabase Realtime | `public.bookings` | **VERIFIED** (Reactive stream) | Live push | **VERIFIED** | **VERIFIED** | **VERIFIED** |
| **Completion Sign-Off (OTP)** | `CustomerLiveTrackingScreen` / Worker | OTP State | `IWorkerRepository` / Payment | Validation Service | `public.bookings.completion_otp` | Event Emitted | Verified Push | **VERIFIED** | **VERIFIED** | **VERIFIED** |
| **Escrow Release to Worker** | `CustomerLiveTrackingScreen` | Auto-release trigger | `IPaymentRepository` | Edge Function `release-escrow` | `public.payments.escrow_status` | Event Emitted | Payout Push | **VERIFIED** | **VERIFIED** | **VERIFIED** |
| **Customer Review & Rating** | `ReviewRatingModal`, Bookings | Rating (1-5), Tags | `IReviewRepository` | Review Service | `public.reviews` | N/A | Worker Feedback Push | **VERIFIED** | **VERIFIED** | **VERIFIED** (Review Suite) |
| **Worker Earnings & Welfare** | `WorkerEarningsScreen` | `_workerFuture`, `_paymentsFuture` | `IWorkerRepository`, `IPaymentRepository` | Worker Service | `public.payments` (released) | Updated on Release | N/A | **VERIFIED** | **VERIFIED** | **VERIFIED** |
| **Worker KYC & Document Upload** | `WorkerKycScreen` | Document Upload State | `IStorageRepository`, `IWorkerRepository` | Storage Service | `storage.objects` (`worker-documents`) | N/A | Admin Verification Push | **VERIFIED** (File bytes) | **VERIFIED** (Native picker) | **VERIFIED** |
| **Admin Operations Dashboard** | `AdminDashboardScreen` | `_dataFuture`, `_bookingsSub` | `IAdminRepository` | Admin Service | `public.bookings`, `public.workers` | **VERIFIED** (CDC Broadcast) | N/A | **VERIFIED** | **VERIFIED** | **VERIFIED** |
| **Admin Worker Verification** | `AdminWorkersScreen` | Verification status | `IAdminRepository` | Governance Service | `public.workers.verification_status` | Realtime Update | Worker Approval Push | **VERIFIED** | **VERIFIED** | **VERIFIED** |
| **Admin AI Demand Forecasting** | `AdminDemandForecastScreen` | `_forecastFuture`, `_metricsFuture` | `IDemandForecastRepository` | `DemandForecastingEngine` (Holt-Winters) | `public.demand_forecasts` | N/A | N/A | **VERIFIED** | **VERIFIED** | **VERIFIED** (Forecast Suite) |
| **Admin Dispute Resolution** | `AdminComplaintsScreen` | `_complaints` | `IAdminRepository` | Dispute Service | `public.disputes` | N/A | Customer/Worker Push | **VERIFIED** | **VERIFIED** | **VERIFIED** |
