-- Fix user_devices table to match register-device function
-- Add missing columns for device registration

-- Add missing columns
ALTER TABLE public.user_devices 
ADD COLUMN IF NOT EXISTS device_type VARCHAR(50) DEFAULT 'iphone',
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Update the unique constraint to use the correct conflict target
-- Drop the old constraint first
ALTER TABLE public.user_devices DROP CONSTRAINT IF EXISTS user_devices_user_id_device_token_key;

-- Add the new unique constraint
CREATE UNIQUE INDEX IF NOT EXISTS user_devices_user_id_device_token_unique 
ON public.user_devices(user_id, device_token);

-- Create trigger for updated_at
DROP TRIGGER IF EXISTS update_user_devices_updated_at ON public.user_devices;
CREATE TRIGGER update_user_devices_updated_at
    BEFORE UPDATE ON public.user_devices
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at();

-- Add policy for service role to manage devices (for Edge Functions)
CREATE POLICY "Service role can manage all devices"
    ON public.user_devices FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Add index for is_active lookups
CREATE INDEX IF NOT EXISTS idx_user_devices_active ON public.user_devices(is_active);

-- Comment on the table
COMMENT ON TABLE public.user_devices IS 'Stores device push tokens for users to receive wake notifications';