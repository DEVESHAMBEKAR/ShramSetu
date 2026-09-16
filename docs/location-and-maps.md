# Location & Google Maps / GPS Infrastructure

**Phase 18 Implementation Guide — ShramSetu Platform**

---

## 1. Location Architecture

The location subsystem in ShramSetu provides real geographic awareness across Customer, Worker, Marketplace Discovery, and Booking modules while strictly respecting data separation, device battery preservation, and user privacy:

```
┌────────────────────────────────────────────────────────────────────────┐
│                          Flutter UI Layer                              │
│  CustomerProfileOnboardingScreen  │  CustomerHomeScreen (Location Pill)│
│  MapLocationPickerScreen          │  WorkerProfileSettingsScreen       │
└───────────────────▲────────────────────────────────▲───────────────────┘
                    │                                │
┌───────────────────┴───────────────┐  ┌─────────────┴───────────────────┐
│     Core Location Service         │  │        Repository Layer         │
│     LocationService               │  │  IUserRepository               │
│  - Permission check & request     │  │  IWorkerRepository             │
│  - GPS coordinates (Geolocator)   │  │  ICustomerRepository           │
│  - Reverse geocoding (Geocoding)  │  │  - distance calculation via     │
│  - Timeout & fallback handling    │  │    HaversineDistanceUtil        │
└───────────────────▲───────────────┘  └─────────────▲───────────────────┘
                    │                                │
┌───────────────────┴───────────────┐  ┌─────────────┴───────────────────┐
│       Device Hardware / APIs      │  │        Supabase PostgreSQL      │
│  - Android GPS / LocationManager  │  │  - addresses (lat, lng)         │
│  - Google Maps SDK (fallback mode)│  │  - workers (lat, lng, updated)  │
│                                   │  │  - bookings (address_id, dist)  │
└───────────────────────────────────┘  └─────────────────────────────────┘
```

- **UI Isolation:** UI screens never communicate directly with platform plugins (`geolocator`, `geocoding`). All hardware calls are encapsulated in `ILocationService`.
- **Dependency Injection:** Accessible via `DI.locationService`, enabling mock implementations for automated testing.
- **Repository Integration:** Coordinates are persisted in PostgreSQL via `IUserRepository` and `IWorkerRepository`.

---

## 2. Device Permission Handling

Location permissions follow Google Play and Android 14+ foreground location requirements:

- **Permissions in `AndroidManifest.xml`:**
  - `android.permission.ACCESS_FINE_LOCATION` (high precision GPS)
  - `android.permission.ACCESS_COARSE_LOCATION` (approximate network/cellular)
  - `android.permission.INTERNET` (map tile downloading & reverse geocoding)
- **Zero Background Tracking:** No `ACCESS_BACKGROUND_LOCATION` is requested or used.
- **Permission Lifecycle:**
  1. `Geolocator.isLocationServiceEnabled()` verifies GPS hardware status.
  2. `Geolocator.checkPermission()` / `Geolocator.requestPermission()` prompts the user during direct interactions (e.g. tapping "Use Current GPS").
  3. `LocationPermissionStatus` handles `granted`, `denied`, `deniedForever`, and `servicesDisabled`.
  4. If permission is denied or service disabled, the application displays clear feedback and immediately allows the user to continue with manual address entry without blocking the workflow.

---

## 3. Address Coordinates

The `public.addresses` table stores high-precision coordinates:
- `latitude NUMERIC(10,7)`
- `longitude NUMERIC(10,7)`

In Dart:
- `CustomerAddress` model contains `final double? latitude` and `final double? longitude`.
- Helper `bool get hasCoordinates => latitude != null && longitude != null;`.
- Backwards compatibility: Addresses created prior to Phase 18 with `NULL` coordinates continue to work seamlessly across the UI and checkout flows.

---

## 4. Customer Location Flow

### A. Onboarding / Profile Setup (`CustomerProfileOnboardingScreen`)
1. Customer enters their name.
2. Under "Your Primary Address", two quick actions are presented:
   - **"Use Current GPS":** Triggers `LocationService.getCurrentPosition()`, runs reverse geocoding, and autofills the address fields (`addressLine`, `area`, `city`, `state`, `postalCode`) while locking GPS coordinates.
   - **"Pick on Map":** Opens `MapLocationPickerScreen` to visually pinpoint the residence or service entrance.
3. Customer can review, confirm, and edit any text fields before saving.
4. On submission, `DI.userRepo.createAddress(...)` records both address fields and coordinates.

### B. Home Screen Location Switcher (`CustomerHomeScreen`)
1. Top location pill dynamically displays the customer's active area and city.
2. Tapping the location pill opens the **Service Location** sheet.
3. Allows instant GPS refreshing or re-selecting on Google Map.
4. Updates profile and triggers reload of nearby workers with fresh distances.

---

## 5. Worker Location Flow

1. Workers set their base of operations through `WorkerProfileSettingsScreen`.
2. Under "Service Area", tapping the tile opens the **Worker Service Area** sheet.
3. Worker can tap "Update with Current GPS Location" or "Pick Area on Map".
4. Obtains coordinates and human-readable locality string.
5. Invokes `DI.workerRepo.updateWorkerLocation(worker.id, latitude, longitude, locationTag)`.
6. Updates `location_updated_at` timestamp.
7. `WorkerDashboardScreen` displays the active service location and duty status.

---

## 6. Google Maps Configuration

