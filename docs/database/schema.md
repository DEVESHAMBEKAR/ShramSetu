# Database Schema

The ShramSetu database is built on PostgreSQL via Supabase. It separates concerns between authentication and application profile logic.

## Users
Extends `auth.users` with ShramSetu roles.
- `id` (UUID): Matches `auth.users(id)`
- `role` (String): 'CUSTOMER', 'WORKER', 'ADMIN'
- `full_name` (String)
- `phone` (String, Unique)
- `email` (String, Unique)

## Workers
Worker-specific profile information.
- `id` (UUID): References `users(id)`
- `experience_years` (Int)
- `rating` (Numeric)
- `completed_jobs` (Int)
- `is_available` (Boolean)
- `worker_status` (String): 'ACTIVE', 'INACTIVE', 'PENDING_VERIFICATION', 'SUSPENDED'

## Services & Skills
- **services**: Master list of categories (e.g. Electrician).
- **skills**: Master list of specific skills (e.g. AC Repair).
- **worker_skills**: Many-to-Many mapping table.

## Bookings
The core transactional table.
- `customer_id` (UUID) -> users
- `worker_id` (UUID) -> workers
- `service_id` (UUID) -> services
- `address_id` (UUID) -> addresses
- `status` (String): Uses unified booking state machine ('pending', 'accepted', 'completed', etc.)
- `otp` (String): Verification code for starting jobs.

## Payments & Reviews
- **payments**: Associated with a booking. Tracks amount and status ('PENDING', 'PAID', 'REFUNDED').
- **reviews**: Associated with a booking (1:1). Contains 1-5 rating.

## Complaints & Welfare
- **complaints**: Allows tracking dispute resolutions.
- **welfare_records**: Tracks financial welfare contributions for cooperative members.
