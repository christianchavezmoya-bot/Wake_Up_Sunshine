-- Add 'cancelled' status to contact_invites check constraint
-- This allows users to cancel pending invites

-- ============================================
-- STEP 1: Drop the existing check constraint
-- ============================================
ALTER TABLE public.contact_invites
DROP CONSTRAINT IF EXISTS contact_invites_status_check;

-- ============================================
-- STEP 2: Add new check constraint with 'cancelled' status
-- ============================================
ALTER TABLE public.contact_invites
ADD CONSTRAINT contact_invites_status_check
CHECK (status IN ('pending', 'accepted', 'declined', 'expired', 'cancelled'));

-- ============================================
-- STEP 3: Add cancelled_at column for tracking
-- ============================================
ALTER TABLE public.contact_invites
ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ NULL;

-- ============================================
-- STEP 4: Create function to cancel an invite
-- ============================================
CREATE OR REPLACE FUNCTION public.cancel_invite(
    p_invite_id UUID
)
RETURNS JSON AS $$
DECLARE
    v_invite RECORD;
    v_user_id UUID;
BEGIN
    -- Get current user ID
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Not authenticated'
        );
    END IF;
    
    -- Get the invite (must be owned by current user and pending)
    SELECT * INTO v_invite
    FROM public.contact_invites
    WHERE id = p_invite_id
      AND inviter_id = v_user_id
      AND status = 'pending';
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Invite not found, not owned by you, or already processed'
        );
    END IF;
    
    -- Update invite status to cancelled
    UPDATE public.contact_invites
    SET status = 'cancelled',
        cancelled_at = NOW()
    WHERE id = v_invite.id;
    
    RETURN json_build_object(
        'success', true,
        'message', 'Invite cancelled successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 5: Grant execute permission to authenticated users
-- ============================================
GRANT EXECUTE ON FUNCTION public.cancel_invite(UUID) TO authenticated;