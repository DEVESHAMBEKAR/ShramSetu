# 📋 ShramSetu — Project Handover & Status Log

### Project Summary
**ShramSetu** is an AI-powered, cooperative-first civic service marketplace built with Flutter and Supabase in partnership with the Pune District Labour Cooperative Federation. It connects local trade artisans (electricians, plumbers, carpenters, etc.) with residential and commercial customers using zero-commission escrow payouts, explainable AI matching (FairMatch), and federation admin governance.

---

## 🛠️ Tech Stack & Architecture

- **Frontend:** Flutter (Web & Android APK, Dart 3.x)
- **Backend / Database:** Supabase (PostgreSQL 15, Row Level Security, Realtime Channels, Edge Functions, Storage Buckets)
- **Architecture Pattern:** Clean Separation (`Presentation` ➔ `Repository / Service` ➔ `Data Sources / Supabase Client`)
- **Visual Truth:** Stitch UI specification & design tokens; Urban Company tier polish
- **Current Quality Status:** **99+ automated unit and widget tests passing** (`flutter test test/unit/`) with **0 analyzer compilation errors** (`flutter analyze`).

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

## 🚀 Future Roadmap & Next Steps

1. **Production Escrow Webhooks:**
   - Deploy Supabase Edge Functions for Razorpay webhook verification (`payment.captured`, `refund.processed`).
2. **Artisan Bank Account Payouts (UPI / IMPS):**
   - Connect payout transfer APIs (RazorpayX or Cashfree) upon customer OTP escrow release.
3. **Push Notifications:**
   - Configure Firebase Cloud Messaging (FCM) credentials for live job dispatch alerts.
4. **In-App Messaging:**
   - Worker-to-customer chat channel over Supabase Realtime channels.
