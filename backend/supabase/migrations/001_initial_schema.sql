-- Wake Up Sunshine Database Schema
-- Version: 1.0.0

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- USERS TABLE
-- ============================================
CREATE TABLE public.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    display_name VARCHAR(100),
    avatar_color VARCHAR(7) DEFAULT '#FF6B35',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for phone number lookups
CREATE INDEX idx_users_phone ON public.users(phone_number);

-- ============================================
-- USER DEVICES TABLE
-- ============================================
CREATE TABLE public.user_devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform VARCHAR(20) DEFAULT 'ios' CHECK (platform IN ('ios', 'android')),
    device_name VARCHAR(100),
    is_primary BOOLEAN DEFAULT true,
    critical_alerts_enabled BOOLEAN DEFAULT true,
    last_active_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id, device_token)
);

-- Index for device token lookups
CREATE INDEX idx_user_devices_token ON public.user_devices(device_token);
CREATE INDEX idx_user_devices_user ON public.user_devices(user_id);
CREATE INDEX idx_user_devices_platform ON public.user_devices(platform);

-- ============================================
-- WAKE PERMISSIONS TABLE
-- ============================================
CREATE TABLE public.wake_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    granter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    trustee_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'blocked')),
    schedule_start TIME,
    schedule_end TIME,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(granter_id, trustee_id)
);

-- Index for permission lookups
CREATE INDEX idx_wake_permissions_granter ON public.wake_permissions(granter_id);
CREATE INDEX idx_wake_permissions_trustee ON public.wake_permissions(trustee_id);
CREATE INDEX idx_wake_permissions_status ON public.wake_permissions(status);

-- ============================================
-- WAKE REQUESTS TABLE
-- ============================================
CREATE TABLE public.wake_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    message TEXT,
    urgency VARCHAR(20) DEFAULT 'normal' CHECK (urgency IN ('low', 'normal', 'high', 'emergency')),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'delivered', 'alarm_playing', 'dismissed', 'confirmed', 'snoozed', 'expired')),
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    delivered_at TIMESTAMPTZ,
    dismissed_at TIMESTAMPTZ,
    confirmed_at TIMESTAMPTZ,
    snoozed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for wake request lookups
CREATE INDEX idx_wake_requests_sender ON public.wake_requests(sender_id);
CREATE INDEX idx_wake_requests_receiver ON public.wake_requests(receiver_id);
CREATE INDEX idx_wake_requests_status ON public.wake_requests(status);
CREATE INDEX idx_wake_requests_created ON public.wake_requests(created_at DESC);

-- ============================================
-- RATE LIMITS TABLE
-- ============================================
CREATE TABLE public.rate_limits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    target_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    requests_today INTEGER DEFAULT 0,
    last_request_at TIMESTAMPTZ,
    is_blocked BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(sender_id, target_id)
);

-- Index for rate limit lookups
CREATE INDEX idx_rate_limits_sender ON public.rate_limits(sender_id);
CREATE INDEX idx_rate_limits_target ON public.rate_limits(target_id);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for users table
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at();

-- Trigger for wake_permissions table
CREATE TRIGGER update_wake_permissions_updated_at
    BEFORE UPDATE ON public.wake_permissions
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at();

-- Function to check if sender can wake receiver
CREATE OR REPLACE FUNCTION public.can_send_wake(
    p_sender_id UUID,
    p_receiver_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_permission_count INTEGER;
    v_rate_limit RECORD;
BEGIN
    -- Check if permission exists and is active
    SELECT COUNT(*) INTO v_permission_count
    FROM public.wake_permissions
    WHERE granter_id = p_receiver_id
      AND trustee_id = p_sender_id
      AND status = 'active';

    IF v_permission_count = 0 THEN
        RETURN false;
    END IF;

    -- Check rate limits
    SELECT * INTO v_rate_limit
    FROM public.rate_limits
    WHERE sender_id = p_sender_id AND target_id = p_receiver_id;

    IF v_rate_limit.is_blocked THEN
        RETURN false;
    END IF;

    -- Check daily limit (10 requests per day)
    IF v_rate_limit.requests_today >= 10 THEN
        RETURN false;
    END IF;

    -- Check cooldown (30 minutes between requests)
    IF v_rate_limit.last_request_at IS NOT NULL
       AND v_rate_limit.last_request_at > NOW() - INTERVAL '30 minutes' THEN
        RETURN false;
    END IF;

    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Function to create or update rate limit
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

-- Function to increment wake count
CREATE OR REPLACE FUNCTION public.increment_wake_count()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM public.update_rate_limit(NEW.sender_id, NEW.receiver_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for wake_requests to update rate limits
CREATE TRIGGER update_rate_limit_on_wake
    AFTER INSERT ON public.wake_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.increment_wake_count();

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wake_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wake_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;

-- Users: Users can read/update their own data
CREATE POLICY "Users can view own profile"
    ON public.users FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.users FOR UPDATE
    USING (auth.uid() = id);

-- User Devices: Users can manage their own devices
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

-- Wake Permissions: Users can manage their own permissions
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

-- Wake Requests: Users can view their sent/received requests
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

-- Rate Limits: Users can manage their own rate limits
CREATE POLICY "Users can view own rate limits"
    ON public.rate_limits FOR SELECT
    USING (auth.uid() = sender_id);

CREATE POLICY "Users can update own rate limits"
    ON public.rate_limits FOR UPDATE
    USING (auth.uid() = sender_id);