- Integrated package: `google_maps_flutter: ^2.10.0`.
- Android API Key Configuration:
  - `AndroidManifest.xml` defines `<meta-data android:name="com.google.android.geo.API_KEY" android:value="${GOOGLE_MAPS_API_KEY}" />`.
  - `build.gradle.kts` defines a fallback placeholder in `defaultConfig`:
    ```kotlin
    manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = (project.findProperty("GOOGLE_MAPS_API_KEY") as String?) ?: ""
    ```
- **Fallback Guarantee:** If no API key is set or Google Play Services are unavailable on the device, `MapLocationPickerScreen` gracefully falls back to a clean visual coordinate picker card without crashing.

---

## 7. Reverse Geocoding

- Encapsulated within `LocationService.reverseGeocode(latitude, longitude)`.
- Uses the `geocoding` package (`placemarkFromCoordinates`).
- Parses placemark components into structured `GeoAddress`:
  - `addressLine`: street, house number, or thoroughfare
  - `area`: sub-locality (e.g. Kothrud, Aundh)
  - `city`: locality or sub-administrative area (e.g. Pune)
  - `state`: administrative area (e.g. Maharashtra)
  - `postalCode`: postal code (e.g. 411038)
- **Offline / Failure Safe:** If geocoding fails, coordinates are preserved and the user can manually enter or confirm the text address.

---

## 8. Distance Calculation

- Utility: `HaversineDistanceUtil` in `app/lib/core/utils/distance_calculator.dart`.
- Uses spherical law of cosines / Haversine formula with Earth radius $R = 6371.0\text{ km}$:
  $$a = \sin^2\left(\frac{\Delta\phi}{2}\right) + \cos(\phi_1)\cos(\phi_2)\sin^2\left(\frac{\Delta\lambda}{2}\right)$$
  $$c = 2\operatorname{atan2}\left(\sqrt{a}, \sqrt{1-a}\right)$$
  $$d = R \cdot c$$
- Precision: Rounded to 1 decimal place.
- **Zero API Dependency:** Evaluated entirely locally in pure Dart; never incurs Google Maps Distance Matrix or Directions API costs.
- Helpers:
  - `calculateDistance(lat1, lon1, lat2, lon2)`
  - `formatDistance(distanceKm)` (formats `< 1 km` as meters and `>= 1 km` as kilometers).

---

## 9. Database Changes

### Migration `009_worker_location.sql`
```sql
ALTER TABLE public.workers
  ADD COLUMN IF NOT EXISTS latitude NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS longitude NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS location_updated_at TIMESTAMP WITH TIME ZONE;

CREATE INDEX IF NOT EXISTS idx_workers_location 
  ON public.workers(latitude, longitude) 
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
```

---

## 10. RLS & Security

- **Customer Addresses:**
  - `Users can manage their own addresses`: `auth.uid() = user_id`.
  - Customers cannot view or modify addresses belonging to other customers.
  - Assigned workers can only view the customer's address for their specific confirmed bookings.
- **Worker Locations:**
  - `Workers can update own worker profile`: `auth.uid() = id`.
  - Workers can only update their own coordinates and timestamp.
  - Active worker profiles are readable by authenticated users for marketplace discovery without exposing sensitive home addresses.
- **Service Keys & Secrets:**
  - Zero Google API keys or Supabase service-role keys are exposed in client-side code.

---

## 11. Privacy Considerations

- **No Continuous Tracking:** Location is sampled only upon explicit user action ("Use Current Location" or "Update Location").
- **Zero Breadcrumb Trails:** No location history tables or historical path logs exist.
- **Worker Protection:** Discovery shows distance in kilometers (e.g. `2.4 km`) and general area tag (e.g. `Kothrud, Pune`) rather than broadcasting raw worker coordinates to unverified customers.

---

## 12. Error & Fallback States

| Error State | Handling Strategy |
|---|---|
| **Location Services Disabled** | Warns user with option to open system GPS settings; allows immediate manual text entry. |
| **Permission Denied** | Informs user; manual entry remains primary and unblocked. |
| **Permission Denied Forever** | Directs user to app settings if desired; manual entry remains unblocked. |
| **GPS Request Timeout** | Falls back to last known position or prompts manual address entry. |
| **Reverse Geocoding Failure** | Retains GPS coordinates and prompts user to verify street/city text. |
| **Google Maps SDK Missing Key** | Map picker displays coordinate fallback preview card without crashing. |

---

## 13. Testing

- Test suite: `app/test/location_distance_test.dart`
- Tests cover:
  1. Coordinate model serialization, equality, and hash code.
  2. Address coordinate serialization (`CustomerAddress.fromMap`, `toMap`).
  3. Deserialization with `NULL` coordinates (backwards compatibility).
  4. Haversine distance known-distance calculation (Pune Station to Swargate).
  5. Zero-distance calculation (identical coordinates).
  6. Symmetry verification ($A \to B = B \to A$).
  7. Invalid and out-of-bound coordinate handling.
  8. `formatDistance` for meters and kilometers.
  9. `LocationPermissionStatus` and `LocationResult.isSuccess`.
  10. Hermetic mock location service testing (`TestMockLocationService`).
  11. Worker location serialization and mock repository updates.
  12. Booking flow state address and coordinate compatibility.

---

## 14. Future Integration with FairMatch

While FairMatch AI is out of scope for Phase 18, the location data model is designed to support it seamlessly:
- `workers.location_updated_at` allows FairMatch algorithms to check location freshness (e.g. discard coordinates older than 4 hours).
- `bookings.distance_km` records the confirmed dispatch distance for transparent cooperative travel allowance calculations.
- `HaversineDistanceUtil` provides the foundational distance metric for proximity-weighted dispatch scoring.
