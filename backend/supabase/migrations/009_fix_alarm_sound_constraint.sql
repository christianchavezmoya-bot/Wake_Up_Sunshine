-- Migration: Fix alarm_sound_id column type and constraint
-- Description: Change column to TEXT and add correct constraint

-- First check and alter column type if needed
DO $$ 
BEGIN
    -- Check if column is UUID type and alter to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'wake_requests' 
        AND column_name = 'alarm_sound_id' 
        AND data_type = 'uuid'
    ) THEN
        ALTER TABLE public.wake_requests 
        ALTER COLUMN alarm_sound_id TYPE TEXT USING alarm_sound_id::TEXT;
    END IF;
END $$;

-- Drop the old constraint if exists
ALTER TABLE public.wake_requests
DROP CONSTRAINT IF EXISTS valid_alarm_sound_id;

-- Make column NOT NULL with default
ALTER TABLE public.wake_requests
ALTER COLUMN alarm_sound_id SET NOT NULL,
ALTER COLUMN alarm_sound_id SET DEFAULT 'classic';

-- Add new constraint with correct values
ALTER TABLE public.wake_requests
ADD CONSTRAINT valid_alarm_sound_id
CHECK (alarm_sound_id IN (
    'wake_up',
    'hey_you',
    'minions',
    'classic'
));

-- Comment on the column
COMMENT ON COLUMN public.wake_requests.alarm_sound_id IS 'The alarm sound ID selected by sender. Valid values: wake_up, hey_you, minions, classic';