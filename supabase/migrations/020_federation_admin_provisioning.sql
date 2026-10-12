-- ============================================================================
-- Migration 020: Federation Admin Provisioning and Mapping
-- Enables Super Admins to provision new Federation Admins with email/password logins,
-- and links existing admin ambekardevesh2@gmail.com to Pune Federation.
-- ============================================================================

-- 1. Ensure existing admin ambekardevesh2@gmail.com is assigned to Pune Federation
INSERT INTO public.admin_federation_scope (
    user_id,
    federation_id,
    scope_level,
    is_active
)
SELECT 
    u.id, 
    '11111111-0000-0000-0000-000000000001', 
    'FEDERATION', 
    true
FROM public.users u
WHERE u.email = 'ambekardevesh2@gmail.com'
ON CONFLICT (user_id, federation_id) DO UPDATE 
SET is_active = true,
    scope_level = 'FEDERATION',
    assigned_at = NOW();

-- 2. Stored Procedure: create_federation_admin
-- Callable only by SUPER_ADMIN. Atomically creates auth user, public.users entry,
-- federation scope mapping, and audit log.
CREATE OR REPLACE FUNCTION public.create_federation_admin(
    p_email TEXT,
    p_password TEXT,
    p_full_name TEXT,
    p_phone TEXT,
    p_federation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_actor_role TEXT;
    v_caller_id UUID;
    v_encrypted_pw TEXT;
    v_fed_name TEXT;
BEGIN
    v_caller_id := auth.uid();
    SELECT role INTO v_actor_role FROM public.users WHERE id = v_caller_id;

    -- Verify caller is SUPER_ADMIN
    IF v_actor_role <> 'SUPER_ADMIN' THEN
        RAISE EXCEPTION 'Unauthorized: Only SUPER_ADMIN can provision Federation Admins (caller has role: %)', COALESCE(v_actor_role, 'NONE');
    END IF;

    -- Validations
    IF p_email IS NULL OR TRIM(p_email) = '' THEN
        RAISE EXCEPTION 'Admin email is required';
    END IF;
    IF p_password IS NULL OR length(p_password) < 6 THEN
        RAISE EXCEPTION 'Password must be at least 6 characters';
    END IF;

    -- Verify federation exists
    SELECT name INTO v_fed_name FROM public.federations WHERE id = p_federation_id;
    IF v_fed_name IS NULL THEN
        RAISE EXCEPTION 'Federation not found with ID: %', p_federation_id;
    END IF;

    -- Check if user already exists in auth.users
    SELECT id INTO v_user_id FROM auth.users WHERE LOWER(email) = LOWER(TRIM(p_email));

    IF v_user_id IS NULL THEN
        v_user_id := gen_random_uuid();
        v_encrypted_pw := crypt(p_password, gen_salt('bf'));

        INSERT INTO auth.users (
            instance_id,
            id,
            aud,
            role,
            email,
            encrypted_password,
            email_confirmed_at,
            confirmation_token,
            recovery_token,
            email_change,
            email_change_token_new,
            phone_change,
            phone_change_token,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            v_user_id,
            'authenticated',
            'authenticated',
            LOWER(TRIM(p_email)),
            v_encrypted_pw,
            NOW(),
            '',
            '',
            '',
            '',
            '',
            '',
            '{"provider": "email", "providers": ["email"]}'::jsonb,
            jsonb_build_object(
                'full_name', p_full_name,
                'phone', p_phone,
                'role', 'FEDERATION_ADMIN',
                'federation_id', p_federation_id
            ),
            NOW(),
            NOW()
        );

        -- Also insert identity so GoTrue can authenticate email
        INSERT INTO auth.identities (
            id,
            user_id,
            provider_id,
            identity_data,
            provider,
            last_sign_in_at,
            created_at,
            updated_at
        ) VALUES (
            gen_random_uuid(),
            v_user_id,
            v_user_id::text,
            format('{"sub":"%s","email":"%s"}', v_user_id::text, LOWER(TRIM(p_email)))::jsonb,
            'email',
            NOW(),
            NOW(),
            NOW()
        );
    ELSE
        -- Update existing user credentials and confirmation
        UPDATE auth.users
        SET encrypted_password = crypt(p_password, gen_salt('bf')),
            email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
            confirmation_token = COALESCE(confirmation_token, ''),
            recovery_token = COALESCE(recovery_token, ''),
            email_change = COALESCE(email_change, ''),
            email_change_token_new = COALESCE(email_change_token_new, ''),
            phone_change = COALESCE(phone_change, ''),
            phone_change_token = COALESCE(phone_change_token, ''),
            raw_user_meta_data = raw_user_meta_data || jsonb_build_object(
                'full_name', p_full_name,
                'phone', p_phone,
                'role', 'FEDERATION_ADMIN',
                'federation_id', p_federation_id
            ),
            updated_at = NOW()
        WHERE id = v_user_id;

        -- Ensure identity exists
        INSERT INTO auth.identities (
            id,
            user_id,
            provider_id,
            identity_data,
            provider,
            last_sign_in_at,
            created_at,
            updated_at
        ) VALUES (
            gen_random_uuid(),
            v_user_id,
            v_user_id::text,
            format('{"sub":"%s","email":"%s"}', v_user_id::text, LOWER(TRIM(p_email)))::jsonb,
            'email',
            NOW(),
            NOW(),
            NOW()
        )
        ON CONFLICT (provider_id, provider) DO UPDATE
        SET identity_data = format('{"sub":"%s","email":"%s"}', v_user_id::text, LOWER(TRIM(p_email)))::jsonb,
            updated_at = NOW();
    END IF;

    -- Upsert public.users profile
    INSERT INTO public.users (id, email, phone, role, full_name, is_active)
    VALUES (
        v_user_id,
        LOWER(TRIM(p_email)),
        p_phone,
        'FEDERATION_ADMIN',
        p_full_name,
        true
    )
    ON CONFLICT (id) DO UPDATE
    SET role = 'FEDERATION_ADMIN',
        full_name = EXCLUDED.full_name,
        phone = COALESCE(EXCLUDED.phone, public.users.phone),
        is_active = true;

    -- Assign scope in admin_federation_scope
    INSERT INTO public.admin_federation_scope (
        user_id,
        federation_id,
        scope_level,
        assigned_by,
        is_active
    ) VALUES (
        v_user_id,
        p_federation_id,
        'FEDERATION',
        v_caller_id,
        true
    )
    ON CONFLICT (user_id, federation_id) DO UPDATE
    SET is_active = true,
        scope_level = 'FEDERATION',
        assigned_by = v_caller_id,
        assigned_at = NOW();

    -- Immutable audit log entry
    INSERT INTO public.audit_logs (
        actor_id,
        actor_role,
        action,
        entity_type,
        entity_id,
        federation_id,
        new_value,
        reason
    ) VALUES (
        v_caller_id,
        'SUPER_ADMIN',
        'PROVISION_FEDERATION_ADMIN',
        'USER',
        v_user_id::text,
        p_federation_id,
        jsonb_build_object(
            'email', LOWER(TRIM(p_email)),
            'full_name', p_full_name,
            'phone', p_phone,
            'role', 'FEDERATION_ADMIN',
            'federation_id', p_federation_id,
            'federation_name', v_fed_name
        ),
        'Federation Admin provisioned with login credentials by Super Admin'
    );

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_user_id,
        'email', LOWER(TRIM(p_email)),
        'federation_id', p_federation_id,
        'federation_name', v_fed_name
    );
END;
$$;

-- 3. Ensure RLS policies allow reading federation admin details
DROP POLICY IF EXISTS "Super admins can view all admin scopes" ON public.admin_federation_scope;
CREATE POLICY "Super admins can view all admin scopes" ON public.admin_federation_scope
    FOR SELECT USING (public.auth_user_role() IN ('SUPER_ADMIN', 'ADMIN'));
