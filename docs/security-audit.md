# ShramSetu Production Security Audit & Hardening Report

**Project:** ShramSetu – AI-Powered Cooperative Gig Worker Service Marketplace  
**Version:** 1.0.0-rc  
**Audit Date:** September 16, 2026  
**Status:** Hardened & Audited  

---

## 1. Executive Summary & Architecture

ShramSetu connects blue-collar cooperative artisans with local consumers through verified trades, transparent matching (FairMatch), and escrow-protected transactions (Razorpay). 

The security posture is built on a **Zero-Trust Client Principle**:
1. The Flutter mobile application never stores or possesses backend administrative secrets or `service_role` credentials.
2. All transactional authorization, worker eligibility verification, escrow state transitions, and analytical aggregations execute authoritatively in PostgreSQL (RLS / RPCs) and isolated serverless Deno Edge Functions.
3. The mobile application operates exclusively with the Supabase anon/publishable key and Razorpay public Key ID.

---

## 2. Authentication & Session Management

### 2.1 Supabase Auth & Phone OTP Flow
- **Mechanism:** Phone authentication with SMS OTP via Fast2SMS routed through Supabase Auth / Edge Functions.
- **Credential Storage:** `flutter_secure_storage` encrypted on-device keychain/keystore. No plaintext tokens in `SharedPreferences`.
- **Session Expiry & Refresh:** JWT access tokens automatically refreshed by the Supabase client library with auto-logout on refresh token revocation.
- **Role Authority:** User role (`CUSTOMER`, `WORKER`, `ADMIN`) is stored in `public.users(role)` with immutable server-side trigger verification. Client cannot self-promote to `ADMIN` or alter other profiles.

### 2.2 Role-Based Routing
- App routing in `main.dart` and `splash_screen.dart` evaluates authoritative session role before presenting screens:
  - `CUSTOMER` -> `CustomerMainLayout` (Marketplace, Bookings, Tracking, Profile)
  - `WORKER` -> `WorkerMainLayout` (Dashboard, Job Requests, Earnings, Settings)
  - `ADMIN` -> `AdminDashboardScreen` (Management, Services, KYC Reviews, Demand Forecast Hub)

---

## 3. Database Security & Row Level Security (RLS) Matrix

RLS is enabled on **100% of public database tables (13/13)**:

| Table Name | RLS Status | Customer Access | Worker Access | Admin Access | Enforcement Mechanism |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `public.users` | **Active** | Read/Update own (`auth.uid() = id`) | Read/Update own (`auth.uid() = id`) | Read/Manage all | `002_rls_policies.sql` |
| `public.services` | **Active** | Read active (`is_active = true`) | Read active (`is_active = true`) | Full CRUD | `002_rls_policies.sql` |
| `public.skills` | **Active** | Read all | Read all | Full CRUD | `002_rls_policies.sql` |
| `public.workers` | **Active** | Read active (`worker_status = 'ACTIVE'`) | Read/Update own profile | Full CRUD | `002_rls_policies.sql` |
| `public.worker_skills` | **Active** | Read all | Manage own (`worker_id = auth.uid()`) | Full CRUD | `002_rls_policies.sql` |
| `public.worker_verification`| **Active** | **No access** | Read/Insert/Update own | Full CRUD | `002_rls_policies.sql` |
| `public.addresses` | **Active** | Full CRUD own (`user_id = auth.uid()`) | Read customer addr for assigned booking | Read all | `002_rls_policies.sql` |
| `public.bookings` | **Active** | Read/Insert/Cancel own | Read/Update assigned bookings | Full CRUD | `002_rls_policies.sql` |
| `public.payments` | **Active** | Read own (`customer_id = auth.uid()`) | Read own (`worker_id = auth.uid()`) | Full CRUD | `002_rls_policies.sql`, `010` |
| `public.reviews` | **Active** | Read all; Insert/Update own completed | Read all | Full CRUD | `011_reviews_and_ratings.sql` |
| `public.complaints` | **Active** | Read/Insert own | Read/Insert complaints against them | Full CRUD | `002_rls_policies.sql` |
| `public.welfare_records`| **Active** | **No access** | Read own (`worker_id = auth.uid()`) | Full CRUD | `002_rls_policies.sql` |
| `public.demand_forecasts`| **Active** | **No access** | **No access** | Full CRUD | `014_demand_forecasting.sql` |

