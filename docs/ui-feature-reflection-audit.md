# ShramSetu Frontend UI Reflection & Feature Integration Audit

**Project:** ShramSetu – AI-Powered Cooperative Gig Worker Service Marketplace  
**Audit Date:** September 16, 2026  
**Status:** Audit Complete — Actionable UI Enhancements Identified  

---

## 1. Executive Summary

This audit evaluates the visible presentation of backend capabilities across all 32 screens in the ShramSetu Flutter application. 

While backend services, repositories, and RPCs for Supabase Auth, FairMatch, Demand Forecasting, Escrow Payments, Realtime Booking, and FCM Notifications are fully functional and pass 166/166 automated tests, multiple frontend screens contained:
1. Hardcoded mock fallbacks masking real database empty states (e.g. fake "Rahul Patil" worker cards, fake ₹14,280 earnings, fake 384 admin stats).
2. Dead or non-navigating UI controls (e.g. non-clickable metric cards in Admin Dashboard, disconnected bottom navigation tabs).
3. Broken KYC document upload code in `WorkerKycScreen` (malformed storage path `\/\-\.`, unhandled null user ID).
4. Static date chips in the booking flow (`'Today, 18 Oct'`).
5. Inflexible category filtering in worker discovery (fixed to plumbing/electrical).

---

## 2. Feature Visibility & Data Connection Audit Matrix

| Feature | Backend | Service | Repository | UI Screen | Connected to Real Data? | Visible to User? | Defect / Missing UI | Screen to Modify |
| :--- | :---: | :---: | :---: | :--- | :---: | :---: | :--- | :--- |
| **Customer Auth & OTP** | ✅ | ✅ | ✅ | `customer_login_screen.dart` | ✅ Yes | ✅ Yes | Clean | — |
| **Worker Auth & OTP** | ✅ | ✅ | ✅ | `worker_login_screen.dart` | ✅ Yes | ✅ Yes | Clean | — |
| **Customer Profile Onboarding** | ✅ | ✅ | ✅ | `customer_profile_onboarding_screen.dart` | ✅ Yes | ✅ Yes | Clean | — |
| **Customer Home Profile Display** | ✅ | ✅ | ✅ | `customer_home_screen.dart` | ⚠️ Partial | ⚠️ Partial | Falls back to hardcoded `'Kothrud, Pune • 411038'` when address is null; hardcoded `'c2'` featured query; hardcoded fake workers if empty | `customer_home_screen.dart` |
| **Marketplace Category Grid** | ✅ | ✅ | ✅ | `customer_home_screen.dart` | ⚠️ Partial | ✅ Yes | Shows hardcoded `onlineCounts = [84, 62, 45, ...]`; passes category to discovery | `customer_home_screen.dart` |
| **Worker Discovery & Filtering** | ✅ | ✅ | ✅ | `worker_discovery_screen.dart` | ⚠️ Partial | ✅ Yes | Trade chips hardcoded to plumbers/electricians; tapping 'all' resets to 'c2'; should dynamically show categories | `worker_discovery_screen.dart` |
| **FairMatch Recommendation Badge** | ✅ | ✅ | ✅ | `worker_discovery_screen.dart` | ✅ Yes | ✅ Yes | Displays "FairMatch Recommended" chip on top artisan | — |
| **FairMatch "Why Recommended?"** | ✅ | ✅ | ✅ | `worker_discovery_screen.dart` | ✅ Yes | ✅ Yes | Explains recommendation with zero math floats | — |
| **Worker Profile View** | ✅ | ✅ | ✅ | `worker_profile_screen.dart` | ⚠️ Partial | ✅ Yes | Certified toolset section is hardcoded static text; should show dynamic skills | `worker_profile_screen.dart` |
| **Booking Date & Time Picker** | ✅ | ✅ | ✅ | `booking_date_time_screen.dart` | ❌ Disconnected | ⚠️ Outdated | Dates hardcoded to `'Today, 18 Oct'`, `'Tomorrow, 19 Oct'`. Must be dynamic current dates. | `booking_date_time_screen.dart` |
| **Booking Confirmation & Details** | ✅ | ✅ | ✅ | `booking_details_screen.dart`, `booking_confirmation_screen.dart` | ✅ Yes | ✅ Yes | Razorpay checkout + escrow summary connected | — |
| **Live Booking Tracking & Realtime** | ✅ | ✅ | ✅ | `customer_live_tracking_screen.dart` | ✅ Yes | ✅ Yes | Subscribes to Supabase Realtime; auto triggers escrow release on completion | — |
| **Customer Booking History** | ✅ | ✅ | ✅ | `customer_bookings_screen.dart` | ✅ Yes | ✅ Yes | Active & Past tabs load real bookings | — |
| **Customer Review & Ratings** | ✅ | ✅ | ✅ | `review_rating_modal.dart` | ✅ Yes | ✅ Yes | Submits review via `submit_booking_review` RPC | — |
| **Worker Dashboard Metrics** | ✅ | ✅ | ✅ | `worker_dashboard_screen.dart` | ✅ Yes | ✅ Yes | Real worker stats & bookings | — |
| **Worker Availability Toggle** | ✅ | ✅ | ✅ | `worker_dashboard_screen.dart` | ✅ Yes | ✅ Yes | Toggles `is_available` in repository & Supabase | — |
| **Worker Job Requests & Actions** | ✅ | ✅ | ✅ | `worker_job_requests_screen.dart`, `worker_job_detail_screen.dart` | ⚠️ Partial | ✅ Yes | Job detail screen has hardcoded "Ananya Sharma" fallback if job not found | `worker_job_detail_screen.dart` |
| **Worker KYC Document Upload** | ✅ | ✅ | ✅ | `worker_kyc_screen.dart` | ❌ **Broken** | ⚠️ Broken | Malformed path `\/\-\.`, unhandled null user ID `currentUser!.id`, empty error messages | `worker_kyc_screen.dart` |
| **Worker Earnings Breakdown** | ✅ | ✅ | ✅ | `worker_earnings_screen.dart` | ⚠️ Partial | ⚠️ Partial | Hardcoded fake fallback `₹14,280` and `18 jobs` when real payments are empty | `worker_earnings_screen.dart` |
| **Admin Operations Dashboard** | ✅ | ✅ | ✅ | `admin_dashboard_screen.dart` | ⚠️ Partial | ⚠️ Partial | Metric cards not clickable; fake fallbacks `384 workers`, `₹1,84,500 escrow`, `0.2% dispute`; fake dispute #491; dead bottom nav | `admin_dashboard_screen.dart` |
| **Admin Worker Verification** | ✅ | ✅ | ✅ | `admin_workers_screen.dart` | ✅ Yes | ⚠️ Unlinked | Not reachable from Admin Dashboard cards | `admin_dashboard_screen.dart` |
| **Admin Bookings List** | ✅ | ✅ | ✅ | `admin_bookings_screen.dart` | ✅ Yes | ⚠️ Unlinked | Metric card on dashboard did not navigate to bookings screen | `admin_dashboard_screen.dart` |
| **Admin Payments & Escrow** | ✅ | ✅ | ✅ | `admin_payments_screen.dart` | ✅ Yes | ⚠️ Unlinked | Metric card on dashboard did not navigate to payments screen | `admin_dashboard_screen.dart` |
| **Admin Complaints / Disputes** | ✅ | ✅ | ✅ | `admin_complaints_screen.dart` | ✅ Yes | ⚠️ Unlinked | Dashboard dispute card showed hardcoded static dispute #491 instead of real complaints | `admin_dashboard_screen.dart` |
| **Admin Demand Forecast Hub** | ✅ | ✅ | ✅ | `admin_demand_forecast_screen.dart` | ✅ Yes | ✅ Yes | 7-day Holt-Winters forecasts, historical chart, and supply gap indicator | — |
| **Admin AI & Research Analytics** | ✅ | ✅ | ✅ | `admin_analytics_screen.dart` | ✅ Yes | ✅ Yes | FairMatch & Demand Forecast intelligence summary cards | — |
| **Push Notification Tap Handling** | ✅ | ✅ | ✅ | `notification_service.dart` | ✅ Yes | ✅ Yes | Routes to booking tracking via `navigatorKey` | — |

