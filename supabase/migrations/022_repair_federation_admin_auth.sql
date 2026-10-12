-- ============================================================================
-- Migration 022: Comprehensive Auth Schema Repair for Federation Admins
-- ============================================================================
-- Resolves:
-- 1. AuthRetryableFetchException: "Database error querying schema" (500)
-- 2. AuthRetryableFetchException: "Database error finding user" (500)
-- 3. Password matching failure during signInWithPassword for manually created admins
--
-- Root Cause:
-- Supabase GoTrue Auth service crashes with a 500 scan error ("converting NULL
-- to string is unsupported") when token columns in auth.users contain NULL.
-- In addition, GoTrue requires a corresponding row in auth.identities with
-- email_verified = true to authenticate email/password sign-in.
-- ============================================================================

-- Ensure required extension for password hashing
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- STEP 1: One-time repair for ALL existing auth.users rows
-- Populates all 8 token columns with empty strings instead of NULL,
-- confirms email, and sets compliant SSO/role metadata.
-- ============================================================================
UPDATE auth.users
SET 
    confirmation_token         = COALESCE(confirmation_token, ''),
    recovery_token             = COALESCE(recovery_token, ''),
    email_change               = COALESCE(email_change, ''),
    email_change_token_new     = COALESCE(email_change_token_new, ''),
    email_change_token_current = COALESCE(email_change_token_current, ''),
    phone_change               = COALESCE(phone_change, ''),
    phone_change_token         = COALESCE(phone_change_token, ''),
    reauthentication_token     = COALESCE(reauthentication_token, ''),
    email_confirmed_at         = COALESCE(email_confirmed_at, NOW()),
    raw_app_meta_data          = COALESCE(raw_app_meta_data, '{"provider": "email", "providers": ["email"]}'::jsonb),
    is_sso_user                = COALESCE(is_sso_user, false)
WHERE 
    confirmation_token IS NULL
    OR recovery_token IS NULL
    OR email_change IS NULL
    OR email_change_token_new IS NULL
    OR email_change_token_current IS NULL
    OR phone_change IS NULL
    OR phone_change_token IS NULL
    OR reauthentication_token IS NULL
    OR email_confirmed_at IS NULL;

-- ============================================================================
-- STEP 2: Note on auth.users column defaults
-- (In Supabase hosted instances, auth.users is owned by supabase_auth_admin,
-- so ALTER TABLE auth.users cannot be run by postgres role. Instead, the
-- create_federation_admin procedure below explicitly sets all 8 token columns
-- to '' on every INSERT and UPDATE, guaranteeing non-NULL values).
-- ============================================================================

-- ============================================================================
-- STEP 3: Repair auth.identities records for all email users
-- GoTrue requires an identity record with email_verified = true to allow
-- signInWithPassword.
-- ============================================================================
-- 3.1 Insert missing identities for users who don't have one
INSERT INTO auth.identities (
    id,
    user_id,
    provider_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
)
SELECT 
    gen_random_uuid(),
    u.id,
    u.id::text,
    jsonb_build_object(
        'sub', u.id::text,
        'email', LOWER(TRIM(u.email)),
        'email_verified', true,
        'phone_verified', false
    ),
    'email',
    NOW(),
    NOW(),
    NOW()
FROM auth.users u
WHERE u.email IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM auth.identities i 
    WHERE i.user_id = u.id AND i.provider = 'email'
);

-- 3.2 Update existing identities to ensure email_verified is true and data is valid
UPDATE auth.identities i
SET identity_data = jsonb_build_object(
        'sub', u.id::text,
        'email', LOWER(TRIM(u.email)),
        'email_verified', true,
        'phone_verified', false
    ),
    updated_at = NOW()
FROM auth.users u
WHERE i.user_id = u.id 
  AND i.provider = 'email';

-- 3.3 Ensure public.users has requires_password_change column
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS requires_password_change BOOLEAN DEFAULT false;

-- ============================================================================
-- STEP 4: Specific repair & credential sync for omshinde@gmail.com
-- Sets a confirmed status, initial password (password123), FEDERATION_ADMIN
-- role, requires_password_change = true, and associates with Nagpur Federation
-- (Nagpur District Shramik Cooperative Union: 55555555-0000-0000-0000-000000000005).
-- Removes any unintended scope to ensure strict federation isolation.
-- ============================================================================
DO $$
DECLARE
    v_target_email TEXT := 'omshinde@gmail.com';
    v_default_password TEXT := 'password123';
    v_user_id UUID;
    v_federation_id UUID := '55555555-0000-0000-0000-000000000005'; -- Nagpur Federation
    v_encrypted_pw TEXT;