---

## 4. PostgreSQL `SECURITY DEFINER` Hardening

### 4.1 Identified Vulnerability (Patched in Migration `015`)
Prior to Migration `015`, `public.auth_user_role()` in `002_rls_policies.sql` and `public.update_worker_rating_and_count()` in `011_reviews_and_ratings.sql` were declared `SECURITY DEFINER` without setting an explicit `search_path`. This exposed potential schema search path hijacking if malicious objects were created in temporary schemas.

### 4.2 Remediation
Migration `015_security_and_performance_hardening.sql` explicitly enforces:
```sql
CREATE OR REPLACE FUNCTION public.auth_user_role() RETURNS TEXT AS $$
  SELECT role FROM public.users WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER
SET search_path = public, pg_temp;
```
and:
```sql
CREATE OR REPLACE FUNCTION public.update_worker_rating_and_count()
RETURNS TRIGGER AS $func$
...
$func$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;
```
All administrative, payment, and matching RPCs (`fairmatch_recommend_workers`, `submit_booking_review`, `get_historical_booking_demand`, `save_demand_forecasts`) are verified to have strict `SET search_path = public` or `SET search_path = public, pg_temp;`.

---

## 5. Storage Security & KYC Document Isolation

Two separate Supabase Storage buckets are configured (`007_storage_and_kyc.sql`):

1. **`profile-images` (Public Read / Auth Write)**:
   - Contains customer and worker profile avatars.
   - Read access: Public.
   - Insert/Update access: Authenticated user uploading to their own user-folder (`(storage.foldername(name))[1] = auth.uid()::text`).

2. **`worker-documents` (Strictly Private / Confined Isolation)**:
   - Contains Aadhaar cards, trade certificates, government IDs, and verification records.
   - Read access: **Restricted exclusively to the document owner (`auth.uid() = foldername`) and Admins (`auth_user_role() = 'ADMIN'`)**.
   - Customers have zero read or write access to this bucket.
   - File validation: Server-side MIME validation and path naming format enforced.

---

## 6. Payment & Escrow Security

### 6.1 Secret Isolation
- `RAZORPAY_KEY_SECRET` is **never** embedded in Flutter code, environment files committed to git, or asset bundles.
- Secret resides strictly in Supabase Edge Function environment secrets (`Deno.env.get('RAZORPAY_KEY_SECRET')`).
- Client only receives the Razorpay public `keyId` for rendering the native checkout sheet.

### 6.2 Razorpay Webhook Signature Verification
- Webhooks from Razorpay hitting `supabase/functions/razorpay-webhook/` validate HMAC SHA256 signatures:
  ```ts
  const expectedSignature = createHmac('sha256', webhookSecret)
    .update(rawBody)
    .digest('hex');
  if (expectedSignature !== razorpaySignature) {
    return new Response('Unauthorized', { status: 401 });
  }
  ```
- Reject all forged or tampered payment callbacks.

### 6.3 Escrow State Machine Rigidity
- Escrow funds cannot transition arbitrarily:
  - `not_funded` -> `held` (Only upon successful payment signature verification)
  - `held` -> `released` (Only upon explicit OTP delivery confirmation or customer release)
  - `held` -> `refunded` (Only on admin cancellation or dispute resolution)
- Double-release protection: Calling `releaseEscrow` twice returns `false` on the second call without releasing additional funds.

---

## 7. Push Notifications & FCM Security

- `FCM_SERVICE_ACCOUNT_KEY` is kept server-side in `send-push-notification` Edge Function.
- Device token registration RPC `register_device_token` verifies `auth.uid() = p_user_id` preventing token spoofing or foreign device hijacking.
- Deactivated tokens are purged upon logout (`deactivate_device_token`).

