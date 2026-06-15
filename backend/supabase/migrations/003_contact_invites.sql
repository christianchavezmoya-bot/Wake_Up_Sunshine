-- Contact Invites Table
-- Version: 1.0.0

-- ============================================
-- CONTACT INVITES TABLE
-- ============================================
CREATE TABLE public.contact_invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inviter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    invitee_email TEXT NOT NULL,
    invite_token TEXT UNIQUE NOT NULL DEFAULT replace(gen_random_uuid()::text, '-', ''),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'expired')),
    message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    accepted_at TIMESTAMPTZ NULL,
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days')
);

-- Indexes for lookups
CREATE INDEX idx_contact_invites_inviter ON public.contact_invites(inviter_id);
CREATE INDEX idx_contact_invites_email ON public.contact_invites(invitee_email);
CREATE INDEX idx_contact_invites_token ON public.contact_invites(invite_token);
CREATE INDEX idx_contact_invites_status ON public.contact_invites(status);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

ALTER TABLE public.contact_invites ENABLE ROW LEVEL SECURITY;

-- Users can view invites they created
CREATE POLICY "Users can view their sent invites"
    ON public.contact_invites FOR SELECT
    USING (auth.uid() = inviter_id);

-- Users can create invites
CREATE POLICY "Users can create invites"
    ON public.contact_invites FOR INSERT
    WITH CHECK (auth.uid() = inviter_id);

-- Users can update invites they created
CREATE POLICY "Users can update their invites"
    ON public.contact_invites FOR UPDATE
    USING (auth.uid() = inviter_id);

-- Allow anyone with valid token to view invite (for accept flow)
-- This is needed so invitees can see the invite before logging in
CREATE POLICY "Invites viewable by token"
    ON public.contact_invites FOR SELECT
    USING (true);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to accept an invite and create wake permission
CREATE OR REPLACE FUNCTION public.accept_invite(
    p_invite_token TEXT,
    p_user_id UUID
)
RETURNS JSON AS $$
DECLARE
    v_invite RECORD;
    v_result JSON;
BEGIN
    -- Get the invite
    SELECT * INTO v_invite
    FROM public.contact_invites
    WHERE invite_token = p_invite_token
      AND status = 'pending'
      AND expires_at > NOW();
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Invite not found, already processed, or expired'
        );
    END IF;
    
    -- Update invite status
    UPDATE public.contact_invites
    SET status = 'accepted',
        accepted_at = NOW()
    WHERE id = v_invite.id;
    
    -- Create wake permission (inviter can wake the invitee)
    -- granter_id = invitee (the person accepting), trustee_id = inviter (the person who sent invite)
    INSERT INTO public.wake_permissions (granter_id, trustee_id, status)
    VALUES (p_user_id, v_invite.inviter_id, 'active')
    ON CONFLICT (granter_id, trustee_id)
    DO UPDATE SET status = 'active';
    
    RETURN json_build_object(
        'success', true,
        'inviter_id', v_invite.inviter_id,
        'message', 'Invite accepted successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to decline an invite
CREATE OR REPLACE FUNCTION public.decline_invite(
    p_invite_token TEXT
)
RETURNS JSON AS $$
DECLARE
    v_invite RECORD;
BEGIN
    -- Get the invite
    SELECT * INTO v_invite
    FROM public.contact_invites
    WHERE invite_token = p_invite_token
      AND status = 'pending';
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Invite not found or already processed'
        );
    END IF;
    
    -- Update invite status
    UPDATE public.contact_invites
    SET status = 'declined'
    WHERE id = v_invite.id;
    
    RETURN json_build_object(
        'success', true,
        'message', 'Invite declined'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's contacts (people they can wake)
CREATE OR REPLACE FUNCTION public.get_my_contacts()
RETURNS TABLE (
    id UUID,
    display_name TEXT,
    avatar_color TEXT,
    permission_id UUID,
    is_online BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        COALESCE(u.display_name, 'User')::TEXT as display_name,
        COALESCE(u.avatar_color, '#FF6B35')::TEXT as avatar_color,
        wp.id as permission_id,
        EXISTS (
            SELECT 1 FROM public.user_devices ud 
            WHERE ud.user_id = u.id 
            AND ud.last_active_at > NOW() - INTERVAL '5 minutes'
        ) as is_online
    FROM public.wake_permissions wp
    JOIN public.users u ON u.id = wp.granter_id
    WHERE wp.trustee_id = auth.uid()
      AND wp.status = 'active'
    ORDER BY u.display_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get pending invites sent by user
CREATE OR REPLACE FUNCTION public.get_my_sent_invites()
RETURNS TABLE (
    id UUID,
    invitee_email TEXT,
    status TEXT,
    created_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ci.id,
        ci.invitee_email,
        ci.status,
        ci.created_at,
        ci.expires_at
    FROM public.contact_invites ci
    WHERE ci.inviter_id = auth.uid()
    ORDER BY ci.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get pending invites received by user (based on email)
CREATE OR REPLACE FUNCTION public.get_my_received_invites()
RETURNS TABLE (
    id UUID,
    inviter_id UUID,
    inviter_name TEXT,
    invite_token TEXT,
    message TEXT,
    created_at TIMESTAMPTZ
) AS $$
DECLARE
    v_user_email TEXT;
BEGIN
    -- Get current user's email from auth
    SELECT email INTO v_user_email FROM auth.users WHERE id = auth.uid();
    
    RETURN QUERY
    SELECT 
        ci.id,
        ci.inviter_id,
        COALESCE(u.display_name, 'Someone')::TEXT as inviter_name,
        ci.invite_token,
        ci.message,
        ci.created_at
    FROM public.contact_invites ci
    JOIN public.users u ON u.id = ci.inviter_id
    WHERE LOWER(ci.invitee_email) = LOWER(v_user_email)
      AND ci.status = 'pending'
      AND ci.expires_at > NOW()
    ORDER BY ci.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add email column to users table if not exists
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'users' 
        AND column_name = 'email'
    ) THEN
        ALTER TABLE public.users ADD COLUMN email TEXT UNIQUE;
        CREATE INDEX idx_users_email ON public.users(email);
    END IF;
END $$;

-- Update RLS policy to allow service role to insert users with email
-- (needed for auth signup flow)