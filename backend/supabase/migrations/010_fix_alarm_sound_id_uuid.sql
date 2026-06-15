-- Migration: Force fix alarm_sound_id from UUID to TEXT
-- Description: The previous migration didn't properly convert UUID to TEXT

-- Drop any existing constraint first
ALTER TABLE public.wake_requests
DROP CONSTRAINT IF EXISTS valid_alarm_sound_id;

-- Force alter column type to TEXT (this handles UUID to TEXT conversion)
-- First make it nullable to avoid issues
ALTER TABLE public.wake_requests
ALTER COLUMN alarm_sound_id DROP NOT NULL;

-- Change type to TEXT, converting any existing UUID values to text
ALTER TABLE public.wake_requests
ALTER COLUMN alarm_sound_id TYPE TEXT
USING CASE
    WHEN alarm_sound_id IS NULL THEN 'classic'
    ELSE alarm_sound_id::TEXT
END;

-- Set default
ALTER TABLE public.wake_requests
ALTER COLUMN alarm_sound_id SET DEFAULT 'classic';

-- Make it NOT NULL now
ALTER TABLE public.wake_requests
ALTER COLUMN alarm_sound_id SET NOT NULL;

-- Add constraint with correct values
ALTER TABLE public.wake_requests
ADD CONSTRAINT valid_alarm_sound_id
CHECK (alarm_sound_id IN (
    'wake_up',
    'hey_you',
    'minions',
    'classic'
));

-- Add trace_id column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'wake_requests'
        AND column_name = 'trace_id'
    ) THEN
        ALTER TABLE public.wake_requests
        ADD COLUMN trace_id TEXT;
    END IF;
END $$;

-- Comment
COMMENT ON COLUMN public.wake_requests.alarm_sound_id IS 'Alarm sound ID: wake_up, hey_you, minions, classic';
COMMENT ON COLUMN public.wake_requests.trace_id IS 'Debug trace ID for tracking wake request through system';