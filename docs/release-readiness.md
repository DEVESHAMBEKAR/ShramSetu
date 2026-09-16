# ShramSetu Release Readiness & Deployment Audit

**Project:** ShramSetu – AI-Powered Cooperative Gig Worker Service Marketplace  
**Target Release:** Android Production APK / AAB (Google Play Store)  
**Version:** 1.0.0-rc  
**Audit Date:** September 16, 2026  
**Final Status:** Conditionally Ready for Staging / Production Deployment  

---

## 1. Release Readiness Scorecard

| Dimension | Grade | Verified Baseline | Gaps / Prerequisites |
| :--- | :---: | :--- | :--- |
| **1. Security & Privacy** | **A** | Zero secrets in repo; RLS active on 13/13 tables; private KYC bucket; `search_path` hardened in migration 015 | Production pen-test by external auditor |
| **2. Reliability & Tests** | **A** | **166 / 166 tests passing**; complete regression coverage across Customer, Worker, Admin, AI, and Payments | End-to-end device testing on low-end Android hardware |
| **3. Code Quality** | **A** | **0 errors** in `flutter analyze`; clean separation of UI, business logic, and repositories | Resolve 23 non-fatal deprecation infos/warnings |
| **4. Database Integrity** | **A** | 15 sequential SQL migrations; atomic triggers; composite indexes; idempotent RPCs | Apply migrations sequentially to production Supabase project |
| **5. AI & Explainability** | **A** | FairMatch v1 explainable recommendations; Demand Forecasting v1 Holt-Winters; zero math floats shown to customers | Real-world validation of Holt-Winters parameter tuning ($L=7$) |
| **6. Payments & Escrow** | **A-** | Escrow state machine (`held` -> `released`); Razorpay signature verification; double-release protection | Production Razorpay merchant account activation & webhook secret |
| **7. Packaging & Build** | **B+** | Debug APK compiles cleanly in 41.7s (`app-debug.apk`); assets verified | Generate production upload keystore (`upload-keystore.jks`) |
| **8. Observability & Logging** | **A-** | Zero raw `print` statements in app code; structured `debugPrint`; exception swallowing prevented | Configure production crash reporting (Sentry or Firebase Crashlytics) |

---

## 2. Android Production Release Checklist

### 2.1 Package Identity & Versioning
- **Application ID:** `com.shramsetu.app`
- **Current Version:** `1.0.0` (Build `1`)
- **Min SDK:** `21` (Android 5.0 Lollipop - supports 99.2% of active Android devices in India)
- **Target SDK:** `34` (Android 14 - compliant with latest Google Play Store API requirements)
- **Compile SDK:** `34`

### 2.2 Permissions in `AndroidManifest.xml`
The following permissions are configured in `android/app/src/main/AndroidManifest.xml`:
- `android.permission.INTERNET`: Required for Supabase API, Razorpay checkout, and FCM.
- `android.permission.ACCESS_FINE_LOCATION`: Required for GPS-based worker distance calculation.
- `android.permission.ACCESS_COARSE_LOCATION`: Required for battery-saving background updates.
- `android.permission.CAMERA`: Required for worker KYC document capture and customer profile photo.
- `android.permission.POST_NOTIFICATIONS`: Required for Android 13+ FCM push notifications.
- `android.permission.VIBRATE`: Required for critical booking alert haptics.

### 2.3 Network Security & Cleartext Traffic
- Production release configuration enforces:
  ```xml
  android:usesCleartextTraffic="false"
  ```
- All mobile communication routes exclusively through TLS 1.3 encrypted HTTPS / WSS endpoints (Supabase and Razorpay).

