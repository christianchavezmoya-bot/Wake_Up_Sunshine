-- Migration: Add alarm_sound_id to wake_requests
-- Version: 2.0.0
-- Description: Adds alarm sound selection feature to wake requests

-- Add alarm_sound_id column to wake_requests table
ALTER TABLE public.wake_requests
ADD COLUMN IF NOT EXISTS alarm_sound_id TEXT NOT NULL DEFAULT 'default_alarm';

-- Add check constraint for valid alarm sound IDs
ALTER TABLE public.wake_requests
DROP CONSTRAINT IF EXISTS valid_alarm_sound_id;

ALTER TABLE public.wake_requests
ADD CONSTRAINT valid_alarm_sound_id
CHECK (alarm_sound_id IN (
    'default_alarm',
    'rooster',
    'bell',
    'siren',
    'gentle_chime',
    'urgent_beep'
));

-- Create index for alarm sound queries (optional, for analytics)
CREATE INDEX IF NOT EXISTS idx_wake_requests_alarm_sound
ON public.wake_requests(alarm_sound_id);

-- Comment on the column
COMMENT ON COLUMN public.wake_requests.alarm_sound_id IS 'The alarm sound ID selected by sender. Maps to device-specific sound files.';