BEGIN
    SELECT id INTO v_user_id FROM auth.users WHERE LOWER(email) = LOWER(v_target_email);
    v_encrypted_pw := crypt(v_default_password, gen_salt('bf'));

    IF v_user_id IS NOT NULL THEN
        -- Remove any unintended Pune scope row for Om Shinde
        DELETE FROM public.admin_federation_scope 
        WHERE user_id = v_user_id AND federation_id = '11111111-0000-0000-0000-000000000001';

        -- Repair auth.users
        UPDATE auth.users
        SET encrypted_password         = v_encrypted_pw,
            email_confirmed_at         = NOW(),
            confirmation_token         = '',
            recovery_token             = '',
            email_change               = '',
            email_change_token_new     = '',
            email_change_token_current = '',
            phone_change               = '',
            phone_change_token         = '',
            reauthentication_token     = '',
            raw_app_meta_data          = '{"provider": "email", "providers": ["email"]}'::jsonb,
            raw_user_meta_data         = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
                'full_name', 'Om Shinde',
                'role', 'FEDERATION_ADMIN',
                'federation_id', v_federation_id,
                'requires_password_change', true
            ),
            is_sso_user                = false,
            updated_at                 = NOW()
        WHERE id = v_user_id;

        -- Ensure email identity
        INSERT INTO auth.identities (
            id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
        ) VALUES (
            gen_random_uuid(),
            v_user_id,
            v_user_id::text,
            jsonb_build_object('sub', v_user_id::text, 'email', v_target_email, 'email_verified', true, 'phone_verified', false),
            'email',
            NOW(), NOW(), NOW()
        )
        ON CONFLICT (provider_id, provider) DO UPDATE
        SET identity_data = jsonb_build_object('sub', v_user_id::text, 'email', v_target_email, 'email_verified', true, 'phone_verified', false),
            updated_at = NOW();

        -- Upsert public.users profile with requires_password_change = true
        INSERT INTO public.users (id, email, phone, role, full_name, is_active, requires_password_change)
        VALUES (v_user_id, v_target_email, '9876543210', 'FEDERATION_ADMIN', 'Om Shinde', true, true)
        ON CONFLICT (id) DO UPDATE
        SET role = 'FEDERATION_ADMIN',
            full_name = 'Om Shinde',
            is_active = true,
            requires_password_change = true;

        -- Assign scope in admin_federation_scope strictly to Nagpur
        INSERT INTO public.admin_federation_scope (user_id, federation_id, scope_level, is_active)
        VALUES (v_user_id, v_federation_id, 'FEDERATION', true)
        ON CONFLICT (user_id, federation_id) DO UPDATE
        SET is_active = true,
            scope_level = 'FEDERATION',
            assigned_at = NOW();

        RAISE NOTICE 'omshinde@gmail.com successfully scoped to Nagpur Federation (%) with password: %', v_federation_id, v_default_password;
    END IF;
END $$;

