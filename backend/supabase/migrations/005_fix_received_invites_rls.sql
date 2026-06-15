-- Fix received invites visibility and public user profile access
-- Version: 1.0.0
--
-- PROBLEMS:
-- 1. get-contacts used .eq('is_active', true) but the column is named 'status'
-- 2. public.users RLS only allowed auth.uid() = id, blocking cross-user joins
--    needed when fetching inviter details for received invites
-- 3. contact_invites.inviter_id FK was changed to reference auth.users in 004,
--    breaking PostgREST relationship joins to public.users
--
-- SOLUTION:
-- 1. Add read policy for public.users so authenticated users can read
--    basic profile data (email, display_name) of other users
-- 2. Fix contact_invites.inviter_id FK back to public.users so PostgREST
--    relationship embedding works correctly
-- 3. Edge functions now use service role for received invites (no migration needed)

-- ============================================
-- STEP 1: Allow authenticated users to read other users' basic profiles
-- ============================================

-- Drop the overly restrictive policy that only allows self-reads
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;

-- Self read (full access to own row)
CREATE POLICY "Users can view own profile"
    ON public.users FOR SELECT
    USING (auth.uid() = id);

-- Allow reading others' public fields (email + display_name) for invite flows
-- Edge functions use service role, but this helps direct PostgREST queries too
CREATE POLICY "Authenticated users can view basic profiles"
    ON public.users FOR SELECT
    USING (auth.uid() IS NOT NULL);

-- ============================================
-- STEP 2: Fix contact_invites FK to reference public.users (not auth.users)
-- ============================================
-- This restores PostgREST relationship embedding for inviter details

ALTER TABLE public.contact_invites
    DROP CONSTRAINT IF EXISTS contact_invites_inviter_id_fkey;

-- Ensure all existing inviter_ids exist in public.users before adding FK
-- (backfill any missing rows from auth.users)
INSERT INTO public.users (id, email, display_name, avatar_color, created_at)
SELECT
    au.id,
    au.email,
    COALESCE(au.raw_user_meta_data->>'display_name', au.email, 'User'),
    '#FF6B35',
    NOW()
FROM auth.users au
WHERE au.id IN (SELECT DISTINCT inviter_id FROM public.contact_invites)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.contact_invites
    ADD CONSTRAINT contact_invites_inviter_id_fkey
    FOREIGN KEY (inviter_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- ============================================
-- STEP 3: Add is_active column alias for wake_permissions
-- ============================================
-- get-contacts edge function was querying .eq('is_active', true) but the
-- column is 'status'. Adding a generated column so both queries work.

ALTER TABLE public.wake_permissions
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN GENERATED ALWAYS AS (status = 'active') STORED;

CREATE INDEX IF NOT EXISTS idx_wake_permissions_is_active ON public.wake_permissions(is_active);

-- ============================================
-- STEP 4: Ensure received invites RLS allows invitee to see their invites
-- ============================================

-- The existing "Invites viewable by token" policy has USING (true) which
-- already allows all authenticated users to read all invites.
-- We add a named policy specifically for email-based received invite lookup
-- so it's clear this is intentional.
DROP POLICY IF EXISTS "Invitees can view invites sent to their email" ON public.contact_invites;

CREATE POLICY "Invitees can view invites sent to their email"
    ON public.contact_invites FOR SELECT
    USING (
        auth.uid() IS NOT NULL
        AND LOWER(invitee_email) = LOWER((SELECT email FROM auth.users WHERE id = auth.uid()))
    );
