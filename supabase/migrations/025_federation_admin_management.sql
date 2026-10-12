-- Migration 025: Federation Admin Management (Reassign, Remove, and Password Reset)
-- Empowers Super Admin to reassign federation admins to different federations,
-- remove admin access/scopes, and reset/change admin passwords securely.

-- ============================================================================
-- 1. Function: super_admin_reset_password
-- ============================================================================
CREATE OR REPLACE FUNCTION public.super_admin_reset_password(
    p_target_user_id UUID,
    p_new_password TEXT,
    p_require_change BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_actor_role TEXT;
    v_encrypted_pw TEXT;
    v_target_email TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_actor_role FROM public.users WHERE id = v_caller_id;
        IF v_actor_role IS NOT NULL AND v_actor_role != 'SUPER_ADMIN' THEN
            RAISE EXCEPTION 'Unauthorized: Super Admin role required to reset passwords (caller role: %)', v_actor_role;
        END IF;
    END IF;

    IF p_target_user_id IS NULL THEN
        RAISE EXCEPTION 'Target user ID is required';
    END IF;

    IF p_new_password IS NULL OR length(p_new_password) < 6 THEN
        RAISE EXCEPTION 'Password must be at least 6 characters long';
    END IF;

    -- Verify target user exists
    SELECT email INTO v_target_email FROM auth.users WHERE id = p_target_user_id;
    IF v_target_email IS NULL THEN
        SELECT email INTO v_target_email FROM public.users WHERE id = p_target_user_id;
    END IF;
    IF v_target_email IS NULL THEN
        RAISE EXCEPTION 'User not found with ID: %', p_target_user_id;
    END IF;

    v_encrypted_pw := crypt(p_new_password, gen_salt('bf'));

    -- Update auth.users credentials
    UPDATE auth.users
    SET encrypted_password = v_encrypted_pw,
        raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
            'requires_password_change', p_require_change
        ),
        updated_at = NOW()
    WHERE id = p_target_user_id;

    -- Update public.users flag
    UPDATE public.users
    SET requires_password_change = p_require_change,
        updated_at = NOW()
    WHERE id = p_target_user_id;

    -- Audit log
    INSERT INTO public.audit_logs (
        actor_id,
        actor_role,
        action,
        entity_type,
        entity_id,
        reason
    ) VALUES (
        COALESCE(v_caller_id, p_target_user_id),
        COALESCE(v_actor_role, 'SUPER_ADMIN'),
        'RESET_ADMIN_PASSWORD',
        'USER',
        p_target_user_id,
        'Super Admin reset federation admin password'
    );

    RETURN jsonb_build_object(
        'success', true,
        'user_id', p_target_user_id,
        'email', v_target_email,
        'message', 'Password reset successfully'
    );
END;
$$;

-- ============================================================================
-- 2. Function: super_admin_reassign_federation_admin
-- ============================================================================
CREATE OR REPLACE FUNCTION public.super_admin_reassign_federation_admin(
    p_user_id UUID,
    p_new_federation_id UUID,
    p_old_federation_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_actor_role TEXT;
    v_new_fed_name TEXT;
    v_admin_name TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_actor_role FROM public.users WHERE id = v_caller_id;
        IF v_actor_role IS NOT NULL AND v_actor_role != 'SUPER_ADMIN' THEN
            RAISE EXCEPTION 'Unauthorized: Super Admin role required to reassign federation admins (caller role: %)', v_actor_role;
        END IF;
    END IF;

    -- Verify target federation exists
    SELECT name INTO v_new_fed_name FROM public.federations WHERE id = p_new_federation_id;
    IF v_new_fed_name IS NULL THEN
        RAISE EXCEPTION 'Target federation not found with ID: %', p_new_federation_id;
    END IF;

    -- Fetch admin name
    SELECT full_name INTO v_admin_name FROM public.users WHERE id = p_user_id;

    -- Deactivate or delete old scope
    IF p_old_federation_id IS NOT NULL THEN
        DELETE FROM public.admin_federation_scope
        WHERE user_id = p_user_id AND federation_id = p_old_federation_id;
    ELSE
        DELETE FROM public.admin_federation_scope
        WHERE user_id = p_user_id;
    END IF;

    -- Insert new federation scope
    INSERT INTO public.admin_federation_scope (
        user_id,
        federation_id,
        scope_level,
        assigned_by,
        is_active,
        assigned_at
    ) VALUES (
        p_user_id,
        p_new_federation_id,
        'FEDERATION',
        v_caller_id,
        true,
        NOW()
    )
    ON CONFLICT (user_id, federation_id) DO UPDATE
    SET is_active = true,
        scope_level = 'FEDERATION',
        assigned_by = COALESCE(v_caller_id, admin_federation_scope.assigned_by),
        assigned_at = NOW();

    -- Ensure public.users role is FEDERATION_ADMIN and active
    UPDATE public.users
    SET role = 'FEDERATION_ADMIN',
        is_active = true,
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Update auth.users metadata with new federation_id
    UPDATE auth.users
    SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
        'federation_id', p_new_federation_id,
        'role', 'FEDERATION_ADMIN'
    ),
    updated_at = NOW()
    WHERE id = p_user_id;

    -- Audit log
    INSERT INTO public.audit_logs (
        actor_id,
        actor_role,
        action,
        entity_type,
        entity_id,
        federation_id,
        old_value,
        new_value,
        reason
    ) VALUES (
        COALESCE(v_caller_id, p_user_id),
        COALESCE(v_actor_role, 'SUPER_ADMIN'),
        'REASSIGN_FEDERATION_ADMIN',
        'ADMIN_FEDERATION_SCOPE',
        p_user_id,
        p_new_federation_id,
        jsonb_build_object('old_federation_id', p_old_federation_id),
        jsonb_build_object('new_federation_id', p_new_federation_id, 'federation_name', v_new_fed_name),
        'Super Admin reassigned Federation Admin'
    );

    RETURN jsonb_build_object(
        'success', true,
        'user_id', p_user_id,
        'admin_name', v_admin_name,
        'new_federation_id', p_new_federation_id,
        'federation_name', v_new_fed_name,
        'message', 'Federation Admin reassigned successfully'
    );