---

## 8. AI & Research Integrity

### 8.1 FairMatch (`fairmatch_v1`)
- Scores are calculated authoritatively on the server (`fairmatch_recommend_workers` RPC) or through `FairMatchEngine`.
- Client-side injection of scores is impossible; the UI consumes server-generated rankings.
- Hard pre-filtering: Inactive workers (`worker_status != 'ACTIVE'`) and unavailable workers (`is_available = false`) are pruned before feature computation.
- Customer privacy: Customer UI never sees raw float scores, factor formulas, or competitors' workload numbers.

### 8.2 Demand Forecasting (`demand_forecast_v1`)
- Aggregation RPC `get_historical_booking_demand` verifies `auth_user_role() = 'ADMIN'`.
- Customer PII (phone numbers, full addresses) is completely excluded from the aggregation pipeline.
- Persistence RPC `save_demand_forecasts` is strictly admin-only.

---

## 9. Client Logging & Sensitive Data Sanitization

- Grep audit of `c:\ShramSetu\app\lib`:
  - `print(`: **0 occurrences** (lone debug log in `customer_live_tracking_screen.dart` replaced with `debugPrint`).
  - Sensitive logging: Zero logging of plain OTPs, passwords, Razorpay payment signatures, or full card details.
  - Exception handling: Stack traces are suppressed from production UI snackbars and release logs.

---

## 10. Vulnerability Severity Matrix & Remediations

| # | Severity | Finding | Root Cause | Status | Mitigation Applied |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **SEC-1** | **High** | Missing `search_path` in `auth_user_role()` | `002_rls_policies.sql` omitted `SET search_path` | **RESOLVED** | Migration `015` applies `SET search_path = public, pg_temp;` |
| **SEC-2** | **High** | Missing `search_path` in `update_worker_rating_and_count()` | `011_reviews_and_ratings.sql` omitted `SET search_path` | **RESOLVED** | Migration `015` applies `SET search_path = public, pg_temp;` |
| **SEC-3** | **Medium** | Raw `print` in `customer_live_tracking_screen.dart` | Uncleaned debug statement | **RESOLVED** | Replaced with release-safe `debugPrint` |
| **SEC-4** | **Low** | Missing index on `fairmatch_logs(created_at)` | Potential slow query on audit trail | **RESOLVED** | Added index in migration `015` |
| **SEC-5** | **Low** | Missing composite index on bookings status | Full table scans on demand aggregations | **RESOLVED** | Added `idx_bookings_demand_agg` in migration `015` |

---

## 11. Release Audit Verification Checklist

### VERIFIED:
- [x] Zero backend secrets or service-role keys committed to git or exposed in Flutter code.
- [x] `.env` files untracked and verified in `.gitignore`.
- [x] 13/13 database tables protected by Row Level Security.
- [x] Storage bucket `worker-documents` locked down to worker owners and federation admins.
- [x] Payment verification is idempotent and strictly validates Razorpay signatures.
- [x] Escrow state machine prevents double-release and unfunded release.
- [x] Multi-tenant isolation verified across Customer, Worker, and Admin roles.
- [x] 22/22 dedicated security tests in `test/security_and_performance_test.dart` passing.
- [x] 166/166 total regression tests passing.

### NOT VERIFIED (Runtime Third-Party Infrastructure):
- [ ] Live Razorpay production merchant account key exchange (currently running test key IDs).
- [ ] Live Fast2SMS Indian DLT template registration under production high concurrency (>100 req/s).
- [ ] Apple Developer Team App Attest / DeviceCheck token validation.
- [ ] Penetration test against production Supabase managed database endpoint by external red team.

### RECOMMENDED FUTURE WORK:
- Add certificate pinning via `http_certificate_pinning` for Edge Function API endpoints.
- Implement automated IP rate limiting via Cloudflare WAF or Supabase API Gateway.
- Implement biometric authentication (Fingerprint/FaceID) for high-value escrow release approvals.
