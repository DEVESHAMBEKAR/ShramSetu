-- ============================================================================
-- Migration 026: Automatic Customer Federation Assignment Based on Location
-- 1. Adds federation_id and federation_ref_id to public.users table.
-- 2. Adds federation_id and district to public.addresses table.
-- 3. Implements public.resolve_federation_from_location() to map coordinates/district/city to federations.
-- 4. Triggers automatic federation assignment when customer location is saved or updated.
-- 5. Backfills existing registered customers to their appropriate federation.
-- 6. Enforces strict federation isolation so Federation Admins can see customers assigned to their jurisdiction.
-- ============================================================================

-- 1. Add federation columns to public.users
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS federation_id UUID REFERENCES public.federations(id) ON UPDATE CASCADE ON DELETE SET NULL;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS federation_ref_id UUID REFERENCES public.federations(id) ON UPDATE CASCADE ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_users_federation_id ON public.users(federation_id);
CREATE INDEX IF NOT EXISTS idx_users_federation_ref_id ON public.users(federation_ref_id);

-- 2. Add federation and district columns to public.addresses
ALTER TABLE public.addresses ADD COLUMN IF NOT EXISTS district TEXT;
ALTER TABLE public.addresses ADD COLUMN IF NOT EXISTS federation_id UUID REFERENCES public.federations(id) ON UPDATE CASCADE ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_addresses_district ON public.addresses(district);
CREATE INDEX IF NOT EXISTS idx_addresses_federation_id ON public.addresses(federation_id);

