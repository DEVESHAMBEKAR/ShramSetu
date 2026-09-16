# Supabase Realtime Booking Updates Architecture

**Project:** ShramSetu – AI-Powered Cooperative Gig Worker Service Marketplace  
**Module:** Core Booking & Synchronization Engine  
**Author:** Antigravity  
**Date:** September 16, 2026  

---

## 1. Purpose
In a gig worker marketplace, booking state transitions must synchronize seamlessly and instantaneously between Customer, Worker, and Admin. Previously, status changes required manual pull-to-refresh or relied on client-side polling timers. 

This engine implements **Supabase Realtime (PostgreSQL Changes)** over secure WebSockets, enabling immediate, automated synchronization without polling or direct database subscriptions in UI widgets.

---

## 2. Architectural Design

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter UI Layer                       │
│  CustomerLiveTrackingScreen | CustomerBookingsScreen        │
│  WorkerDashboardScreen      | WorkerJobRequestsScreen       │
│  AdminBookingsScreen        | AdminDashboardScreen          │
└──────────────────────────────▲──────────────────────────────┘
                               │ Stream<T> / StreamSubscription
┌──────────────────────────────┴──────────────────────────────┐
│                      Repository Layer                       │
│  ICustomerRepository: watchCustomerBookings, watchBooking    │
│  IWorkerRepository:   watchWorkerBookings                   │
│  IAdminRepository:    watchBookings                         │
└──────────────────────────────▲──────────────────────────────┘
                               │
┌──────────────────────────────┴──────────────────────────────┐
│             Realtime Service (Abstraction)                  │
│               BookingRealtimeService                        │
│  - Channel lifecycle & deduplication                        │
│  - PostgresChanges filtering & row parsing                  │
│  - Clean unsubscribe & error handling                       │
└──────────────────────────────▲──────────────────────────────┘
                               │ WebSocket
┌──────────────────────────────┴──────────────────────────────┐
│                    Supabase Realtime                        │
│           PostgreSQL `bookings` (RLS Enforced)              │
└─────────────────────────────────────────────────────────────┘
```

### Strict Architectural Boundaries:
- **No Direct UI Queries:** Widgets never call `supabase.channel()`, `supabase.from()`, or `onPostgresChanges()`.
- **Clean Contracts:** UI screens consume standard Dart `Stream<T>` provided by repository interfaces (`ICustomerRepository`, `IWorkerRepository`, `IAdminRepository`).
- **Relational Integrity:** Realtime Postgres Changes only push mutated raw columns of `public.bookings`. When an event occurs, the repository transparently re-emits hydrated models containing joined relational data (`users`, `services`, `workers`, `addresses`).

---

## 3. Database & Supabase Configuration

### A. Replica Identity
To ensure that `UPDATE` and `DELETE` events delivered through WebSockets contain full column data (and not merely the primary key), `REPLICA IDENTITY FULL` is enabled on `public.bookings`:

```sql
ALTER TABLE public.bookings REPLICA IDENTITY FULL;
```

### B. Supabase Realtime Publication
`public.bookings` is explicitly registered into the `supabase_realtime` publication:

```sql
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'bookings'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
  END IF;
END $$;
```
*(Reference: `supabase/migrations/008_realtime_bookings.sql`)*

---

## 4. Channel Strategy & Security

| Role | Channel Pattern | Filter | Security & RLS Enforcement |
| :--- | :--- | :--- | :--- |
| **Customer** | `customer_bookings_<customerId>_<timestamp>` | `table: 'bookings', filter: 'customer_id=eq.<uid>'` | PostgreSQL RLS policy `"Customers can view their own bookings"` ensures customers only receive events for their own bookings. |
| **Worker** | `worker_bookings_<workerId>_<timestamp>` | `table: 'bookings', filter: 'worker_id=eq.<uid>'` | PostgreSQL RLS policy `"Workers can view assigned bookings"` restricts worker change notifications strictly to jobs assigned to their user ID. |
| **Single Job**| `booking_<bookingId>_<timestamp>` | `table: 'bookings', filter: 'id=eq.<bookingId>'` | Evaluates caller's role against RLS. |
| **Admin** | `admin_bookings_<timestamp>` | `table: 'bookings'` | PostgreSQL RLS policy `"Admins can view all bookings"` (`auth_user_role() = 'ADMIN'`). |

---

## 5. Booking Lifecycle Flow & Event Propagation

```
Customer creates Booking
       │ (INSERT `status = 'pending'`)
       ▼
Supabase Realtime Broadcasts Event
       │
       ├──────────────────────────────────────────────┐
       ▼                                              ▼
Worker receives Realtime Event             Admin receives Realtime Event
(Job Request & Dashboard auto-refresh)     (Bookings console auto-updates)
       │
       ▼ Worker taps "Accept"
(UPDATE `status = 'accepted'`)
       │
       ├──────────────────────────────────────────────┐
       ▼                                              ▼
Customer receives Realtime Event           Admin receives Realtime Event
(Live tracker advances to "Accepted")      (Status pill turns green)
       │
       ▼ Worker advances through lifecycle
`onTheWay` ➔ `arrived` ➔ `inProgress` ➔ `completed`
       │
       ▼
Customer Live Tracking step indicator advances in real time without refreshing.
```

---

## 6. Status Mapping Standard

PostgreSQL check constraint:
```sql
CHECK (status IN ('pending', 'accepted', 'onTheWay', 'arrived', 'inProgress', 'completed', 'rejected', 'cancelled'))
```

Standardized across Dart code in `BookingStatus`:
- `status.toDbString()`: Returns exact camelCase DB string (`'onTheWay'`, `'inProgress'`, etc.).
- `BookingStatus.fromDbString(val)`: Case-insensitive and robust parser with fallback to `BookingStatus.pending`.

---

## 7. Lifecycle, Error Handling & Cleanup

1. **Subscription Cleanup:**
   - Every UI screen that subscribes to a stream holds a `StreamSubscription`.
   - In `dispose()`, `subscription.cancel()` is executed immediately.
   - When the stream's listener count drops to 0, `BookingRealtimeService` executes `_client.removeChannel(channel)` to close the WebSocket channel and release resources.
2. **Network Resilience:**
   - Supabase Realtime automatically reconnects on socket drop.
   - If a temporary network interruption occurs, the repository stream catches the event and emits gracefully without unhandled exceptions.
   - Pull-to-refresh remains functional as a manual fallback.

---

## 8. Testing & Validation

### Automated Unit & Stream Tests
Located at `app/test/booking_realtime_test.dart`:
1. `BookingStatus DB Serialization & Deserialization` (Enum ➔ DB string, robust parsing).
2. `BookingRealtimeEvent Model & Event Types` (INSERT, UPDATE, DELETE parsing).
3. `Customer Repository Realtime Streams` (`watchCustomerBookings`, `watchBookingDetails`).
4. `Worker Repository Realtime Streams` (`watchWorkerBookings`, `updateBookingStatus`).
5. `Admin Repository Realtime Streams` (`watchBookings`, `updateBookingStatus`).

Run via:
```bash
flutter test
```

---

## 9. Limitations & Future Scope
- Realtime presence (worker GPS live map pins) is intentionally out of scope for this milestone (no Google Maps / GPS tracking).
- Offline-first local database caching (e.g. Hive/Drift) is not implemented per single-source-of-truth guidelines. Supabase PostgreSQL remains the authoritative source of truth.
