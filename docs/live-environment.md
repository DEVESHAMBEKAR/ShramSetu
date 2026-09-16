# ShramSetu — Live Environment Audit & Specification
**Document Version:** 1.0.0  
**Audit Timestamp:** 2026-09-16T20:30:00+05:30  
**Target Environment:** LIVE / REAL BACKEND  

---

## 1. Executive Environment Summary

This document specifies the authoritative environment topology for the **ShramSetu** cooperative service marketplace as audited from codebase inspection, network probing against Supabase, and configuration analysis.

| Component | Target Platform / Provider | Environment State | Security / Secret Policy |
| :--- | :--- | :---: | :--- |
| **Backend / DB / Auth** | Supabase (PostgreSQL 15+) | Connected (`epcevntwhwyrrexlezco`) | Public anon key in client; service-role key strictly server-side |
| **Realtime Channel** | Supabase Realtime (WebSockets) | Configured for `public.bookings` | Postgres change broadcasts; REPLICA IDENTITY FULL |
| **Storage** | Supabase Storage | Configured (`profile-images`, `worker-documents`) | Private KYC bucket; public avatar read |
| **Edge Functions** | Supabase Edge Functions (Deno) | Defined locally (5 functions); pending deployment | Server-side secrets (`RAZORPAY_KEY_SECRET`, `FCM_KEY`) |
| **SMS / OTP Gateway** | Fast2SMS / Supabase Auth | Test & SMS Providers | Server-side API key only |
| **Push Notifications** | Firebase Cloud Messaging (FCM v1) | Client SDK + Edge Function dispatch | Client Google Services; service account server-side |
| **Payments / Escrow** | Razorpay Payment Gateway | TEST MODE (`rzp_test_...`) | Key ID in client/config; Secret server-side only |
| **Geolocation / Maps** | Google Maps SDK + Geolocator | Native GPS / Web Geolocation API | Android API Key in manifest placeholder |

---

## 2. Environment Configurations Breakdown

### 2.1 Supabase Backend (`epcevntwhwyrrexlezco`)
- **Project Reference ID:** `epcevntwhwyrrexlezco`
- **Supabase REST URL:** `https://epcevntwhwyrrexlezco.supabase.co`
- **Supabase Auth URL:** `https://epcevntwhwyrrexlezco.supabase.co/auth/v1`
- **Supabase Realtime URL:** `wss://epcevntwhwyrrexlezco.supabase.co/realtime/v1`
- **Public Client Key:** Standard publishable JWT anon key (Safe for client-side embedding per Supabase security guidelines).
- **Service Role Key:** **STRICTLY ABSENT** from Flutter client, `.env`, `.env.example`, and web assets.

### 2.2 Database Environment
- **Hosting:** Managed PostgreSQL on AWS via Supabase Infrastructure.
- **Schema Name:** `public`
- **Row Level Security (RLS):** Enabled on all 13 core domain tables.
- **Schema Snapshot:**
  - Base Tables: `users`, `services`, `skills`, `workers`, `worker_skills`, `worker_verification`, `addresses`, `bookings`, `payments`, `reviews`, `complaints`, `welfare_records`, `worker_verification_documents`.
  - Required Extensions: `uuid-ossp`, `pgcrypto`.

### 2.3 Authentication Environment
- **Customer Auth:** Mobile Number + OTP via Supabase GoTrue Auth API.
- **Worker Auth:** Mobile Number + OTP via Supabase GoTrue Auth API.
- **Admin Auth:** Email (`ambekardevesh2@gmail.com`) + Password via Supabase Auth.
- **Role Verification:** Querying `public.users.role` with `RoleGuard` protection and owner-admin fallback.

### 2.4 Storage Environment
- **Bucket `profile-images`:** Public read access for worker and customer avatars; authenticated write restricted to user's folder (`auth.uid() = foldername[1]`).
- **Bucket `worker-documents`:** Private access. Only the worker and Admin can read KYC documents; only the worker can upload their verification files.

### 2.5 Edge Functions
Located in `supabase/functions/`:
1. `create-payment-order`: Generates Razorpay order IDs and registers pending escrow rows.
2. `verify-payment`: Validates Razorpay HMAC SHA256 signature server-side and moves escrow to `held`.
3. `release-escrow`: Atomically releases funds upon customer/admin completion confirmation.
4. `send-push-notification`: Delivers FCM push messages via FCM v1 HTTP API using service account credentials.
5. `razorpay-webhook`: Processes webhook events directly from Razorpay servers.

### 2.6 Razorpay Payment Environment
- **Status:** **TEST MODE**
- **Public Key ID:** `rzp_test_...`
- **Safety Precaution:** Live financial transactions are **NOT enabled** until production merchant KYC is finalized and explicit live keys are provided in Supabase Secrets.

### 2.7 Fast2SMS / OTP Environment
- **Status:** Configured via Supabase Auth SMS Provider.
- **Local Fallback:** Supported phone numbers for automated testing remain functional without external SMS consumption.

### 2.8 Location / Google Maps Environment
- **Mobile:** Uses device GPS hardware via `geolocator` plugin with runtime permission handling.
- **Web:** Uses HTML5 Geolocation API (`window.navigator.geolocation`).
- **Map Tiles:** Google Maps Flutter plugin with Android manifest placeholder.

---

## 3. Environment Variable Specification

### 3.1 Client-Facing (`app/.env`)
```env
# Supabase Configuration (Public Client Credentials)
SUPABASE_URL=https://epcevntwhwyrrexlezco.supabase.co
SUPABASE_ANON_KEY=<SUPABASE_PUBLISHABLE_ANON_KEY>

# Feature Flags
# false = Live Supabase Backend; true = Local In-Memory Mock Store
USE_MOCK_DATA=false
```

### 3.2 Server-Facing Secrets (Supabase Secrets Vault — NEVER in Client)
```bash
# Razorpay Credentials
supabase secrets set RAZORPAY_KEY_ID="rzp_test_..."
supabase secrets set RAZORPAY_KEY_SECRET="<RAZORPAY_SERVER_SECRET>"
supabase secrets set RAZORPAY_WEBHOOK_SECRET="<RAZORPAY_WEBHOOK_SECRET>"

# FCM Credentials
supabase secrets set FCM_SERVICE_ACCOUNT_KEY='{"type":"service_account",...}'

# SMS Gateway Credentials
supabase secrets set FAST2SMS_API_KEY="<FAST2SMS_KEY>"
```
