-- Unlock Purchase System Migration
-- Version: 1.0.0
-- Creates tables for purchase-based unlock with invite credits
-- Uses IF NOT EXISTS for idempotency

-- ============================================
-- UNLOCK USERS TABLE (Device-based, no auth required)
-- ============================================
CREATE TABLE IF NOT EXISTS public.unlock_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT UNIQUE NOT NULL,
    has_paid BOOLEAN DEFAULT false,
    invite_credits INTEGER DEFAULT 0,
    is_invited BOOLEAN DEFAULT false,
    invited_by UUID REFERENCES public.unlock_users(id),
    platform VARCHAR(20) CHECK (platform IN ('ios', 'android')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for device_id lookups
CREATE INDEX IF NOT EXISTS idx_unlock_users_device ON public.unlock_users(device_id);

-- ============================================
-- PURCHASES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.unlock_users(id) ON DELETE CASCADE,
    platform VARCHAR(20) NOT NULL CHECK (platform IN ('ios', 'android')),
    product_id VARCHAR(100) NOT NULL DEFAULT 'wake_unlock_lifetime',
    receipt_token TEXT NOT NULL,
    original_transaction_id TEXT,
    validated BOOLEAN DEFAULT false,
    validation_response JSONB,
    purchased_at TIMESTAMPTZ DEFAULT NOW(),
    validated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for purchase lookups
CREATE INDEX IF NOT EXISTS idx_purchases_user ON public.purchases(user_id);
CREATE INDEX IF NOT EXISTS idx_purchases_platform ON public.purchases(platform);
CREATE INDEX IF NOT EXISTS idx_purchases_validated ON public.purchases(validated);
CREATE INDEX IF NOT EXISTS idx_purchases_receipt ON public.purchases(receipt_token);
CREATE INDEX IF NOT EXISTS idx_purchases_original_tx ON public.purchases(original_transaction_id);

-- ============================================
-- UNLOCK INVITES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.unlock_invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(8) UNIQUE NOT NULL,
    created_by_user_id UUID NOT NULL REFERENCES public.unlock_users(id) ON DELETE CASCADE,
    max_uses INTEGER DEFAULT 1,
    uses_count INTEGER DEFAULT 0,
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '48 hours'),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for invite code lookups
CREATE INDEX IF NOT EXISTS idx_unlock_invites_code ON public.unlock_invites(code);
CREATE INDEX IF NOT EXISTS idx_unlock_invites_creator ON public.unlock_invites(created_by_user_id);
CREATE INDEX IF NOT EXISTS idx_unlock_invites_expires ON public.unlock_invites(expires_at);

-- ============================================
-- INVITE REDEMPTIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.invite_redemptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invite_id UUID NOT NULL REFERENCES public.unlock_invites(id) ON DELETE CASCADE,
    redeemed_by_user_id UUID NOT NULL REFERENCES public.unlock_users(id) ON DELETE CASCADE,
    redeemed_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(invite_id, redeemed_by_user_id)
);

-- Index for redemption lookups
CREATE INDEX IF NOT EXISTS idx_invite_redemptions_invite ON public.invite_redemptions(invite_id);
CREATE INDEX IF NOT EXISTS idx_invite_redemptions_user ON public.invite_redemptions(redeemed_by_user_id);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

-- Enable RLS on all tables
ALTER TABLE public.unlock_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.unlock_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invite_redemptions ENABLE ROW LEVEL SECURITY;

-- Unlock Users: Public access (device-based, no auth)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'unlock_users' AND policyname = 'Unlock users are viewable by all') THEN
        CREATE POLICY "Unlock users are viewable by all"
            ON public.unlock_users FOR SELECT
            USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'unlock_users' AND policyname = 'Unlock users can be inserted by all') THEN
        CREATE POLICY "Unlock users can be inserted by all"
            ON public.unlock_users FOR INSERT
            WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'unlock_users' AND policyname = 'Unlock users can be updated by all') THEN
        CREATE POLICY "Unlock users can be updated by all"
            ON public.unlock_users FOR UPDATE
            USING (true);
    END IF;
END $$;

-- Purchases: Public access for insertion
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'purchases' AND policyname = 'Purchases viewable by all') THEN
        CREATE POLICY "Purchases viewable by all"
            ON public.purchases FOR SELECT
            USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'purchases' AND policyname = 'Purchases can be inserted by all') THEN
        CREATE POLICY "Purchases can be inserted by all"
            ON public.purchases FOR INSERT
            WITH CHECK (true);
    END IF;
END $$;

-- Unlock Invites: Public access
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'unlock_invites' AND policyname = 'Unlock invites viewable by all') THEN
        CREATE POLICY "Unlock invites viewable by all"
            ON public.unlock_invites FOR SELECT
            USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'unlock_invites' AND policyname = 'Unlock invites can be inserted by all') THEN
        CREATE POLICY "Unlock invites can be inserted by all"
            ON public.unlock_invites FOR INSERT
            WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'unlock_invites' AND policyname = 'Unlock invites can be updated by all') THEN
        CREATE POLICY "Unlock invites can be updated by all"
            ON public.unlock_invites FOR UPDATE
            USING (true);
    END IF;
