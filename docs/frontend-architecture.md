# ShramSetu Frontend Architecture

## Overview
The ShramSetu Flutter frontend follows a decoupled, feature-based architecture pattern designed to evolve from local mock data towards a remote Supabase backend.

## Structure
The codebase uses a feature-based folder structure inside `lib/`:
- `core/`: Shared models (e.g., `BookingStatus`), theme (colors, typography), and utilities.
- `features/`: The main modules.
  - `auth/`: Authentication UI and state.
  - `customer/`: Customer-specific flows (service selection, booking creation).
  - `worker/`: Worker-specific flows (KYC verification, job acceptance, execution).
  - `admin/`: Cooperative admin console (dispute management, statistics, queue control).
  - `booking/`: Unified booking flows and status screens.

## Data Layer
Each feature has a `data/` layer composed of:
1. **Models**: Defines data entities.
2. **Repositories (Interfaces/Implementations)**: Currently, the app uses `MockCustomerRepository`, `MockWorkerRepository`, and `MockAdminRepository` based on `ChangeNotifier`. These manage local mock state and will later be replaced by Supabase-backed repositories implementing shared abstract interfaces.

## State Management
State is currently managed using a simple `ChangeNotifier` pattern inside singletons.
As the app scales and connects to Supabase, this will naturally transition into more robust state management (e.g., Riverpod or Bloc), while the underlying UI remains fully untouched.

## Design System
The UI strictly adheres to the Stitch-generated design definitions.
Themes are centrally managed in `core/theme/` (using standard Material 3 color schemes and typography).

## Mock Data Architecture
- **Avoided raw List<Map>** in favor of strongly-typed models (e.g., `Worker`, `UnifiedBooking`).
- The `BookingStatus` state machine is centralized in `core/models/booking_status.dart`.
