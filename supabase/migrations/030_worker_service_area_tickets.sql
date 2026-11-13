-- Migration 030: Worker Service Area Tickets & Territorial Jurisdiction Management
-- Tracks requests by verified artisans to alter or expand their operating areas (max 3)
-- Requires Federation Admin or Super Admin review and approval before updates are applied to public.workers

CREATE TABLE IF NOT EXISTS public.worker_area_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID NOT NULL REFERENCES public.workers(id) ON DELETE CASCADE,
    federation_id UUID REFERENCES public.federations(id) ON DELETE SET NULL,
    current_areas TEXT[] DEFAULT '{}',
    requested_areas TEXT[] NOT NULL DEFAULT '{}',
    reason TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    admin_remarks TEXT,
    resolved_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_worker_area_tickets_worker ON public.worker_area_tickets(worker_id);
CREATE INDEX IF NOT EXISTS idx_worker_area_tickets_federation ON public.worker_area_tickets(federation_id);
CREATE INDEX IF NOT EXISTS idx_worker_area_tickets_status ON public.worker_area_tickets(status);

-- Enable Row Level Security (RLS)
ALTER TABLE public.worker_area_tickets ENABLE ROW LEVEL SECURITY;

-- Policy 1: Authenticated workers can view their own tickets; admins can view all or federation-scoped tickets
CREATE POLICY "Users can view relevant area tickets"
    ON public.worker_area_tickets
    FOR SELECT
    TO authenticated
    USING (
        worker_id IN (SELECT id FROM public.workers WHERE user_id = auth.uid())
        OR EXISTS (
            SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('ADMIN', 'SUPER_ADMIN')
        )
    );

-- Policy 2: Workers can create area tickets for their own worker record
CREATE POLICY "Workers can create own area tickets"
    ON public.worker_area_tickets
    FOR INSERT
    TO authenticated
    WITH CHECK (
        worker_id IN (SELECT id FROM public.workers WHERE user_id = auth.uid())
    );

-- Policy 3: Administrators can update area tickets (approve or reject)
CREATE POLICY "Admins can update area tickets"
    ON public.worker_area_tickets
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('ADMIN', 'SUPER_ADMIN')
        )
    );

