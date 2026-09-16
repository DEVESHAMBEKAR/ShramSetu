# ShramSetu — Push Notifications Architecture (FCM & Supabase)

## Overview
ShramSetu incorporates a secure, resilient, privacy-first push notification architecture using **Firebase Cloud Messaging (FCM)** for device push delivery and **Supabase** as the authoritative source of truth.

---

## 1. Architectural Flow

```text
+-----------------------+              +--------------------------+
|  Flutter Client App   |              |   Supabase PostgreSQL    |
| (Customer / Worker)   |              +--------------------------+
+-----------+-----------+                           |
            |                                       |
  (1) Login / Token Sync                            |
            |                                       |
            v                                       v
+-----------------------+              +--------------------------+
|  user_device_tokens   | <----------  |      notifications       |
| (multi-device record) |              |  (persistent in-app log) |
+-----------+-----------+              +--------------------------+
            |                                       |
            +-------------------+-------------------+
                                |
                                v
               +----------------------------------+
               |      Supabase Edge Function      |
               |     `send-push-notification`     |
               +----------------+-----------------+
                                |
                   (FCM HTTP v1 OAuth2 Dispatch)
                                |
                                v
               +----------------------------------+
               |     Firebase Cloud Messaging     |
               +----------------+-----------------+
                                |
                   (Push Delivery to Device)
                                |
                                v
               +----------------------------------+
               |   Flutter Background / Banner    |
               | (Deep Link / Live Tracking Nav)  |
               +----------------------------------+
```

---

## 2. Database Schema & RPCs

### Tables
1. **`public.user_device_tokens`**:
   - `id`: UUID Primary Key
   - `user_id`: References `users(id)` ON DELETE CASCADE
   - `fcm_token`: Device registration token (unique per user)
   - `platform`: `android` | `ios` | `web`
   - `device_id`: Optional hardware identifier
   - `is_active`: Boolean flag
   - `created_at`, `updated_at`, `last_seen_at`: Timestamps
   - `UNIQUE(user_id, fcm_token)`

2. **`public.notifications`**:
   - `id`: UUID Primary Key
   - `recipient_user_id`: References `users(id)` ON DELETE CASCADE
   - `type`: `booking_status`, `booking_requested`, `payment_released`, `review_received`
   - `title`: User-facing notification heading
   - `body`: Notification description
   - `data`: Sanitized JSON payload (IDs and non-sensitive status only)
   - `read_at`: Nullable timestamp when opened/read
   - `created_at`: Creation timestamp

### Secure RPCs
- **`register_device_token(p_fcm_token, p_platform, p_device_id)`**: Idempotently registers or activates device token for `auth.uid()`.
- **`deactivate_device_token(p_fcm_token)`**: Marks token inactive upon logout to prevent notification leak to shared devices.
- **`mark_notification_read(p_notification_id)`**: Marks an individual notification as read.

---

## 3. Privacy & Security Guarantees

> [!IMPORTANT]
> **Payload Privacy Guarantee**:
> In compliance with enterprise security and privacy rules, **NO sensitive customer data** is ever passed in FCM push notification data payloads:
> - Customer physical street addresses are NEVER included.
> - Customer or worker phone numbers are NEVER included.
> - Raw GPS coordinates (`latitude`, `longitude`) are NEVER included.
> - Payment credentials or secrets are NEVER included.
>
> Push payloads ONLY contain minimal reference identifiers:
> ```json
> {
>   "bookingId": "01944883-8a9d-7f41-b0e5-779872e45214",
>   "status": "accepted",
>   "type": "booking_status"
> }
> ```
> When the user taps the notification, the application fetches full, authorized data from Supabase protected by **Row Level Security (RLS)**.

---

## 4. Graceful Degradation (Zero-Crash Fallback)

If `google-services.json` or Firebase project secrets are absent:
1. `NotificationService.initialize()` catches initialization exceptions and logs an informative diagnostic warning.
2. The app falls back to local and mock notification mode.
3. In-app realtime notifications and Supabase database records continue to operate without crashing.
4. Android build configuration applies Google Services Gradle plugin conditionally:
   ```kotlin
   if (file("google-services.json").exists()) {
       apply(plugin = "com.google.gms.google-services")
   }
   ```

---

## 5. Firebase Setup Guide (For Production Deployment)

### Client Setup (Android)
1. Go to [Firebase Console](https://console.firebase.google.com/).
2. Create or select your Firebase project: `ShramSetu`.
3. Add an Android app with package name: `com.example.app` (or your production applicationId).
4. Download `google-services.json` and place it in:
   `c:\ShramSetu\app\android\app\google-services.json`
5. The build system will automatically detect the file and apply the `google-services` plugin.

### Server Setup (Supabase Edge Function)
1. In Firebase Console, go to **Project Settings > Service accounts**.
2. Click **Generate new private key** and download the JSON file.
3. Set the service account JSON as a secret in your Supabase CLI / Dashboard:
   ```bash
   supabase secrets set FIREBASE_SERVICE_ACCOUNT='{"type":"service_account","project_id":"...","private_key":"...","client_email":"..."}'
   ```
4. Deploy the Edge Function:
   ```bash
   supabase functions deploy send-push-notification
   ```

---

## 6. Token Lifecycle & Deep-Link Navigation

- **On Login / Session Restore**: The app fetches the current FCM token and registers it in `user_device_tokens`.
- **On Logout**: The app calls `deactivateCurrentToken()`, setting `is_active = false` in the database.
- **On Notification Tap**:
  - Worker is navigated to `WorkerJobDetailScreen(jobId: bookingId)`.
  - Customer is navigated to `CustomerLiveTrackingScreen(bookingId: bookingId)`.