# Row Level Security (RLS)

All business data tables in ShramSetu have Row Level Security enabled. 

## Role-Based Access Control (RBAC)
We utilize a combination of standard RLS (`auth.uid()`) and a database role check.
The `users.role` field dictates elevated permissions.

```sql
-- Helper Function
CREATE OR REPLACE FUNCTION auth_user_role() RETURNS TEXT AS $$
  SELECT role FROM public.users WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;
```

## Policy Breakdown

### Customers
- **Profile:** Can `SELECT` and `UPDATE` where `id = auth.uid()`.
- **Bookings:** Can `INSERT`, `SELECT`, and `UPDATE` where `customer_id = auth.uid()`.
- **Addresses:** Can manage where `user_id = auth.uid()`.
- **Reviews & Complaints:** Can `INSERT` and `SELECT` where `customer_id = auth.uid()`.

### Workers
- **Worker Profile:** Can `SELECT` and `UPDATE` where `id = auth.uid()`.
- **Bookings:** Can `SELECT` and `UPDATE` (e.g. status changes) where `worker_id = auth.uid()`.
- **Verification:** Can `INSERT` and `UPDATE` their own records.
- **Addresses:** Can `SELECT` a customer address *only if* they have an assigned booking at that address.

### Admins
- **Global Access:** Admins have a blanket policy `auth_user_role() = 'ADMIN'` allowing them to `SELECT`, `UPDATE`, and `DELETE` on all major tables including `users`, `workers`, `bookings`, `complaints`, `payments`, and `welfare_records`.
- **Security Note:** Service-role keys are never distributed. Admins must authenticate via Supabase Auth and have their `users.role` explicitly set to `ADMIN` by a superuser.
