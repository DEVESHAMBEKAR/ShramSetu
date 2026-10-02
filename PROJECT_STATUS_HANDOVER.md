# 📋 ShramSetu — Project Handover & Status Log

### Project Summary
**ShramSetu** is an AI-powered, cooperative-first service marketplace built with Flutter and Supabase in partnership with the Pune District Labour Cooperative Federation. It connects local trade artisans (electricians, plumbers, carpenters, etc.) with residential and commercial customers using zero-commission escrow payouts, explainable AI matching (FairMatch), and federation admin governance.

---

## 🛠️ Tech Stack & Architecture

- **Frontend:** Flutter (Web & Android APK, Dart)
- **Backend / Database:** Supabase (PostgreSQL, Row Level Security, Realtime Channels, Edge Functions, Storage Buckets)
- **Architecture Pattern:** Clean Separation (`Presentation` ➔ `Repository / Service` ➔ `Data Sources / Supabase Client`)
- **Visual Truth:** Stitch UI specification & design tokens; Urban Company tier polish
- **Current Quality Status:** **201 / 201 automated tests passing** (`flutter test`)

---

## ✅ What Has Been Completed

### 1. Database & Security Architecture (Supabase)
- **16 Migrations Applied:**
  - Tables: `users`, `workers`, `worker_verification`, `worker_verification_documents`, `addresses`, `bookings`, `payments`, `federations`, `demand_forecasts`, and audit logs.
- **Supabase Row Level Security (RLS):**
  - Customer data and addresses are restricted to `auth.uid() = user_id`.
  - Worker private records and document files are visible only to the worker and federation admins.
- **Storage Buckets:**
  - `worker-documents` bucket configured with 1-hour signed URLs for secure KYC document inspection.

### 2. Multi-Role Authentication & Access Control
- **Strict 3-Role Separation:**
  - `CUSTOMER`: Book services, manage delivery addresses, live job tracking, OTP escrow release.
  - `WORKER`: Accept assignments, view payouts, advance job states, complete KYC registration.
  - `ADMIN`: Federation desk managing worker approvals, KYC document verification, dispute resolution.
- **Mobile OTP Verification:**
  - 6-digit phone OTP authentication with rate limiting and cross-role protection (prevents an artisan from signing into the customer portal and vice versa).
- **Admin Authentication:**
  - Secure credential login with self-healing public user record sync.

### 3. Worker Registration & 20-Field Verification Gate
- **Streamlined 20-Field KYC Form:**
  - Basic Info: Full Name, Mobile, Profile Photo, DOB, Gender, Current Address, City, District, PIN Code.
  - Trade & Work Info: Category/Trade, Primary Skill, Skill Level, Experience Years, Service Area, Availability.
  - Verification & Cooperative: Govt KYC ID, Trade Certificate, Federation Name, Cooperative Membership ID, Declaration.
- **Strict Verification Gate:**
  - Newly registered workers cannot receive jobs or access the worker dashboard until approved by a Federation Administrator.
  - Held on the `WorkerUnderVerificationScreen` with real-time status updates.

### 4. Admin Federation Verification Console
- **6-State Status Lifecycle:**
  - `PENDING` ➔ `UNDER_REVIEW` ➔ `CHANGES_REQUIRED` ➔ `APPROVED` ➔ `REJECTED` ➔ `SUSPENDED`.
- **Document Inspection:**
  - Admins can view uploaded identity documents and certificates via secure signed URLs.
  - Individual document actions: **Approve** or **Flag** (with mandatory reason).
- **Worker Actions:**
  - Start Review, Approve Worker, Request Changes (with reason), Reject (mandatory reason), and Suspend.
  - Complete verification audit history preserved for each action.

### 5. Rejection Handling & Reapplication
- **Admin Reason Transparency:**
  - Declined workers see the exact rejection reason entered by the administrator.
- **Correct & Reapply:**
  - One-tap button opens registration with all previous fields pre-filled, allowing the worker to update flagged information and resubmit.
- **Logout Action:**
  - Red Logout button with confirmation dialog on the verification screen to switch accounts.

### 6. Customer Delivery Addresses (Strictly User-Scoped)
- **Database CRUD:**
  - Integrated with Supabase `addresses` table (Add, Edit, Delete, Set as Default).
- **Strict Data Isolation:**
  - Only addresses belonging to the authenticated customer (`user_id`) are displayed (no dummy or leaked data).
- **Checkout Integration:**
  - The customer's default delivery address is automatically loaded in `BookingDetailsScreen` and linked to the booking record.

### 7. Customer Order Management & Booking Lifecycle
- **State Machine Flow:**
  - `REQUESTED` ➔ `ACCEPTED` ➔ `EN_ROUTE` ➔ `IN_PROGRESS` ➔ `COMPLETED` / `CANCELLED`.
- **Cancellation & Rescheduling:**
  - Customers can reschedule active bookings (date/time/address) or cancel with reason logging.
- **OTP-Protected Escrow Release:**
  - Customer verifies artisan work with an OTP release code before funds are disbursed.

### 8. Explainable AI Services
- **FairMatch Engine (`FairMatchService`):**
  - Fair distribution of jobs preventing artisan starvation; logs match explanations (proximity, skill fit, union balance).
- **Demand Forecasting (`DemandForecastService`):**
  - Zone-wise workload forecasts for labour planning without exposing customer PII.

---

## 🚀 What Remains To Be Done (Roadmap)

### Priority 1: Payments & Production Escrow
1. **Razorpay Production Webhook:**
   - Deploy Supabase Edge Function to handle `payment.captured` and `refund.processed` webhooks for automated escrow funding and refunds.
2. **Artisan Bank Account Payouts (UPI / IMPS):**
   - Connect payout transfer APIs (RazorpayX or Cashfree) to disburse funds to artisan accounts upon customer OTP verification.

### Priority 2: Real-time Communication & Notifications
1. **Push Notifications (FCM / APNs):**
   - Set up Firebase Cloud Messaging for instant booking alerts ("Artisan assigned", "Artisan is en route", "Job completed").
2. **In-App Worker-Customer Chat:**
   - Lightweight chat channel over Supabase Realtime for job location coordination without sharing phone numbers.

### Priority 3: Offline & PWA Polish
1. **Offline Mode for Workers:**
   - Local caching (Hive or SQLite) so artisans can view their active schedule in low-connectivity areas.
2. **PWA & Multilingual Localization:**
   - Complete Marathi (`mr`) and Hindi (`hi`) translation keys across all customer and worker screens.
