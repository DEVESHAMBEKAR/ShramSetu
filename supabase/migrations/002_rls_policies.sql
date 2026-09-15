-- Enable Row Level Security (RLS) on all tables

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.worker_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.worker_verification ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.welfare_records ENABLE ROW LEVEL SECURITY;

-- Helper Function to get user role
CREATE OR REPLACE FUNCTION auth_user_role() RETURNS TEXT AS $$
  SELECT role FROM public.users WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- 1. Users Table
-- Users can read and update their own profiles
CREATE POLICY "Users can view their own profile" ON public.users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON public.users FOR UPDATE USING (auth.uid() = id);
-- Admins can view and manage all profiles
CREATE POLICY "Admins can view all users" ON public.users FOR SELECT USING (auth_user_role() = 'ADMIN');
CREATE POLICY "Admins can update all users" ON public.users FOR UPDATE USING (auth_user_role() = 'ADMIN');

-- 2. Services Table
-- Anyone authenticated can view active services
CREATE POLICY "Authenticated users can view services" ON public.services FOR SELECT USING (auth.uid() IS NOT NULL AND is_active = true);
-- Admins can manage services
CREATE POLICY "Admins can manage services" ON public.services FOR ALL USING (auth_user_role() = 'ADMIN');

-- 3. Skills Table
CREATE POLICY "Authenticated users can view skills" ON public.skills FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Admins can manage skills" ON public.skills FOR ALL USING (auth_user_role() = 'ADMIN');

-- 4. Workers Table
-- Anyone authenticated can view active/available workers
CREATE POLICY "Authenticated users can view workers" ON public.workers FOR SELECT USING (auth.uid() IS NOT NULL AND worker_status = 'ACTIVE');
-- Workers can view/update their own worker profile
CREATE POLICY "Workers can view own worker profile" ON public.workers FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Workers can update own worker profile" ON public.workers FOR UPDATE USING (auth.uid() = id);
-- Admins can manage all workers
CREATE POLICY "Admins can manage workers" ON public.workers FOR ALL USING (auth_user_role() = 'ADMIN');

-- 5. Worker Skills
CREATE POLICY "Authenticated users can view worker skills" ON public.worker_skills FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Workers can manage their own skills" ON public.worker_skills FOR ALL USING (auth.uid() = worker_id);
CREATE POLICY "Admins can manage worker skills" ON public.worker_skills FOR ALL USING (auth_user_role() = 'ADMIN');

-- 6. Worker Verification
CREATE POLICY "Workers can view own verification" ON public.worker_verification FOR SELECT USING (auth.uid() = worker_id);
CREATE POLICY "Workers can insert own verification" ON public.worker_verification FOR INSERT WITH CHECK (auth.uid() = worker_id);
CREATE POLICY "Workers can update own verification" ON public.worker_verification FOR UPDATE USING (auth.uid() = worker_id);
CREATE POLICY "Admins can manage verifications" ON public.worker_verification FOR ALL USING (auth_user_role() = 'ADMIN');

-- 7. Addresses
CREATE POLICY "Users can manage their own addresses" ON public.addresses FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Workers can view customer address for their bookings" ON public.addresses FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.bookings WHERE bookings.address_id = addresses.id AND bookings.worker_id = auth.uid())
);
CREATE POLICY "Admins can view all addresses" ON public.addresses FOR SELECT USING (auth_user_role() = 'ADMIN');

-- 8. Bookings
CREATE POLICY "Customers can view their own bookings" ON public.bookings FOR SELECT USING (auth.uid() = customer_id);
CREATE POLICY "Customers can create bookings" ON public.bookings FOR INSERT WITH CHECK (auth.uid() = customer_id);
CREATE POLICY "Customers can update their own bookings (e.g. cancel)" ON public.bookings FOR UPDATE USING (auth.uid() = customer_id);

CREATE POLICY "Workers can view assigned bookings" ON public.bookings FOR SELECT USING (auth.uid() = worker_id);
CREATE POLICY "Workers can update their assigned bookings (status)" ON public.bookings FOR UPDATE USING (auth.uid() = worker_id);

CREATE POLICY "Admins can view all bookings" ON public.bookings FOR SELECT USING (auth_user_role() = 'ADMIN');
CREATE POLICY "Admins can manage all bookings" ON public.bookings FOR UPDATE USING (auth_user_role() = 'ADMIN');

-- 9. Payments
CREATE POLICY "Customers can view their own payments" ON public.payments FOR SELECT USING (auth.uid() = customer_id);
CREATE POLICY "Workers can view their own payments" ON public.payments FOR SELECT USING (auth.uid() = worker_id);
CREATE POLICY "Admins can manage payments" ON public.payments FOR ALL USING (auth_user_role() = 'ADMIN');

-- 10. Reviews
CREATE POLICY "Anyone can view reviews" ON public.reviews FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Customers can create reviews for their bookings" ON public.reviews FOR INSERT WITH CHECK (auth.uid() = customer_id);
CREATE POLICY "Admins can manage reviews" ON public.reviews FOR ALL USING (auth_user_role() = 'ADMIN');

-- 11. Complaints
CREATE POLICY "Customers can view their own complaints" ON public.complaints FOR SELECT USING (auth.uid() = customer_id);
CREATE POLICY "Customers can create complaints" ON public.complaints FOR INSERT WITH CHECK (auth.uid() = customer_id);
CREATE POLICY "Workers can view complaints against them" ON public.complaints FOR SELECT USING (auth.uid() = worker_id);
CREATE POLICY "Workers can create complaints" ON public.complaints FOR INSERT WITH CHECK (auth.uid() = worker_id);
CREATE POLICY "Admins can manage complaints" ON public.complaints FOR ALL USING (auth_user_role() = 'ADMIN');

-- 12. Welfare Records
CREATE POLICY "Workers can view their own welfare records" ON public.welfare_records FOR SELECT USING (auth.uid() = worker_id);
CREATE POLICY "Admins can manage welfare records" ON public.welfare_records FOR ALL USING (auth_user_role() = 'ADMIN');
