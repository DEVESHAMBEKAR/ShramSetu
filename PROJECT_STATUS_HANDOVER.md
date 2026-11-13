# 📋 ShramSetu — Project Handover & Status Log

### Project Summary
**ShramSetu** is an AI-powered, cooperative-first civic service marketplace built with Flutter and Supabase in partnership with the Pune District Labour Cooperative Federation. It connects local trade artisans (electricians, plumbers, carpenters, etc.) with residential and commercial customers using zero-commission escrow payouts, explainable AI matching (FairMatch), and federation admin governance.

---

## 🛠️ Tech Stack & Architecture

- **Frontend:** Flutter (Web & Android APK, Dart 3.x)
- **Backend / Database:** Supabase (PostgreSQL 15, Row Level Security, Realtime Channels, Edge Functions, Storage Buckets)
- **Architecture Pattern:** Clean Separation (`Presentation` ➔ `Repository / Service` ➔ `Data Sources / Supabase Client`)
- **Visual Truth:** Stitch UI specification & design tokens; Urban Company tier polish
- **Current Quality Status:** **115 automated unit and widget tests passing** (`flutter test test/unit/`) with **0 analyzer compilation errors** (`flutter analyze`).

---

## ✅ Completed Milestones & Feature Log

### 1. Multi-Role Authentication & Access Control
- **Strict Role Separation:**
  - `CUSTOMER`: Service discovery, cart checkout, saved delivery addresses, live tracking, OTP escrow release.
  - `WORKER`: Trade assignment acceptance, real earnings, KYC document upload, status tracking.
  - `ADMIN` & `FEDERATION_ADMIN`: Cooperative desk reviewing artisans, document inspection, district operations.
  - `SUPER_ADMIN`: Central federation provisioning, cross-state cooperative management, audit log inspection.
- **Mobile OTP Authentication:**
  - 6-digit phone OTP with rate limiting, test numbers, and authoritative cross-role gates (prevents workers from logging into customer portal and vice versa).
- **Google OAuth Sign-In (Customer & Worker):**
  - Brand-compliant `GoogleSignInButton` with custom vector `GoogleLogoPainter`.
  - `IAuthRepository.signInWithGoogle({required String role})` implemented across Supabase and Mock repositories.
  - Dynamic web origin redirect (`Uri.base.origin`) preventing default `localhost:3000` port mismatches.
  - Role-intent preservation (`?auth_role=CUSTOMER` / `?auth_role=WORKER`) across OAuth redirects to prevent accidental admin privilege escalation.
  - Provider preflight check with interactive setup modal and 1-tap demo Google profile fallback.

### 2. Multi-Federation & Super Admin Governance
- **Super Admin Management Console:**
  - Complete layout (`SuperAdminMainLayout`) with navigation to Federations, Federation Admins, Audit Logs, and Analytics.
- **State & District Filtering and Sorting:**
  - Dynamic Indian states and districts dropdowns via `IndiaGeographyService`.
  - Real-time search by cooperative name, district, or registration number.
  - Multi-attribute sorting (Alphabetical, Worker Count, Active Bookings, Created Date).
- **Federation Isolation & Scoping:**
  - Row Level Security migrations (`019`–`026`) enforcing strict cooperative isolation: Federation admins can only view and manage workers and bookings within their assigned cooperative UUID.

### 3. Worker Registration & 20-Field Verification Gate
- **Streamlined 20-Field KYC Form:**
  - Basic Info: Full Name, Mobile, Profile Photo, DOB, Gender, Current Address, City, District, PIN Code.
  - Trade & Work Info: Category/Trade, Primary Skill, Skill Level, Experience Years, Service Area, Availability.
  - Verification & Cooperative: Govt KYC ID, Trade Certificate, Federation Name, Cooperative Membership ID, Declaration.
- **Strict Verification Gate:**
  - Newly registered workers cannot receive jobs or access the worker dashboard until approved by a Federation Administrator.
  - Held on the `WorkerUnderVerificationScreen` with real-time status updates and prominent Logout.
- **Rejection Handling & Reapplication:**
  - Transparent reason display with one-tap **Correct & Reapply** pre-filling existing fields.

### 4. Admin Federation Verification Console
- **6-State Status Lifecycle:**
  - `PENDING` ➔ `UNDER_REVIEW` ➔ `CHANGES_REQUIRED` ➔ `APPROVED` ➔ `REJECTED` ➔ `SUSPENDED`.
- **Document Inspection:**
  - Secure document viewer for identity cards and trade certificates via Supabase signed URLs.
  - Granular document actions: **Approve** or **Flag** with mandatory reason logging.

### 5. Customer Delivery Addresses & Federation Assignment
- **User-Scoped Address CRUD:**
  - Integrated with Supabase `addresses` table (Add, Edit, Delete, Set Default).
  - Strict customer-level data isolation preventing cross-account data leakage.
