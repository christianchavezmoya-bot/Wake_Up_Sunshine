-- Fix User Identity Model
-- Version: 1.0.0
-- 
-- PROBLEM: public.users.id was using uuid_generate_v4() creating NEW UUIDs,
-- but auth.users.id is the canonical identity. FK constraints failed because
-- inviter_id (auth.users.id) didn't exist in public.users.
--
-- SOLUTION: 
-- 1. public.users.id must equal auth.users.id
-- 2. Auto-create public.users on auth signup
-- 3. Update FKs to reference auth.users directly for clarity

-- ============================================
-- STEP 1: Drop existing FK constraints
-- ============================================

-- Drop FKs from contact_invites
ALTER TABLE public.contact_invites 
DROP CONSTRAINT IF EXISTS contact_invites_inviter_id_fkey;

-- Drop FKs from wake_permissions  
ALTER TABLE public.wake_permissions
DROP CONSTRAINT IF EXISTS wake_permissions_granter_id_fkey;
ALTER TABLE public.wake_permissions
DROP CONSTRAINT IF EXISTS wake_permissions_trustee_id_fkey;

-- Drop FKs from user_devices
ALTER TABLE public.user_devices
DROP CONSTRAINT IF EXISTS user_devices_user_id_fkey;

-- Drop FKs from wake_requests
ALTER TABLE public.wake_requests
DROP CONSTRAINT IF EXISTS wake_requests_sender_id_fkey;
ALTER TABLE public.wake_requests
DROP CONSTRAINT IF EXISTS wake_requests_receiver_id_fkey;

-- Drop FKs from rate_limits
ALTER TABLE public.rate_limits
DROP CONSTRAINT IF EXISTS rate_limits_sender_id_fkey;
ALTER TABLE public.rate_limits
DROP CONSTRAINT IF EXISTS rate_limits_target_id_fkey;

-- ============================================
-- STEP 2: Recreate public.users with auth.users.id
-- ============================================

-- Backup existing data
CREATE TABLE IF NOT EXISTS public.users_backup AS 
SELECT * FROM public.users;

-- Drop the old table (this removes the uuid_generate_v4() default)
DROP TABLE IF EXISTS public.users CASCADE;

-- Recreate users table with id referencing auth.users
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    phone_number VARCHAR(20) UNIQUE,
    email TEXT UNIQUE,
    display_name VARCHAR(100),
    avatar_color VARCHAR(7) DEFAULT '#FF6B35',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for lookups
CREATE INDEX idx_users_phone ON public.users(phone_number);
CREATE INDEX idx_users_email ON public.users(email);

-- ============================================
-- STEP 3: Recreate dependent tables with correct FKs
-- ============================================

-- User Devices
DROP TABLE IF EXISTS public.user_devices CASCADE;
CREATE TABLE public.user_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform VARCHAR(20) DEFAULT 'ios' CHECK (platform IN ('ios', 'android')),
    device_name VARCHAR(100),
    is_primary BOOLEAN DEFAULT true,
    critical_alerts_enabled BOOLEAN DEFAULT true,
    last_active_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, device_token)
);

CREATE INDEX idx_user_devices_token ON public.user_devices(device_token);
CREATE INDEX idx_user_devices_user ON public.user_devices(user_id);

-- Wake Permissions
DROP TABLE IF EXISTS public.wake_permissions CASCADE;
CREATE TABLE public.wake_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    granter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    trustee_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'blocked')),
    schedule_start TIME,
    schedule_end TIME,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(granter_id, trustee_id)
);

CREATE INDEX idx_wake_permissions_granter ON public.wake_permissions(granter_id);
CREATE INDEX idx_wake_permissions_trustee ON public.wake_permissions(trustee_id);

-- Wake Requests
DROP TABLE IF EXISTS public.wake_requests CASCADE;
CREATE TABLE public.wake_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    message TEXT,
    urgency VARCHAR(20) DEFAULT 'normal' CHECK (urgency IN ('low', 'normal', 'high', 'emergency')),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'delivered', 'alarm_playing', 'dismissed', 'confirmed', 'snoozed', 'expired')),
    alarm_sound_id UUID,
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    delivered_at TIMESTAMPTZ,
    dismissed_at TIMESTAMPTZ,
    confirmed_at TIMESTAMPTZ,
    snoozed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_wake_requests_sender ON public.wake_requests(sender_id);
CREATE INDEX idx_wake_requests_receiver ON public.wake_requests(receiver_id);
CREATE INDEX idx_wake_requests_status ON public.wake_requests(status);

-- Rate Limits
DROP TABLE IF EXISTS public.rate_limits CASCADE;
CREATE TABLE public.rate_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    target_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    requests_today INTEGER DEFAULT 0,
    last_request_at TIMESTAMPTZ,
    is_blocked BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(sender_id, target_id)
);

CREATE INDEX idx_rate_limits_sender ON public.rate_limits(sender_id);
CREATE INDEX idx_rate_limits_target ON public.rate_limits(target_id);

-- ============================================
-- STEP 4: Add FK to contact_invites (already exists, just add constraint)
-- ============================================

