# Database Relationships

## Core Entity Map

```mermaid
erDiagram
    auth_users ||--|| users : extends
    users ||--o| workers : "is a"
    users ||--o{ addresses : has
    
    workers ||--o{ worker_skills : has
    skills ||--o{ worker_skills : assigned_to
    
    workers ||--o| worker_verification : undergoes
    workers ||--o{ welfare_records : receives

    users ||--o{ bookings : "creates (as customer)"
    workers ||--o{ bookings : "assigned to"
    services ||--o{ bookings : "requested for"
    addresses ||--o{ bookings : "occurs at"
    
    bookings ||--o| payments : generates
    bookings ||--o| reviews : receives
    bookings ||--o{ complaints : "subject of"
```

## Key Foreign Keys
- `users.id` cascades from `auth.users.id`. When a user is deleted from Supabase Auth, their profile is automatically removed.
- `workers.id` cascades from `users.id`.
- `bookings` holds references to the `customer_id`, `worker_id`, `service_id`, and `address_id`.
- `payments`, `reviews`, and `complaints` all enforce a mandatory `booking_id` relationship. `reviews` enforces a `UNIQUE(booking_id)` constraint so a booking can only be reviewed once.