- **Dynamic Cooperative Routing:**
  - `assignCustomerFederation` automatically maps customer location (PIN code, district, city) to the nearest active cooperative federation.
  - Graceful `AreaNotServiceableScreen` fallback when no cooperative exists in the user's district.

### 6. Real Data Migration & Worker Dashboard Polish
- **Elimination of Mock/Dummy Entries:**
  - Worker dashboard displays real dynamic jobs and verified zero-state (no hardcoded ₹14,280 or dummy completed jobs).
  - Real daily income chart, union welfare cess calculation, and released escrow earnings.

### 7. Explainable AI Services
- **FairMatch Engine (`FairMatchService`):**
  - Transparent algorithmic distribution of jobs balancing worker proximity, skill rating, and union equity.
- **Demand Forecasting (`DemandForecastService`):**
  - District-level workload forecasting for seasonal labour demand without exposing customer PII.

---

## 📌 Recent Git Commit Log

```
* 672747d - feat: complete multi-federation, service area discovery, emergency sos, digital invoice, and welfare insurance
* a23330a - fix(customer): strictly isolate saved addresses to the specific logged-in customer and link to checkout
* 6d4a846 - feat(customer): replace hardcoded dummy saved addresses with real database CRUD - load from addresses table, add new, set default, and delete
* 3cd37c7 - feat(worker): show rejection reason and add Correct & Reapply button on rejected verification screen
* d7e2d8b - fix(worker): rejection status not propagating to worker console - map INACTIVE->rejected, fix terminal state polling, refresh docs on check
* 494bc32 - feat(worker): add prominent Logout button with confirmation dialog on verification waiting screen
* eb683ac - feat(admin): document inspection - view signed URL, approve, and flag individual worker documents
* 42c448f - fix(worker): resolve DropdownMenuItem value mismatch assertion on registration screen
* 4e20370 - fix(admin): resolve reviewed_by schema cache error in Supabase worker approval fallback
* 921d875 - feat(verification): implement 20-field worker registration, 6-state admin federation verification, and customer order management
* 963d0a7 - feat(worker): enforce registration and admin federation document verification gate before granting app access
* 9ce8b17 - fix(profile): display real database user names across customer, worker, and admin portals
```

---

### 8. Master UI/UX Redesign, Accessible Status Badges & Unified State Views
- **Application Compilation & Restart Recovery:**
  - Resolved Flutter web compilation blocker caused by parameter mismatches in `customer_home_screen.dart`.
  - Application builds and runs cleanly with 0 compilation errors across web and mobile.
- **Canonical Design System Tokens & Complete Palette Propagation:**
  - Standardized Deep Teal (`#0D5C5B`) for authoritative primary CTAs, Soft White (`#F8F9FA`) for clean canvas comfort, Warm Amber (`#D97706`) for highlights and escrow milestones, and Green (`#16A34A`) for verified credentials.
  - Fully wired `AppColors.primary`, `AppColors.primaryContainer`, `AppColors.secondary`, `AppColors.secondaryContainer`, `AppColors.background`, and `AppColors.surface` to the canonical tokens so that all screens, avatars, badges, sidebars, and appbars across Customer, Worker, and Admin interfaces immediately inherit the new palette.
- **Accessible Dual-Signifier `BookingStatusBadge`:**
  - Strictly adheres to WCAG 1.4.1 (never relying on color alone): pairs dedicated semantic icons, high-contrast localized text labels (EN, MR, HI), and enclosing border rings across all lifecycle states (`REQUESTED`, `ACCEPTED`, `EN_ROUTE`, `ARRIVED`, `IN_PROGRESS`, `COMPLETED`, `REJECTED`, `CANCELLED`).
- **Standardized Data State Matrix (`AppLoadingView`, `AppEmptyView`, `AppErrorView`, `AppOfflineView`):**
  - Integrated across Customer Home, Discovery, Live Tracking, Worker Dashboard, Worker Job Detail, Verification Waiting, and Federation Admin Console.
- **Responsive Multi-Role Layout:**
  - Desktop sidebar with smooth collapse animation (76px icon rail / 260px expanded navigation) and mobile bottom navigation bar, harmonized with Deep Teal dark tone and Warm Amber accents.
- **Document Verification Lifecycle Controls:**
  - On the Federation Admin Worker Verification screen, when a document is in `PENDING` state, reviewers see `[ View ]`, `[ Approve ]`, and `[ Flag Queries ]`.
  - Once a document is `APPROVED`, the `[ Approve ]` button automatically hides, and is replaced by `[ Resubmit ]` alongside `[ Flag Queries ]`, allowing administrators to demand fresh document re-uploads or raise queries even on previously accepted records without cluttering the UI.
