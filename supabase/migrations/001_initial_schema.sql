-- Initial Schema for ShramSetu

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users (Profiles) Table
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('CUSTOMER', 'WORKER', 'ADMIN')),
  full_name TEXT NOT NULL,
  phone TEXT UNIQUE,
  email TEXT UNIQUE,
  avatar_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Services Table
CREATE TABLE public.services (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  category TEXT,
  icon_data TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Skills Table
CREATE TABLE public.skills (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Workers Table
CREATE TABLE public.workers (
  id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  bio TEXT,
  experience_years INTEGER DEFAULT 0,
  rating NUMERIC(3,2) DEFAULT 0.0,
  completed_jobs INTEGER DEFAULT 0,
  location_tag TEXT,
  insurance_amount TEXT,
  federation_id TEXT,
  is_union_gold BOOLEAN DEFAULT false,
  is_coop_master BOOLEAN DEFAULT false,
  is_available BOOLEAN DEFAULT false,
  worker_status TEXT DEFAULT 'PENDING_VERIFICATION' CHECK (worker_status IN ('ACTIVE', 'INACTIVE', 'PENDING_VERIFICATION', 'SUSPENDED')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Worker Skills (M2M)
CREATE TABLE public.worker_skills (
  worker_id UUID REFERENCES public.workers(id) ON DELETE CASCADE,
  skill_id UUID REFERENCES public.skills(id) ON DELETE CASCADE,
  PRIMARY KEY (worker_id, skill_id)
);

-- Worker Verification
CREATE TABLE public.worker_verification (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  worker_id UUID NOT NULL REFERENCES public.workers(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'NOT_SUBMITTED' CHECK (status IN ('NOT_SUBMITTED', 'PENDING', 'APPROVED', 'REJECTED')),
  submitted_at TIMESTAMP WITH TIME ZONE,
  reviewed_at TIMESTAMP WITH TIME ZONE,
  reviewed_by UUID REFERENCES public.users(id),
  rejection_reason TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Addresses
CREATE TABLE public.addresses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  label TEXT,
  address_line TEXT NOT NULL,
  area TEXT,
  city TEXT,
  state TEXT,
  postal_code TEXT,
  latitude NUMERIC(10,7),
  longitude NUMERIC(10,7),
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Bookings
CREATE TABLE public.bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id UUID NOT NULL REFERENCES public.users(id),
  worker_id UUID REFERENCES public.workers(id),
  service_id UUID NOT NULL REFERENCES public.services(id),
  address_id UUID REFERENCES public.addresses(id),
  scheduled_date DATE NOT NULL,
  scheduled_time TIME NOT NULL,
  base_amount NUMERIC(10,2) NOT NULL DEFAULT 0.0,
  labor_allowance NUMERIC(10,2) NOT NULL DEFAULT 0.0,
  distance_km NUMERIC(5,2),
  status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('pending', 'accepted', 'onTheWay', 'arrived', 'inProgress', 'completed', 'rejected', 'cancelled')),
  otp TEXT,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE
);

-- Payments
CREATE TABLE public.payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES public.users(id),
  worker_id UUID REFERENCES public.workers(id),
  amount NUMERIC(10,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PAID', 'FAILED', 'REFUNDED')),
  payment_method TEXT,
  transaction_reference TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Reviews
CREATE TABLE public.reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES public.users(id),
  worker_id UUID NOT NULL REFERENCES public.workers(id),
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(booking_id)
);

-- Complaints
CREATE TABLE public.complaints (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id),
  customer_id UUID NOT NULL REFERENCES public.users(id),
  worker_id UUID REFERENCES public.workers(id),
  subject TEXT NOT NULL,
  description TEXT NOT NULL,
  priority TEXT DEFAULT 'NORMAL' CHECK (priority IN ('LOW', 'NORMAL', 'HIGH', 'URGENT')),
  status TEXT DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'IN_REVIEW', 'RESOLVED', 'CLOSED')),
  resolution TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Welfare Records
CREATE TABLE public.welfare_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  worker_id UUID NOT NULL REFERENCES public.workers(id) ON DELETE CASCADE,
  amount NUMERIC(10,2) NOT NULL,
  type TEXT NOT NULL,
  status TEXT DEFAULT 'PENDING',
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Triggers for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_services_updated_at BEFORE UPDATE ON public.services FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_workers_updated_at BEFORE UPDATE ON public.workers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_worker_verification_updated_at BEFORE UPDATE ON public.worker_verification FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_addresses_updated_at BEFORE UPDATE ON public.addresses FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_bookings_updated_at BEFORE UPDATE ON public.bookings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_complaints_updated_at BEFORE UPDATE ON public.complaints FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Indexes for performance
CREATE INDEX idx_bookings_customer_id ON public.bookings(customer_id);
CREATE INDEX idx_bookings_worker_id ON public.bookings(worker_id);
CREATE INDEX idx_bookings_status ON public.bookings(status);
CREATE INDEX idx_workers_is_available ON public.workers(is_available);
CREATE INDEX idx_worker_verification_status ON public.worker_verification(status);