END;
$$;

-- ============================================================================
-- 3. Function: super_admin_remove_federation_admin
-- ============================================================================
CREATE OR REPLACE FUNCTION public.super_admin_remove_federation_admin(
    p_user_id UUID,
    p_federation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_actor_role TEXT;
    v_fed_name TEXT;
    v_admin_name TEXT;
    v_remaining_scopes INT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_actor_role FROM public.users WHERE id = v_caller_id;
        IF v_actor_role IS NOT NULL AND v_actor_role != 'SUPER_ADMIN' THEN
            RAISE EXCEPTION 'Unauthorized: Super Admin role required to remove federation admins (caller role: %)', v_actor_role;
        END IF;
    END IF;

    -- Fetch details for audit
    SELECT name INTO v_fed_name FROM public.federations WHERE id = p_federation_id;
    SELECT full_name INTO v_admin_name FROM public.users WHERE id = p_user_id;

    -- Remove the scope
    DELETE FROM public.admin_federation_scope
    WHERE user_id = p_user_id AND federation_id = p_federation_id;

    -- Check remaining scopes
    SELECT count(*) INTO v_remaining_scopes
    FROM public.admin_federation_scope
    WHERE user_id = p_user_id AND is_active = true;

    -- If no remaining scopes, demote role so they cannot access federation portals
    IF v_remaining_scopes = 0 THEN
        UPDATE public.users
        SET role = 'CUSTOMER',
            updated_at = NOW()
        WHERE id = p_user_id AND role = 'FEDERATION_ADMIN';

        UPDATE auth.users
        SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
            'role', 'CUSTOMER',
            'federation_id', null
        ),
        updated_at = NOW()
        WHERE id = p_user_id;
    END IF;

    -- Audit log
    INSERT INTO public.audit_logs (
        actor_id,
        actor_role,
        action,
        entity_type,
        entity_id,
        federation_id,
        old_value,
        reason
    ) VALUES (
        COALESCE(v_caller_id, p_user_id),
        COALESCE(v_actor_role, 'SUPER_ADMIN'),
        'REMOVE_FEDERATION_ADMIN',
        'ADMIN_FEDERATION_SCOPE',
        p_user_id,
        p_federation_id,
        jsonb_build_object('removed_from', v_fed_name, 'remaining_scopes', v_remaining_scopes),
        'Super Admin removed Federation Admin assignment'
    );

    RETURN jsonb_build_object(
        'success', true,
        'user_id', p_user_id,
        'admin_name', v_admin_name,
        'removed_federation_id', p_federation_id,
        'remaining_scopes', v_remaining_scopes,
        'message', 'Federation Admin removed successfully'
    );
END;
$$;

-- ============================================================================
-- 4. Permissions & Explicit RLS policies on admin_federation_scope
-- ============================================================================
GRANT EXECUTE ON FUNCTION public.super_admin_reset_password(UUID, TEXT, BOOLEAN) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.super_admin_reassign_federation_admin(UUID, UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.super_admin_remove_federation_admin(UUID, UUID) TO authenticated, service_role;

DROP POLICY IF EXISTS "Super admins can delete admin scopes" ON public.admin_federation_scope;
CREATE POLICY "Super admins can delete admin scopes" ON public.admin_federation_scope
    FOR DELETE USING (public.auth_user_role() = 'SUPER_ADMIN');

DROP POLICY IF EXISTS "Super admins can update admin scopes" ON public.admin_federation_scope;
CREATE POLICY "Super admins can update admin scopes" ON public.admin_federation_scope
    FOR UPDATE USING (public.auth_user_role() = 'SUPER_ADMIN');

DROP POLICY IF EXISTS "Super admins can insert admin scopes" ON public.admin_federation_scope;
CREATE POLICY "Super admins can insert admin scopes" ON public.admin_federation_scope
    FOR INSERT WITH CHECK (public.auth_user_role() = 'SUPER_ADMIN');