-- 3. Helper Function: Resolve Federation ID based on location text, district, city, state, or address
CREATE OR REPLACE FUNCTION public.resolve_federation_from_location(
    p_district TEXT DEFAULT NULL,
    p_city TEXT DEFAULT NULL,
    p_state TEXT DEFAULT NULL,
    p_location TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_fed_id UUID;
    v_combined TEXT;
BEGIN
    v_combined := LOWER(COALESCE(p_location, '') || ' ' || COALESCE(p_district, '') || ' ' || COALESCE(p_city, '') || ' ' || COALESCE(p_state, ''));

    -- 3a. Direct district or city match against federations table
    IF p_district IS NOT NULL AND TRIM(p_district) <> '' THEN
        SELECT id INTO v_fed_id
        FROM public.federations
        WHERE LOWER(district) = LOWER(TRIM(p_district)) OR LOWER(city) = LOWER(TRIM(p_district))
        LIMIT 1;
        IF v_fed_id IS NOT NULL THEN
            RETURN v_fed_id;
        END IF;
    END IF;

    IF p_city IS NOT NULL AND TRIM(p_city) <> '' THEN
        SELECT id INTO v_fed_id
        FROM public.federations
        WHERE LOWER(city) = LOWER(TRIM(p_city)) OR LOWER(district) = LOWER(TRIM(p_city))
        LIMIT 1;
        IF v_fed_id IS NOT NULL THEN
            RETURN v_fed_id;
        END IF;
    END IF;

    -- 3b. Keyword matching on combined location string
    IF v_combined ~* 'nashik|nsk|satpur|panchavati|college road' THEN
        SELECT id INTO v_fed_id FROM public.federations WHERE id = '22222222-0000-0000-0000-000000000002';
        IF v_fed_id IS NOT NULL THEN RETURN v_fed_id; END IF;
    ELSIF v_combined ~* 'nagpur|ngp|sitabuldi|dharampeth|sadar' THEN
        SELECT id INTO v_fed_id FROM public.federations WHERE id = '55555555-0000-0000-0000-000000000005';
        IF v_fed_id IS NOT NULL THEN RETURN v_fed_id; END IF;
    ELSIF v_combined ~* 'mumbai|thane|navi mumbai|andheri|bandra|dadar|mmr|vashi' THEN
        SELECT id INTO v_fed_id FROM public.federations WHERE id = '33333333-0000-0000-0000-000000000003';
        IF v_fed_id IS NOT NULL THEN RETURN v_fed_id; END IF;
    ELSIF v_combined ~* 'sambhajinagar|aurangabad|csn|waluj|cidco' THEN
        SELECT id INTO v_fed_id FROM public.federations WHERE id = '44444444-0000-0000-0000-000000000004';
        IF v_fed_id IS NOT NULL THEN RETURN v_fed_id; END IF;
    ELSIF v_combined ~* 'hyderabad|secunderabad|gandhi bhawan|telangana' THEN
        SELECT id INTO v_fed_id FROM public.federations WHERE id = '66666666-0000-0000-0000-000000000006' OR LOWER(name) LIKE '%hyderabad%';
        IF v_fed_id IS NOT NULL THEN RETURN v_fed_id; END IF;
    ELSIF v_combined ~* 'pune|kothrud|hadapsar|hinjewadi|baner|wakad|pimpri|deccan|swargate' THEN
        SELECT id INTO v_fed_id FROM public.federations WHERE id = '11111111-0000-0000-0000-000000000001';
        IF v_fed_id IS NOT NULL THEN RETURN v_fed_id; END IF;
    END IF;

    -- 3c. Safe baseline fallback: Pune District Labour Cooperative Federation
    SELECT id INTO v_fed_id FROM public.federations WHERE id = '11111111-0000-0000-0000-000000000001';
    IF v_fed_id IS NULL THEN
        SELECT id INTO v_fed_id FROM public.federations ORDER BY created_at ASC LIMIT 1;
    END IF;

    RETURN v_fed_id;
END;
$$;

-- 4. Trigger Function: Automatically assign federation to address and user
CREATE OR REPLACE FUNCTION public.handle_address_federation_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_resolved_fed_id UUID;
    v_user_role TEXT;
BEGIN
    -- Resolve federation for this address if not already explicitly provided
    IF NEW.federation_id IS NULL THEN
        NEW.federation_id := public.resolve_federation_from_location(
            NEW.district,
            NEW.city,
            NEW.state,
            COALESCE(NEW.area, NEW.address_line)
        );
    END IF;

    -- Determine user role
    SELECT role INTO v_user_role FROM public.users WHERE id = NEW.user_id;

    -- If this address belongs to a customer, synchronize the customer's federation assignment
    IF v_user_role = 'CUSTOMER' THEN
        -- If it's a default address, or the customer doesn't have a federation assigned yet, update users record
        UPDATE public.users
        SET federation_id = NEW.federation_id,
            federation_ref_id = NEW.federation_id,
            updated_at = NOW()
        WHERE id = NEW.user_id;
    END IF;

    RETURN NEW;
END;
$$;

-- Attach trigger to public.addresses table
DROP TRIGGER IF EXISTS trg_assign_address_federation ON public.addresses;
CREATE TRIGGER trg_assign_address_federation
    BEFORE INSERT OR UPDATE ON public.addresses
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_address_federation_assignment();

-- 5. RPC Function: Explicitly assign or update customer federation by location
CREATE OR REPLACE FUNCTION public.assign_customer_federation(
    p_user_id UUID,
    p_district TEXT DEFAULT NULL,
    p_city TEXT DEFAULT NULL,
    p_state TEXT DEFAULT NULL,
    p_location TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_target_fed_id UUID;
    v_fed_name TEXT;
    v_actor_role TEXT;
BEGIN
    -- Authorize: Customer themselves or Administrator
    v_actor_role := public.auth_user_role();
    IF auth.uid() <> p_user_id AND v_actor_role NOT IN ('SUPER_ADMIN', 'ADMIN', 'FEDERATION_ADMIN') THEN
        RAISE EXCEPTION 'Access Denied: You cannot assign federations to another customer';
    END IF;

    -- Resolve federation ID
    v_target_fed_id := public.resolve_federation_from_location(p_district, p_city, p_state, p_location);

    IF v_target_fed_id IS NULL THEN
        RAISE EXCEPTION 'Could not resolve a cooperative federation for the specified location';
    END IF;

    SELECT name INTO v_fed_name FROM public.federations WHERE id = v_target_fed_id;

    -- Update customer user record
    UPDATE public.users
    SET federation_id = v_target_fed_id,
        federation_ref_id = v_target_fed_id,
        updated_at = NOW()
    WHERE id = p_user_id AND role = 'CUSTOMER';

    RETURN jsonb_build_object(
        'success', true,
        'user_id', p_user_id,
        'federation_id', v_target_fed_id,
        'federation_name', v_fed_name
    );
END;
$$;

-- 6. Backfill existing customer records
DO $$
DECLARE
    rec RECORD;
    v_fed UUID;
BEGIN
    FOR rec IN SELECT id FROM public.users WHERE role = 'CUSTOMER' LOOP
        -- Attempt to resolve from customer's latest address
        SELECT public.resolve_federation_from_location(a.district, a.city, a.state, COALESCE(a.area, a.address_line))
        INTO v_fed
        FROM public.addresses a
        WHERE a.user_id = rec.id
        ORDER BY a.is_default DESC, a.created_at DESC
        LIMIT 1;

        IF v_fed IS NULL THEN
            v_fed := '11111111-0000-0000-0000-000000000001'::uuid;
        END IF;

        UPDATE public.users
        SET federation_id = v_fed,
            federation_ref_id = v_fed
        WHERE id = rec.id AND (federation_id IS NULL OR federation_ref_id IS NULL);
    END LOOP;
END $$;

-- 7. Federation Admin Customer Scope Policy
-- Federation Admins can view customer profiles and addresses within their assigned federation jurisdiction
DROP POLICY IF EXISTS "Federation admins can view scoped customers" ON public.users;
CREATE POLICY "Federation admins can view scoped customers" ON public.users
    FOR SELECT USING (
        auth.uid() = id
        OR public.auth_user_role() IN ('SUPER_ADMIN', 'ADMIN')
        OR (
            public.auth_user_role() = 'FEDERATION_ADMIN'
            AND (
                federation_id = ANY(public.get_admin_federation_ids())
                OR federation_ref_id = ANY(public.get_admin_federation_ids())
            )
        )
    );