- **Test Quality:**
### 9. Master Booking Pipeline & Schema Harmonization
- **PostgreSQL Column & Join Fixes:**
  - Resolved fatal schema mismatch in `SupabaseWorkerRepository.getJobRequests()` where non-existent column `amount` was queried instead of `base_amount, labor_allowance`.
  - Resolved fatal column query in `SupabaseWorkerRepository.updateBookingStatus()` where non-existent column `service_name` was queried directly on `bookings` instead of using the relation `services!service_id(name)`.
- **Customer Booking Creation Robustness:**
  - Hardened `SupabaseCustomerRepository.createBooking()` to validate and normalize `workerId`, `serviceId`, and `addressId`. If mock IDs (`w1`, `addr_1`) or non-existent UUIDs are passed, gracefully resolves to valid foreign keys or null (as `worker_id` is nullable in schema), preventing PostgreSQL foreign key / UUID syntax exceptions.
  - Automatically synchronizes newly created bookings with `SharedBookingStore` for instant reactivity across customer, worker, and admin screens.
- **Worker Job Requests & Lifecycle Transitions:**
  - Added robust multi-tier fallback to `getWorkerBookings()` and `getJobRequests()`: queries joined relations (`users`, `services`, `addresses`), and if any relation is blocked or null, seamlessly recovers through simplified queries or local caching.
  - Hardened worker action buttons in `WorkerDashboardScreen` and `WorkerJobDetailScreen` with proper `async/await`, error catching, and user feedback via SnackBars.
  - Fixed `RangeError: -1` in `SharedBookingStore.updateBookingStatus()` when transitioning newly created or unindexed bookings.
- **Database RLS Policies (Migration 028):**
  - Added `028_fix_booking_and_verification_rls.sql` and updated master setup script:
    - Allows workers to read `users` profiles (full name, phone) of customers with active bookings assigned to them.
    - Allows all admin tiers (`ADMIN`, `SUPER_ADMIN`, `FEDERATION_ADMIN`) to view all user profiles and delivery addresses.
    - Allows all admin tiers to insert and view `worker_verification_history` and `worker_verification_documents`.
- **Test Quality:**
  - **119 automated unit and widget tests passing** (`flutter test test/unit/`) with **0 analyzer compilation errors** (`flutter analyze`).
  - Added dedicated test suite `booking_execution_and_repair_test.dart` verifying the full booking lifecycle.

### 10. End-to-End Area Dispatch, Dual Payment (Cash & Razorpay), and Delivery-Style Map Tracking
- **Area-Based Tariff Booking:**
  - Customer selects trade service (e.g. Plumber) at the decided cooperative rate for their ward/area.
  - FairMatch AI system searches for artisans within a **strict 3.5 km operational radius** (`FairMatchConfig.operationalRadiusKm = 3.5`).
- **FairMatch AI Proximity & Dispatch:**
  - Job requests dispatched to top-ranked artisans with all essential details shared (customer name, contact, location, service, tariff, labor allowance, notes).
  - Multi-factor scoring transparently prioritizes proximity inside the 3.5 km local ward corridor.
- **Worker Acceptance & OTP Generation:**
  - When worker accepts the booking, a random 4-digit verification OTP code is generated and displayed on the Customer console.
  - Worker must validate this 4-digit OTP code before completing the service.
- **Dual Payment Modes (Razorpay & Cash):**
  - **At Checkout:** Customer can choose between **Razorpay (Online Escrow/UPI)** and **Cash (Pay on Service to Partner)**. Cash bookings bypass online gateway redirection.
  - **Before Completion:** Worker console enforces cash collection confirmation if Cash mode is selected, or validates escrow status if Razorpay was chosen.
  - **Flexible In-Flight Switching:** Customer can seamlessly switch a Cash order to Razorpay online escrow at any time before service completion directly from the live tracking screen.
- **Delivery-Style Live Map Tracking:**
  - Dynamic live tracking HUD displays stage updates (`accepted` ➔ `onTheWay` ➔ `arrived` ➔ `inProgress` ➔ `completed`) with worker location, route polyline, and arrival ETA.
  - Vector map canvas visually highlights the 3.5 km cooperative ward perimeter, transit arterial corridors, and real-time artisan progress.
- **Database Schema & Migrations:**
  - Created `029_booking_payment_and_dispatch.sql` and updated `master_migration_and_admin_setup.sql` with `payment_method TEXT DEFAULT 'RAZORPAY'` and 3.5 km radius normalization in `fairmatch_recommend_workers`.

---

## 🚀 Future Roadmap & Next Steps

1. **Production Escrow Webhooks:**
   - Deploy Supabase Edge Functions for Razorpay webhook verification (`payment.captured`, `refund.processed`).
2. **Artisan Bank Account Payouts (UPI / IMPS):**
   - Connect payout transfer APIs (RazorpayX or Cashfree) upon customer OTP escrow release.
3. **Push Notifications:**
   - Configure Firebase Cloud Messaging (FCM) credentials for live job dispatch alerts.
4. **In-App Messaging:**
   - Worker-to-customer chat channel over Supabase Realtime channels.