END $$;

-- Invite Redemptions: Public access
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'invite_redemptions' AND policyname = 'Invite redemptions viewable by all') THEN
        CREATE POLICY "Invite redemptions viewable by all"
            ON public.invite_redemptions FOR SELECT
            USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'invite_redemptions' AND policyname = 'Invite redemptions can be inserted by all') THEN
        CREATE POLICY "Invite redemptions can be inserted by all"
            ON public.invite_redemptions FOR INSERT
            WITH CHECK (true);
    END IF;
END $$;

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to generate a random 8-character invite code
CREATE OR REPLACE FUNCTION public.generate_invite_code()
RETURNS VARCHAR(8) AS $$
DECLARE
    chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- Removed confusing chars: I, O, 0, 1
    result VARCHAR(8) := '';
    i INTEGER;
BEGIN
    FOR i IN 1..8 LOOP
        result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to get or create unlock user by device_id
CREATE OR REPLACE FUNCTION public.get_or_create_unlock_user(
    p_device_id TEXT,
    p_platform VARCHAR(20) DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- Try to get existing user
    SELECT id INTO v_user_id
    FROM public.unlock_users
    WHERE device_id = p_device_id;
    
    IF v_user_id IS NOT NULL THEN
        RETURN v_user_id;
    END IF;
    
    -- Create new user
    INSERT INTO public.unlock_users (device_id, platform)
    VALUES (p_device_id, p_platform)
    RETURNING id INTO v_user_id;
    
    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to validate purchase and grant credits
CREATE OR REPLACE FUNCTION public.validate_purchase_and_grant_credits(
    p_user_id UUID,
    p_platform VARCHAR(20),
    p_receipt_token TEXT,
    p_original_transaction_id TEXT DEFAULT NULL,
    p_validation_response JSONB DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_existing_purchase RECORD;
    v_user RECORD;
BEGIN
    -- Check if user exists and already has paid
    SELECT * INTO v_user FROM public.unlock_users WHERE id = p_user_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'User not found');
    END IF;
    
    -- Check for duplicate transaction (prevent replay attacks)
    IF p_original_transaction_id IS NOT NULL THEN
        SELECT * INTO v_existing_purchase
        FROM public.purchases
        WHERE original_transaction_id = p_original_transaction_id
          AND validated = true;
        
        IF FOUND THEN
            -- This transaction was already used by another user
            RETURN json_build_object('success', false, 'error', 'Transaction already used');
        END IF;
    END IF;
    
    -- Check if this receipt was already validated
    SELECT * INTO v_existing_purchase
    FROM public.purchases
    WHERE user_id = p_user_id
      AND receipt_token = p_receipt_token
      AND validated = true;
    
    IF FOUND THEN
        -- Already validated, just return success
        RETURN json_build_object(
            'success', true,
            'already_validated', true,
            'has_paid', v_user.has_paid,
            'invite_credits', v_user.invite_credits
        );
    END IF;
    
    -- Create/update purchase record
    INSERT INTO public.purchases (
        user_id, platform, receipt_token, 
        original_transaction_id, validated, 
        validation_response, validated_at
    )
    VALUES (
        p_user_id, p_platform, p_receipt_token,
        p_original_transaction_id, true,
        p_validation_response, NOW()
    )
    ON CONFLICT DO NOTHING;
    
    -- Update user to paid status and grant 2 invite credits
    UPDATE public.unlock_users
    SET has_paid = true,
        invite_credits = 2,
        updated_at = NOW()
    WHERE id = p_user_id;
    
    RETURN json_build_object(
        'success', true,
        'has_paid', true,
        'invite_credits', 2,
        'message', 'Purchase validated successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create an unlock invite
CREATE OR REPLACE FUNCTION public.create_unlock_invite(
    p_user_id UUID
)
RETURNS JSON AS $$
DECLARE
    v_user RECORD;
    v_code VARCHAR(8);
    v_invite RECORD;
BEGIN
    -- Get user
    SELECT * INTO v_user FROM public.unlock_users WHERE id = p_user_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'User not found');
    END IF;
    
    -- Check if user has paid (only paid users can create invites)
    IF NOT v_user.has_paid THEN
        RETURN json_build_object('success', false, 'error', 'Only paid users can create invites');
    END IF;
    
    -- Check if user has invite credits
    IF v_user.invite_credits <= 0 THEN
        RETURN json_build_object('success', false, 'error', 'No invite credits remaining');
    END IF;
    
    -- Generate unique code
    LOOP
        v_code := public.generate_invite_code();
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.unlock_invites WHERE code = v_code);
    END LOOP;
    
    -- Create invite
    INSERT INTO public.unlock_invites (code, created_by_user_id)
    VALUES (v_code, p_user_id)
    RETURNING * INTO v_invite;
    
    -- Decrement user's invite credits
    UPDATE public.unlock_users
    SET invite_credits = invite_credits - 1,
        updated_at = NOW()
    WHERE id = p_user_id;
    
    RETURN json_build_object(
        'success', true,
        'code', v_code,
        'invite_id', v_invite.id,
        'invite_link', 'https://wakemeup.app/invite/' || v_code,
        'deep_link', 'wakeupsunshine://unlock/' || v_code,
        'remaining_credits', v_user.invite_credits - 1
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to validate invite code
CREATE OR REPLACE FUNCTION public.validate_unlock_invite(
    p_code VARCHAR(8)
)
RETURNS JSON AS $$
DECLARE
    v_invite RECORD;
BEGIN
    -- Get invite
    SELECT * INTO v_invite
    FROM public.unlock_invites
    WHERE code = p_code;
    
    IF NOT FOUND THEN
        RETURN json_build_object('valid', false, 'error', 'Invite code not found');
    END IF;
    
    -- Check if expired
    IF v_invite.expires_at < NOW() THEN
        RETURN json_build_object('valid', false, 'error', 'Invite code has expired', 'status', 'expired');
    END IF;
    
    -- Check if fully used
    IF v_invite.uses_count >= v_invite.max_uses THEN
        RETURN json_build_object('valid', false, 'error', 'Invite code has already been used', 'status', 'used');
    END IF;
    
    RETURN json_build_object(
        'valid', true,
        'status', 'valid',
        'invite_id', v_invite.id,
        'created_by', v_invite.created_by_user_id,
        'remaining_uses', v_invite.max_uses - v_invite.uses_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to redeem invite code
CREATE OR REPLACE FUNCTION public.redeem_unlock_invite(
    p_code VARCHAR(8),
    p_device_id TEXT,
    p_platform VARCHAR(20) DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_invite RECORD;
    v_user RECORD;
    v_creator RECORD;
    v_user_id UUID;
BEGIN
    -- Validate invite code
    SELECT * INTO v_invite
    FROM public.unlock_invites
    WHERE code = p_code;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'Invite code not found');
    END IF;
    
    -- Check if expired
    IF v_invite.expires_at < NOW() THEN
        RETURN json_build_object('success', false, 'error', 'Invite code has expired', 'status', 'expired');
    END IF;
    
    -- Check if fully used
    IF v_invite.uses_count >= v_invite.max_uses THEN
        RETURN json_build_object('success', false, 'error', 'Invite code has already been used', 'status', 'used');
    END IF;
    
    -- Get creator to check for self-invite
    SELECT * INTO v_creator
    FROM public.unlock_users
    WHERE id = v_invite.created_by_user_id;
    
    -- Check for self-invite (same device_id)
    IF v_creator.device_id = p_device_id THEN
        RETURN json_build_object('success', false, 'error', 'Cannot use your own invite code');
    END IF;
    
    -- Get or create user
    v_user_id := public.get_or_create_unlock_user(p_device_id, p_platform);
    
    -- Get user record
    SELECT * INTO v_user FROM public.unlock_users WHERE id = v_user_id;
    
    -- Check if user already has access
    IF v_user.has_paid THEN
        RETURN json_build_object('success', false, 'error', 'You already have full access');
    END IF;
    
    -- Check if this user already redeemed this invite
    IF EXISTS (
        SELECT 1 FROM public.invite_redemptions
        WHERE invite_id = v_invite.id AND redeemed_by_user_id = v_user_id
    ) THEN
        RETURN json_build_object('success', false, 'error', 'You have already redeemed this invite');
    END IF;
    
    -- Create redemption record
    INSERT INTO public.invite_redemptions (invite_id, redeemed_by_user_id)
    VALUES (v_invite.id, v_user_id);
    
    -- Update invite uses count
    UPDATE public.unlock_invites
    SET uses_count = uses_count + 1
    WHERE id = v_invite.id;
    
    -- Grant access to user
    UPDATE public.unlock_users
    SET has_paid = true,
        is_invited = true,
        invited_by = v_invite.created_by_user_id,
        updated_at = NOW()
    WHERE id = v_user_id;
    
    RETURN json_build_object(
        'success', true,
        'message', 'Welcome! You now have full access to Wake Me Up',
        'user_id', v_user_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user unlock status
CREATE OR REPLACE FUNCTION public.get_unlock_status(
    p_device_id TEXT
)
RETURNS JSON AS $$
DECLARE
    v_user RECORD;
BEGIN
    SELECT * INTO v_user
    FROM public.unlock_users
    WHERE device_id = p_device_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'exists', false,
            'has_paid', false,
            'is_invited', false,
            'invite_credits', 0
        );
    END IF;
    
    RETURN json_build_object(
        'exists', true,
        'user_id', v_user.id,
        'has_paid', v_user.has_paid,
        'is_invited', v_user.is_invited,
        'invite_credits', v_user.invite_credits,
        'platform', v_user.platform
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for updated_at (drop if exists first)
DROP TRIGGER IF EXISTS update_unlock_users_updated_at ON public.unlock_users;
CREATE TRIGGER update_unlock_users_updated_at
    BEFORE UPDATE ON public.unlock_users
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at();