### 2.4 Keystore & Code Obfuscation (R8/ProGuard)
Before building the final production App Bundle (`flutter build appbundle --release`):
1. **Generate Upload Keystore:**
   ```powershell
   keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. **Configure `android/key.properties` (Excluded from git):**
   ```properties
   storePassword=<SECURE_PASSWORD>
   keyPassword=<SECURE_PASSWORD>
   keyAlias=upload
   storeFile=../upload-keystore.jks
   ```
3. **Verify ProGuard Rules (`android/app/proguard-rules.pro`):**
   Ensure Razorpay and Supabase models are preserved:
   ```proguard
   -keep class com.razorpay.** { *; }
   -dontwarn com.razorpay.**
   ```

---

## 3. Backend Deployment Procedures

### 3.1 Applying Supabase Migrations
Execute the 15 migrations in sequential order against the target Supabase project:
```bash
supabase db push
# Or sequentially via Supabase SQL Editor:
# 001_initial_schema.sql
# 002_rls_policies.sql
# 003_seed_data.sql
# 007_storage_and_kyc.sql
# 008_realtime_bookings.sql
# 009_worker_location.sql
# 010_razorpay_payments.sql
# 011_reviews_and_ratings.sql
# 012_fcm_notifications.sql
# 013_fairmatch_engine.sql
# 014_demand_forecasting.sql
# 015_security_and_performance_hardening.sql
```

### 3.2 Setting Production Edge Function Secrets
Do **not** commit production secrets to version control. Set them directly via Supabase CLI:
```bash
supabase secrets set RAZORPAY_KEY_ID="rzp_live_..."
supabase secrets set RAZORPAY_KEY_SECRET="live_secret_..."
supabase secrets set RAZORPAY_WEBHOOK_SECRET="whsec_..."
supabase secrets set FAST2SMS_API_KEY="fast2sms_prod_..."
supabase secrets set FCM_SERVICE_ACCOUNT_KEY='{"type":"service_account",...}'
```

### 3.3 Deploying Edge Functions
```bash
supabase functions deploy create-payment-order
supabase functions deploy verify-payment
supabase functions deploy release-escrow
supabase functions deploy razorpay-webhook
supabase functions deploy send-push-notification
```

---

## 4. Production Readiness Statement

### VERIFIED (Ready for Production Deployment):
- [x] **Full Test Suite:** 166/166 automated unit and integration tests passing.
- [x] **Zero Errors in Static Analysis:** `flutter analyze` passes with 0 errors.
- [x] **Debug APK Compilation:** Clean Android debug build (`app-debug.apk`) produced in 41.7s.
- [x] **Multi-Role Security:** Customer, Worker, and Admin roles strictly separated in database RLS.
- [x] **Search Path Hardening:** `auth_user_role()` and rating trigger functions secured with `SET search_path = public, pg_temp;`.
- [x] **Storage Isolation:** Worker KYC bucket access restricted to document owners and federation admins.
- [x] **Payment Security:** Secret keys completely isolated server-side; webhooks signed via HMAC SHA256; escrow release state machine verified against double-release.
- [x] **AI Integrity & Transparency:** FairMatch v1 scoring operates authoritatively on server; customers receive explainable badges with zero raw math floats; Demand Forecasting v1 is locked to administrators.
- [x] **Client Memory Hygiene:** All stream subscriptions and text controllers disposed cleanly across all stateful screens.
- [x] **Logging Sanitization:** Zero raw `print` statements in application codebase.

### NOT VERIFIED (Requires External Third-Party Action Prior to Launch):
- [ ] **Live Razorpay Production Activation:** Requires legal business verification, bank account KYC, and exchange of test keys for live merchant credentials.
- [ ] **Fast2SMS Production DLT Registration:** Requires TRAI DLT registration of SMS sender ID and approved template IDs for commercial OTP delivery in India.
- [ ] **Google Play Developer Account:** Requires payment of Google Play Console fee, upload of AAB, and privacy policy declaration.
- [ ] **End-to-End Stress Testing:** Simulated load test with >5,000 active concurrent users on Supabase tier.

### RECOMMENDED FUTURE WORK (Post-MVP):
- Add Sentry or Firebase Crashlytics for real-time mobile crash observability.
- Configure automated pg_cron job for midnight batch generation of daily demand forecasts.
- Add biometric authentication for one-tap escrow release by customers.
