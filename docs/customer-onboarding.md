# Customer Onboarding Flow

**Last Updated:** September 15, 2026

---

## Overview

After successful OTP authentication, the app checks whether the customer's profile is complete. New customers (and existing customers with incomplete profiles) are sent to the **Customer Profile Onboarding** screen before they can access the home screen.

---

## Profile Completeness Criteria

A customer profile is considered **complete** if ALL of the following are true:

| Condition | Field | Notes |
|---|---|---|
| Name is set | `users.full_name` | Must be non-empty AND not start with `'User '` (auto-placeholder) |
| Address exists | `addresses` table | Customer must have at least one saved address |

This is evaluated server-side via `SupabaseUserRepository.isProfileComplete()`, which calls `getCustomerProfile()` and checks `CustomerProfile.isComplete`.

---

## Authentication Flow

```
OTP
 ↓
Supabase Auth (verifyOtp)
 ↓
upsertUserProfile (creates user row if new, placeholder name)
 ↓
isProfileComplete() checks:
  - users.full_name not placeholder
  - addresses count >= 1
 ↓
┌──────────────────┬──────────────────────────────┐
│ Profile COMPLETE │ Profile INCOMPLETE / NEW      │
│ /customer/home   │ /customer/onboarding          │
└──────────────────┴──────────────────────────────┘
```

### Session Restoration (Splash Screen)

```
App launch
 ↓
SplashScreen._checkSession()
 ↓
authRepo.getCurrentUser() → user found
 ↓
userRepo.getUserRole(userId) → 'CUSTOMER'
 ↓
userRepo.isProfileComplete(userId)
 ↓
┌──────────────────┬──────────────────────────────┐
│ Profile COMPLETE │ Profile INCOMPLETE            │
│ /customer/home   │ /customer/onboarding          │
└──────────────────┴──────────────────────────────┘
```

---

## Profile Fields

| Field | Table | Column | Required | Notes |
|---|---|---|---|---|
| Full Name | `users` | `full_name` | ✅ Yes | Min 2 chars, no placeholder names |
| Phone | `users` | `phone` | Auto | Set during OTP auth |
| Avatar URL | `users` | `avatar_url` | ❌ Optional | Uploaded to `profile-images/{userId}/avatar.jpg` |
| Address Line | `addresses` | `address_line` | ✅ Yes | Street address |
| Area/Locality | `addresses` | `area` | ❌ Optional | Neighbourhood |
| City | `addresses` | `city` | ✅ Yes | |
| State | `addresses` | `state` | ✅ Yes | |
| Postal Code | `addresses` | `postal_code` | ✅ Yes | 6-digit validation |

---

## Default Address Handling

- When creating a customer's **first address**, `is_default = true` is automatically set.
- This is determined server-side by checking the count of existing addresses before inserting.
- No client-side logic controls the default flag — prevents race conditions.
- Fallback: If no default address is found, the most recent address is returned as the default.

---

## Role Security

- `updateCustomerProfile()` never modifies `users.role`.
- The `role` column is only set during initial `upsertUserProfile()`.
- RLS policy `"Users can update their own profile"` allows UPDATE on their own row, but the repository explicitly excludes `role` from the update payload.

---

## RLS Policies

All policies are in `002_rls_policies.sql`. Relevant policies:

| Table | Operation | Policy |
|---|---|---|
| `users` | SELECT | `Users can view their own profile` (auth.uid() = id) |
| `users` | UPDATE | `Users can update their own profile` (auth.uid() = id) |
| `addresses` | ALL | `Users can manage their own addresses` (auth.uid() = user_id) |

---

## Customer Home Screen

`CustomerHomeScreen` is a `StatefulWidget` that loads the real profile once in `initState()`. It displays:

- `'Good morning/afternoon/evening, {first name}'` — time-aware greeting using real name
- `'{area}, {city}, {state}'` — real address from default address
- Falls back to empty greeting and `'Add your location'` if profile not yet loaded

---

## Error Handling

| Error | Behavior |
|---|---|
| Profile save fails | Error message shown, stays on onboarding, does NOT navigate to home |
| Address save fails | Error message shown, stays on onboarding |
| Image upload fails (optional) | Warns user but proceeds with profile save (image is optional) |
| Session expired during onboarding | Error shown, user prompted to log in again |

---

## Files Changed

| File | Change |
|---|---|
| `lib/features/customer/data/models/customer_profile.dart` | NEW — typed CustomerProfile and CustomerAddress models |
| `lib/core/repositories/i_user_repository.dart` | EXTENDED — added 5 new profile/address methods |
| `lib/features/auth/data/repositories/supabase_user_repository.dart` | IMPLEMENTED — all new methods |
| `lib/features/auth/data/repositories/mock_user_repository.dart` | IMPLEMENTED — all new methods with in-memory storage |
| `lib/features/customer/presentation/screens/customer_profile_onboarding_screen.dart` | NEW — onboarding screen |
| `lib/features/auth/presentation/screens/customer_login_screen.dart` | UPDATED — completeness check after OTP |
| `lib/features/customer/presentation/screens/splash_screen.dart` | UPDATED — completeness check on session restore |
| `lib/features/customer/presentation/screens/customer_home_screen.dart` | CONVERTED — StatelessWidget → StatefulWidget, real data |
| `lib/main.dart` | UPDATED — `/customer/onboarding` route registered |

---

## No Database Migration Required

The existing `001_initial_schema.sql` already contains all required fields in `users` and `addresses` tables.