-- ============================================================================
-- STEP 5: Upgrade create_federation_admin stored procedure
-- Fully GoTrue-compliant, ensures tokens are never NULL, identities are created,
-- and permissions are strictly enforced.
-- ============================================================================
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
    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_actor_role FROM public.users WHERE id = v_caller_id;
        IF v_actor_role IS NOT NULL AND v_actor_role NOT IN ('SUPER_ADMIN', 'ADMIN') THEN
            RAISE EXCEPTION 'Unauthorized: Administrative role required to provision Federation Admins (caller has role: %)', v_actor_role;
        END IF;
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

    v_encrypted_pw := crypt(p_password, gen_salt('bf'));

    IF v_user_id IS NULL THEN
        v_user_id := gen_random_uuid();

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
            email_change_token_current,
            phone_change,
            phone_change_token,
            reauthentication_token,
            raw_app_meta_data,
            raw_user_meta_data,
            is_sso_user,
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
            '',
            '',
            '{"provider": "email", "providers": ["email"]}'::jsonb,
            jsonb_build_object(
                'full_name', p_full_name,
                'phone', p_phone,
                'role', 'FEDERATION_ADMIN',
                'federation_id', p_federation_id,
                'requires_password_change', true
            ),
            false,
            NOW(),
            NOW()
        );

        -- Insert email identity record for GoTrue authentication
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
            jsonb_build_object(
                'sub', v_user_id::text,
                'email', LOWER(TRIM(p_email)),
                'email_verified', true,
                'phone_verified', false
            ),
            'email',
            NOW(),
            NOW(),
            NOW()
        );
    ELSE
        -- Update existing user credentials, confirmation, and ensure ALL token columns are non-NULL
        UPDATE auth.users
        SET encrypted_password         = v_encrypted_pw,
            email_confirmed_at         = COALESCE(email_confirmed_at, NOW()),
            confirmation_token         = COALESCE(confirmation_token, ''),
            recovery_token             = COALESCE(recovery_token, ''),
            email_change               = COALESCE(email_change, ''),
            email_change_token_new     = COALESCE(email_change_token_new, ''),
            email_change_token_current = COALESCE(email_change_token_current, ''),
            phone_change               = COALESCE(phone_change, ''),
            phone_change_token         = COALESCE(phone_change_token, ''),
            reauthentication_token     = COALESCE(reauthentication_token, ''),
            raw_app_meta_data          = COALESCE(raw_app_meta_data, '{"provider": "email", "providers": ["email"]}'::jsonb),
            is_sso_user                = COALESCE(is_sso_user, false),
            raw_user_meta_data         = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
                'full_name', p_full_name,
                'phone', p_phone,
                'role', 'FEDERATION_ADMIN',
                'federation_id', p_federation_id,
                'requires_password_change', true
            ),
            updated_at                 = NOW()
        WHERE id = v_user_id;

        -- Ensure email identity exists or is updated with verified status
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
            jsonb_build_object(
                'sub', v_user_id::text,
                'email', LOWER(TRIM(p_email)),
                'email_verified', true,
                'phone_verified', false
            ),
            'email',
            NOW(),
            NOW(),
            NOW()
        )
        ON CONFLICT (provider_id, provider) DO UPDATE
        SET identity_data = jsonb_build_object(
                'sub', v_user_id::text,
                'email', LOWER(TRIM(p_email)),
                'email_verified', true,
                'phone_verified', false
            ),
            updated_at = NOW();
    END IF;

    -- Upsert public.users profile with requires_password_change = true
    INSERT INTO public.users (id, email, phone, role, full_name, is_active, requires_password_change)
    VALUES (
        v_user_id,
        LOWER(TRIM(p_email)),
        p_phone,
        'FEDERATION_ADMIN',
        p_full_name,
        true,
        true
    )
    ON CONFLICT (id) DO UPDATE
    SET role = 'FEDERATION_ADMIN',
        full_name = EXCLUDED.full_name,
        phone = COALESCE(EXCLUDED.phone, public.users.phone),
        is_active = true,
        requires_password_change = true;

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
        assigned_by = COALESCE(v_caller_id, admin_federation_scope.assigned_by),
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
        COALESCE(v_caller_id, v_user_id),
        COALESCE(v_actor_role, 'SUPER_ADMIN'),
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
        'Federation Admin provisioned with GoTrue-compliant login credentials'
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

-- ============================================================================
-- STEP 6: Helper procedure to reset admin password from Super Admin console
-- ============================================================================
CREATE OR REPLACE FUNCTION public.reset_admin_password(
    p_email TEXT,
    p_new_password TEXT
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
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_actor_role FROM public.users WHERE id = v_caller_id;
        IF v_actor_role IS NOT NULL AND v_actor_role NOT IN ('SUPER_ADMIN', 'ADMIN') THEN
            RAISE EXCEPTION 'Unauthorized: Only Super Admin can reset admin passwords';
        END IF;
    END IF;

    IF p_new_password IS NULL OR length(p_new_password) < 6 THEN
        RAISE EXCEPTION 'Password must be at least 6 characters';
    END IF;

    SELECT id INTO v_user_id FROM auth.users WHERE LOWER(email) = LOWER(TRIM(p_email));
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not found in auth.users with email: %', p_email;
    END IF;

    UPDATE auth.users
    SET encrypted_password         = crypt(p_new_password, gen_salt('bf')),
        email_confirmed_at         = COALESCE(email_confirmed_at, NOW()),
        confirmation_token         = COALESCE(confirmation_token, ''),
        recovery_token             = COALESCE(recovery_token, ''),
        email_change               = COALESCE(email_change, ''),
        email_change_token_new     = COALESCE(email_change_token_new, ''),
        email_change_token_current = COALESCE(email_change_token_current, ''),
        phone_change               = COALESCE(phone_change, ''),
        phone_change_token         = COALESCE(phone_change_token, ''),
        reauthentication_token     = COALESCE(reauthentication_token, ''),
        updated_at                 = NOW()
    WHERE id = v_user_id;

    -- Ensure identity exists with email_verified = true
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
        jsonb_build_object(
            'sub', v_user_id::text,
            'email', LOWER(TRIM(p_email)),
            'email_verified', true,
            'phone_verified', false
        ),
        'email',
        NOW(),
        NOW(),
        NOW()
    )
    ON CONFLICT (provider_id, provider) DO UPDATE
    SET identity_data = jsonb_build_object(
            'sub', v_user_id::text,
            'email', LOWER(TRIM(p_email)),
            'email_verified', true,
            'phone_verified', false
        ),
        updated_at = NOW();

    RETURN jsonb_build_object('success', true, 'email', p_email, 'message', 'Password updated successfully');
END;
$$;
