-- Fix: Allow trustees to delete their own wake permissions
-- This fixes the bug where users cannot remove contacts from "People I Can Wake"

-- Add policy allowing trustees to delete permissions where they are the trustee
CREATE POLICY "Users can delete permissions as trustee"
    ON public.wake_permissions FOR DELETE
    USING (auth.uid() = trustee_id);