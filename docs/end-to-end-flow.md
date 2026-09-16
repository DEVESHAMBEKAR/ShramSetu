# ShramSetu End-to-End User Journeys & System Flows

## 1. Overview

This document describes the complete, unbroken end-to-end user journeys connecting the **Customer**, **Worker (Artisan Partner)**, and **Cooperative Admin** within ShramSetu.

---

## 2. The Complete 8-Step Service Lifecycle

```mermaid
sequenceDiagram
    autonumber
    actor Customer
    participant App as ShramSetu App
    participant Store as SharedBookingStore
    actor Worker
    actor Admin
    participant Escrow as Escrow System

    Customer->>App: 1. Discovers artisan & creates booking
    App->>Store: createBooking(workerId, serviceId, time, amount)
    Store-->>Worker: Broadcast 'pending' booking via Realtime Stream
    Store-->>Admin: Broadcast new booking to Admin Dashboard

    Worker->>App: 2. Views Job Request & accepts
    App->>Store: updateBookingStatus(id, accepted)
    Store-->>Customer: Push notification ("Artisan confirmed booking")

    Customer->>App: 3. Authorizes payment
    App->>Escrow: createPaymentOrder() & verifyPayment()
    Escrow-->>Store: Lock funds in HELD state

    Worker->>App: 4. Starts travel
    App->>Store: updateBookingStatus(id, onTheWay)
    Store-->>Customer: Realtime tracking & ETA update

    Worker->>App: 5. Arrives at location
    App->>Store: updateBookingStatus(id, arrived)
    Store-->>Customer: Notification ("Artisan has arrived")

    Worker->>App: 6. Starts work & enters OTP
    App->>Store: updateBookingStatus(id, inProgress)

    Worker->>App: 7. Completes service
    App->>Store: updateBookingStatus(id, completed)
    Store->>Escrow: releaseEscrow(id) -> Funds released to Worker wallet
    Store-->>Customer: Prompt Review & Rating Modal

    Customer->>App: 8. Submits 5-star rating & comment
    App->>Store: submitReview(rating, comment)
    Store-->>Worker: Rating recorded, profile rating recalculated
    Store-->>Admin: Dashboard Fair Work Index updated
```

---

## 3. Journey Details by Role

### 3.1 Customer Journey
1. **Onboarding & Authentication:**
   - Enters mobile number -> receives 6-digit OTP -> enters OTP.
   - Profile check: Existing customer with complete profile goes directly to `/customer/home`. New customer completes quick onboarding (Name, Address) and proceeds.
2. **Discovery & Matching:**
   - Explores categories (Plumbing, Electrical, Cleaning, Carpentry).
   - FairMatch v1 ranks artisans using explainable criteria (Proximity, Fair Work Distribution, Skill Badge, Coop Rating).
   - Customer selects artisan and chooses date & time.
3. **Tracking & Service Experience:**
   - Live stream updates as artisan status advances: `accepted` $\to$ `onTheWay` $\to$ `arrived` $\to$ `inProgress` $\to$ `completed`.
   - Customer provides arrival OTP to verify physical arrival.
4. **Completion & Feedback:**
   - Once completed, customer rates artisan (1 to 5 stars) with optional feedback.

### 3.2 Worker (Artisan Partner) Journey
1. **Authentication & Shift Toggle:**
   - Logs in with phone and OTP.
   - Toggles availability status (Online / Offline).
2. **Job Request Reception:**
   - Real-time stream receives new job request with customer location, tariff breakdown, and distance.
   - Accepts request.
3. **Service Execution:**
   - Updates status: `onTheWay` $\to$ `arrived` $\to$ `inProgress` $\to$ `completed`.
4. **Guaranteed Payout:**
   - Completion immediately releases escrow funds into the worker's earnings wallet without administrative delays.

### 3.3 Admin Journey
1. **Coop Hub Dashboard:**
   - Observes platform health: active bookings, verified artisans, escrow pool locked, cooperative welfare fund balance.
2. **Bookings Oversight:**
   - Real-time monitor of all marketplace bookings across Pune district.
3. **Verification & Moderation:**
   - Reviews worker KYC documents, approves/rejects credentials.
   - Moderates reviews and resolves customer complaints.
