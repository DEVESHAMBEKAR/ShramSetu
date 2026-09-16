# ShramSetu Multi-Platform Support: Web & Mobile Architecture

## 1. Executive Summary

ShramSetu is architected as a **single, unified cross-platform codebase** targeting both mobile devices (Android & iOS) and web browsers (Desktop & Mobile Web) as **first-class citizens**. Neither platform is an afterthought; both share 100% of the core domain, state machine logic, repository interfaces, and dependency injection layer while gracefully adapting presentation for optimal user experience.

---

## 2. Platform Target Matrix

| Capability | Android / iOS Mobile | Desktop & Tablet Web (Width $\ge$ 800px) | Mobile Web (Width < 800px) |
| :--- | :--- | :--- | :--- |
| **Primary Visual Layout** | Mobile Viewport with Bottom Navigation Bar | Responsive Wide Viewport with Desktop Sidebar Rail | Mobile Viewport with Bottom Navigation Bar |
| **Navigation Pattern** | Bottom Navigation Bar + Modal Sheets | Fixed Left Navigation Rail (260px) + Expanded Content Area | Bottom Navigation Bar + Modal Sheets |
| **Stitch UI Tokens** | 100% preserved (Colors, Typography, Radii, Spacing) | 100% preserved (Colors, Typography, Radii, Spacing) | 100% preserved (Colors, Typography, Radii, Spacing) |
| **Routing Mechanism** | Named Route Stack (`Navigator.pushNamed`) | Hash URL Strategy (`/#/customer/home`, `/#/worker/dashboard`) | Hash URL Strategy (`/#/...`) |
| **Route Protection** | `RoleGuard` widget checking session role | `RoleGuard` widget with URL manipulation prevention | `RoleGuard` widget with URL manipulation prevention |
| **Push Notifications** | Native Firebase Cloud Messaging (FCM) + APNs | Web Push Notification API / In-app realtime snackbars | Web Push Notification API / In-app realtime snackbars |
| **Location Services** | Native GPS via `geolocator` | HTML5 Geolocation API via `geolocator_web` | HTML5 Geolocation API via `geolocator_web` |
| **Escrow & Payments** | Razorpay Flutter SDK | Razorpay Standard Web Checkout Modal | Razorpay Standard Web Checkout Modal |
| **Offline Capability** | SQLite / SharedPreferences caching | Browser IndexedDB / LocalStorage | Browser IndexedDB / LocalStorage |

---

## 3. Responsive Web Layout Strategy

To honor **Rule 2** (*"The Stitch-generated UI is the visual source of truth"*) and **Rule 3** (*"Never redesign an existing Stitch screen unless explicitly instructed"*), the layout system does not alter the atomic UI components or cards. Instead, it wraps top-level screens within responsive scaffolding:

### 3.1 Adaptive Breakpoints
- **Mobile Mode (`width < 800px`):**
  - Renders the exact Stitch-designed bottom navigation bar.
  - Full-width mobile screen container optimized for single-hand touch interaction.
- **Desktop Mode (`width >= 800px`):**
  - Replaces bottom navigation bar with a dedicated 260px Left Sidebar.
  - Displays platform branding, active role status, navigation tiles, and quick logout.
  - Content screens expand naturally into the right workspace without horizontally stretching text or buttons into unreadable layouts.

### 3.2 Implemented Layouts
1. **`CustomerMainLayout`:**
   - Left Navigation: Home, Services Directory, My Bookings, Profile & Settings.
2. **`WorkerMainLayout`:**
   - Left Navigation: Dashboard, Job Requests, Earnings & Payouts, Profile & Guild.
3. **`AdminMainLayout`:**
   - Left Navigation: Coop Hub (Dashboard), Bookings Management, Services Directory, Coop Pool & Wallet, Member Directory.

---

## 4. Web Deep Linking & Route Protection (`RoleGuard`)

On the web, users have direct access to the browser address bar and can enter URLs arbitrarily (e.g. `/#/admin/home` or `/#/worker/dashboard`).

### 4.1 Threat Model
Without protection, typing `/#/admin/home` could display administrative screens to unauthenticated users or customers.

### 4.2 The `RoleGuard` Solution
All sensitive application routes in `lib/main.dart` are wrapped by `RoleGuard`:
```dart
'/customer/home': (context) => const RoleGuard(
      requiredRole: 'CUSTOMER',
      fallbackRoute: '/login/customer',
      child: CustomerMainLayout(),
    ),
'/worker/dashboard': (context) => const RoleGuard(
      requiredRole: 'WORKER',
      fallbackRoute: '/login/worker',
      child: WorkerMainLayout(),
    ),
'/admin/home': (context) => const RoleGuard(
      requiredRole: 'ADMIN',
      fallbackRoute: '/login/admin',
      child: AdminMainLayout(),
    ),
```

### 4.3 Validation Lifecycle
1. When mounted, `RoleGuard` queries `DI.authRepo.getCurrentUser()`.
2. If `null`, it renders an initial progress indicator and queues a redirect (`pushReplacementNamed`) to the corresponding login route.
3. If user exists, it verifies `DI.authRepo.getUserRole() == requiredRole`.
4. If role matches, it renders the protected screen (`child`).
5. If role mismatches, it redirects to the fallback login route.

---

## 5. Web Deployment on GitHub Pages

The application is configured for seamless deployment to GitHub Pages:
- **Base HREF:** `--base-href /ShramSetu/`
- **SPA Routing Fix:** `404.html` is synchronized with `index.html` so that direct browser navigation or refreshing a deep URL routes to the Flutter application rather than GitHub's 404 error page.
- **Asset Processing:** `.nojekyll` file prevents GitHub Pages from filtering out files starting with underscores (such as CanvasKit and shader binaries).
- **Public URL:** `https://deveshambekar.github.io/ShramSetu/`

---

## 6. Mobile Release Artifacts

- **Android Debug APK:** Compiled and verified at `build/app/outputs/flutter-apk/app-debug.apk`.
- **Target SDK:** 34 (Android 14 compliant).
- **Min SDK:** 21 (Android 5.0+ coverage).
- **Architecture:** `armeabi-v7a`, `arm64-v8a`, `x86_64`.
