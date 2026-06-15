-- Fix invite schema, add invitee_id, fix wake_permissions FKs
-- Version: 1.0.0
--
-- PROBLEMS FIXED:
-- 1. contact_invites had no invitee_id — can't tie accepted invite to user account
-- 2. contact_invites had no declined_at column
-- 3. wake_permissions FKs referenced auth.users — PostgREST joins returned null names
-- 4. accept_invite/decline_invite RPCs didn't set invitee_id / declined_at
-- 5. RPCs looked up by invite_token; new approach prefers id (UUID) lookup

-- ============================================
-- STEP 1: Add missing columns to contact_invites
-- ============================================

ALTER TABLE public.contact_invites
  ADD COLUMN IF NOT EXISTS invitee_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS declined_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_contact_invites_invitee_id ON public.contact_invites(invitee_id);

-- Backfill invitee_id for already-accepted invites using email match
UPDATE public.contact_invites ci
SET invitee_id = au.id
FROM auth.users au
WHERE LOWER(ci.invitee_email) = LOWER(au.email)
  AND ci.status = 'accepted'
  AND ci.invitee_id IS NULL;

-- ============================================
-- STEP 2: Fix wake_permissions FKs → public.users
-- (so PostgREST relationship embedding works)
-- ============================================

-- Drop existing FKs that reference auth.users
ALTER TABLE public.wake_permissions
  DROP CONSTRAINT IF EXISTS wake_permissions_granter_id_fkey;
ALTER TABLE public.wake_permissions
  DROP CONSTRAINT IF EXISTS wake_permissions_trustee_id_fkey;

-- Ensure all referenced users exist in public.users
INSERT INTO public.users (id, email, display_name, avatar_color, created_at)
SELECT au.id, au.email,
  COALESCE(au.raw_user_meta_data->>'display_name', au.email, 'User'),
  '#FF6B35', NOW()
FROM auth.users au
WHERE au.id IN (
  SELECT granter_id FROM public.wake_permissions
  UNION
  SELECT trustee_id FROM public.wake_permissions
)
ON CONFLICT (id) DO NOTHING;

-- Re-add FKs pointing at public.users
ALTER TABLE public.wake_permissions
  ADD CONSTRAINT wake_permissions_granter_id_fkey
    FOREIGN KEY (granter_id) REFERENCES public.users(id) ON DELETE CASCADE;
ALTER TABLE public.wake_permissions
  ADD CONSTRAINT wake_permissions_trustee_id_fkey
    FOREIGN KEY (trustee_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- ============================================
-- STEP 3: Update accept_invite RPC
-- Now accepts p_invite_id (UUID) as primary, p_invite_token as fallback
-- Sets invitee_id and accepted_at; creates wake_permission
-- ============================================

CREATE OR REPLACE FUNCTION public.accept_invite(
  p_invite_id   UUID    DEFAULT NULL,
  p_invite_token TEXT   DEFAULT NULL,
  p_user_id     UUID    DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_invite RECORD;
BEGIN
  -- Require at least one lookup key
  IF p_invite_id IS NULL AND p_invite_token IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'invite_id or invite_token required', 'debugCode', 'MISSING_LOOKUP_KEY');
  END IF;

  IF p_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'user_id required', 'debugCode', 'MISSING_USER_ID');
  END IF;

  -- Look up the invite
  SELECT * INTO v_invite
  FROM public.contact_invites
  WHERE status = 'pending'
    AND expires_at > NOW()
    AND (
      (p_invite_id    IS NOT NULL AND id            = p_invite_id)
      OR
      (p_invite_token IS NOT NULL AND invite_token  = p_invite_token)
    )
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Invite not found or not available for this account',
      'debugCode', 'INVITE_NOT_FOUND_FOR_USER'
    );
  END IF;

  -- Mark accepted
  UPDATE public.contact_invites
  SET status = 'accepted',
      accepted_at = NOW(),
      invitee_id = p_user_id
  WHERE id = v_invite.id;

  -- Ensure invitee exists in public.users (safety backfill)
  INSERT INTO public.users (id, email, display_name, avatar_color, created_at)
  SELECT au.id, au.email,
    COALESCE(au.raw_user_meta_data->>'display_name', au.email, 'User'),
    '#FF6B35', NOW()
  FROM auth.users au WHERE au.id = p_user_id
  ON CONFLICT (id) DO NOTHING;

  -- Create wake permission: granter = invitee (User B), trustee = inviter (User A)
  -- This means User A can wake User B
  INSERT INTO public.wake_permissions (granter_id, trustee_id, status)
  VALUES (p_user_id, v_invite.inviter_id, 'active')
  ON CONFLICT (granter_id, trustee_id)
  DO UPDATE SET status = 'active', updated_at = NOW();

  RETURN json_build_object(
    'success', true,
    'status', 'accepted',
    'inviteId', v_invite.id,
    'inviterId', v_invite.inviter_id,
    'message', 'Invite accepted'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 4: Update decline_invite RPC
-- Accepts p_invite_id (UUID) as primary, p_invite_token as fallback
-- Sets declined_at; no wake_permission created
-- ============================================

CREATE OR REPLACE FUNCTION public.decline_invite(
  p_invite_id    UUID    DEFAULT NULL,
  p_invite_token TEXT    DEFAULT NULL,
  p_user_id      UUID    DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_invite RECORD;
BEGIN
  IF p_invite_id IS NULL AND p_invite_token IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'invite_id or invite_token required');
  END IF;

  SELECT * INTO v_invite
  FROM public.contact_invites
  WHERE status = 'pending'
    AND (
      (p_invite_id    IS NOT NULL AND id           = p_invite_id)
      OR
      (p_invite_token IS NOT NULL AND invite_token = p_invite_token)
    )
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Invite not found or already processed');
  END IF;

  UPDATE public.contact_invites
  SET status = 'declined',
      declined_at = NOW(),
      invitee_id = p_user_id
  WHERE id = v_invite.id;

  RETURN json_build_object(
    'success', true,
    'status', 'declined',
    'inviteId', v_invite.id,
    'message', 'Invite declined'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 5: RLS — let invitees read their accepted/declined invites too
-- ============================================

DROP POLICY IF EXISTS "Invitees can view invites by id" ON public.contact_invites;
CREATE POLICY "Invitees can view invites by id"
  ON public.contact_invites FOR SELECT
  USING (invitee_id = auth.uid());