ALTER TABLE public.contact_invites
ADD CONSTRAINT contact_invites_inviter_id_fkey
FOREIGN KEY (inviter_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- ============================================
-- STEP 5: Create trigger to auto-create public.users on auth signup
-- ============================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email, phone_number, display_name, avatar_color, created_at)
    VALUES (
        NEW.id,
        NEW.email,
        NEW.phone,
        COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.email, 'User'),
        '#FF6B35',
        NOW()
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if any
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- STEP 6: Backfill existing auth users into public.users
-- ============================================

INSERT INTO public.users (id, email, phone_number, display_name, avatar_color, created_at)
SELECT 
    u.id,
    u.email,
    u.phone,
    COALESCE(u.raw_user_meta_data->>'display_name', u.email, 'User'),
    '#FF6B35',
    NOW()
FROM auth.users u
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- STEP 7: Recreate RLS policies
-- ============================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wake_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wake_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Users can view own profile"
    ON public.users FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.users FOR UPDATE
    USING (auth.uid() = id);

-- Allow insert for authenticated users (trigger handles creation, but this allows explicit inserts)
CREATE POLICY "Users can insert own profile"
    ON public.users FOR INSERT
    WITH CHECK (auth.uid() = id);

-- User Devices policies
CREATE POLICY "Users can view own devices"
    ON public.user_devices FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own devices"
    ON public.user_devices FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own devices"
    ON public.user_devices FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own devices"
    ON public.user_devices FOR DELETE
    USING (auth.uid() = user_id);

-- Wake Permissions policies
CREATE POLICY "Users can view permissions where they are granter"
    ON public.wake_permissions FOR SELECT
    USING (auth.uid() = granter_id);

CREATE POLICY "Users can view permissions where they are trustee"
    ON public.wake_permissions FOR SELECT
    USING (auth.uid() = trustee_id);

CREATE POLICY "Users can insert permissions as granter"
    ON public.wake_permissions FOR INSERT
    WITH CHECK (auth.uid() = granter_id);

CREATE POLICY "Users can update permissions as granter"
    ON public.wake_permissions FOR UPDATE
    USING (auth.uid() = granter_id);

CREATE POLICY "Users can delete permissions as granter"
    ON public.wake_permissions FOR DELETE
    USING (auth.uid() = granter_id);

-- Wake Requests policies
CREATE POLICY "Users can view sent wake requests"
    ON public.wake_requests FOR SELECT
    USING (auth.uid() = sender_id);

CREATE POLICY "Users can view received wake requests"
    ON public.wake_requests FOR SELECT
    USING (auth.uid() = receiver_id);

CREATE POLICY "Users can insert wake requests"
    ON public.wake_requests FOR INSERT
    WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update wake requests as receiver"
    ON public.wake_requests FOR UPDATE
    USING (auth.uid() = receiver_id);

-- Rate Limits policies
CREATE POLICY "Users can view own rate limits"
    ON public.rate_limits FOR SELECT
    USING (auth.uid() = sender_id);

CREATE POLICY "Users can update own rate limits"
    ON public.rate_limits FOR UPDATE
    USING (auth.uid() = sender_id);

-- ============================================
-- STEP 8: Recreate triggers
-- ============================================

CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_wake_permissions_updated_at
    BEFORE UPDATE ON public.wake_permissions
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at();

-- ============================================
-- STEP 9: Recreate utility functions
-- ============================================

CREATE OR REPLACE FUNCTION public.can_send_wake(
    p_sender_id UUID,
    p_receiver_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_permission_count INTEGER;
    v_rate_limit RECORD;
BEGIN
    SELECT COUNT(*) INTO v_permission_count
    FROM public.wake_permissions
    WHERE granter_id = p_receiver_id
      AND trustee_id = p_sender_id
      AND status = 'active';

    IF v_permission_count = 0 THEN
        RETURN false;
    END IF;

    SELECT * INTO v_rate_limit
    FROM public.rate_limits
    WHERE sender_id = p_sender_id AND target_id = p_receiver_id;

    IF v_rate_limit.is_blocked THEN
        RETURN false;
    END IF;

    IF v_rate_limit.requests_today >= 10 THEN
        RETURN false;
    END IF;

    IF v_rate_limit.last_request_at IS NOT NULL
       AND v_rate_limit.last_request_at > NOW() - INTERVAL '30 minutes' THEN
        RETURN false;
    END IF;

    RETURN true;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.update_rate_limit(
    p_sender_id UUID,
    p_target_id UUID
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.rate_limits (sender_id, target_id, requests_today, last_request_at)
    VALUES (p_sender_id, p_target_id, 1, NOW())
    ON CONFLICT (sender_id, target_id)
    DO UPDATE SET
        requests_today = CASE
            WHEN DATE(rate_limits.last_request_at) = CURRENT_DATE THEN rate_limits.requests_today + 1
            ELSE 1
        END,
        last_request_at = NOW();
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.increment_wake_count()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM public.update_rate_limit(NEW.sender_id, NEW.receiver_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_rate_limit_on_wake
    AFTER INSERT ON public.wake_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.increment_wake_count();