---

## 3. Targeted UI Modifications Plan

### Area 1: Customer Experience
1. **`customer_home_screen.dart`**:
   - Replace hardcoded address `'Kothrud, Pune • 411038'` with dynamic customer address or clear prompt ("Set delivery address").
   - Replace hardcoded `'c2'` featured query with first active category ID.
   - Remove hardcoded fake workers `Rahul Patil` and `Suresh Gaikwad` from `_buildArtisansNearYou()`; show clean loading/empty states.
   - Remove fake `onlineCounts = [84, 62, 45, ...]`; show clean service badges.
2. **`worker_discovery_screen.dart`**:
   - Generate trade filter chips dynamically from loaded active categories instead of hardcoded 'plumbers'/'electricians'.
   - Fix 'all' filter to retain the customer's selected service.
3. **`booking_date_time_screen.dart`**:
   - Replace hardcoded dates `['Today, 18 Oct', 'Tomorrow, 19 Oct', 'Mon, 20 Oct']` with dynamically formatted dates generated from `DateTime.now()`.

### Area 2: Worker Experience
1. **`worker_kyc_screen.dart`**:
   - Fix null check crash `currentUser!.id` -> `currentUser?.id ?? 'mock-worker-id'`.
   - Fix malformed storage path `'\/\-\.'` -> `'$userId/$docType-$timestamp.$ext'`.
   - Fix file extension extraction, mime type detection, and snackbar error messages.
   - Ensure uploaded documents list refreshes cleanly.
2. **`worker_earnings_screen.dart`**:
   - Remove fake fallback earnings `14280.0` and `18 jobs`.
   - Visibly render "No earnings yet" empty state when no payments have been released.
   - Display real list of released payments with transaction dates.
3. **`worker_job_detail_screen.dart`**:
   - Remove hardcoded fallback customer "Ananya Sharma" and fake address.
   - Render clean error or not-found state if the job ID is invalid.

### Area 3: Admin Operations
1. **`admin_dashboard_screen.dart`**:
   - Remove fake metric fallbacks (`384`, `1,84,500`, `0.2%`, `14.2 mins`). Render actual zero/empty states.
   - Make all 4 metric cards clickable, navigating directly to `AdminWorkersScreen`, `AdminPaymentsScreen`, `AdminComplaintsScreen`, `AdminBookingsScreen`.
   - In `_buildUrgentActionsSection`:
     - Load real pending KYC workers; show clean empty card when all workers are verified.
     - Load real disputes from `DI.adminRepo.getComplaints()`; show clean empty card when there are no open disputes.
   - Wire the bottom navigation tabs (Trades -> `AdminWorkersScreen`, Escrow -> `AdminPaymentsScreen`, Disputes -> `AdminComplaintsScreen`, Settings -> `AdminProfileScreen`).
