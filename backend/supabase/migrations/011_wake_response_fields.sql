-- Migration 011: Add wake response fields and tighten status constraint
-- Run safely against existing data; all columns are nullable unless defaulted.

-- 1. Response metadata columns
ALTER TABLE public.wake_requests
  ADD COLUMN IF NOT EXISTS response_action   TEXT,
  ADD COLUMN IF NOT EXISTS response_message  TEXT,
  ADD COLUMN IF NOT EXISTS responded_at      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS snooze_until      TIMESTAMPTZ;

-- 2. sent_at (may already exist on some deployments)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'wake_requests'
      AND column_name  = 'sent_at'
  ) THEN
    ALTER TABLE public.wake_requests
      ADD COLUMN sent_at TIMESTAMPTZ DEFAULT NOW();
  END IF;
END $$;

-- 3. updated_at
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'wake_requests'
      AND column_name  = 'updated_at'
  ) THEN
    ALTER TABLE public.wake_requests
      ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
  END IF;
END $$;

-- 4. Widen status check constraint to cover all allowed values.
--    Drop whatever the current constraint is named; add the new one.
DO $$
DECLARE
  _c TEXT;
BEGIN
  SELECT constraint_name INTO _c
  FROM information_schema.table_constraints
  WHERE table_schema    = 'public'
    AND table_name      = 'wake_requests'
    AND constraint_type = 'CHECK'
    AND constraint_name LIKE '%status%';
  IF _c IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.wake_requests DROP CONSTRAINT %I', _c);
  END IF;
END $$;

ALTER TABLE public.wake_requests
  ADD CONSTRAINT wake_requests_status_check
  CHECK (status IN (
    'pending', 'sent', 'delivered',
    'confirmed', 'snoozed', 'dismissed',
    'timed_out', 'failed'
  ));

-- 5. updated_at trigger
CREATE OR REPLACE FUNCTION public.set_wake_requests_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_wake_requests_updated_at ON public.wake_requests;
CREATE TRIGGER trg_wake_requests_updated_at
  BEFORE UPDATE ON public.wake_requests
  FOR EACH ROW EXECUTE FUNCTION public.set_wake_requests_updated_at();

-- 6. Index to speed up anti-spam / active-request lookups
CREATE INDEX IF NOT EXISTS idx_wake_requests_sender_receiver_status
  ON public.wake_requests (sender_id, receiver_id, status);

CREATE INDEX IF NOT EXISTS idx_wake_requests_receiver_status
  ON public.wake_requests (receiver_id, status);

COMMENT ON COLUMN public.wake_requests.response_action  IS 'confirmed | snoozed | dismissed';
COMMENT ON COLUMN public.wake_requests.response_message IS 'Optional message from receiver';
COMMENT ON COLUMN public.wake_requests.responded_at     IS 'When the receiver responded';
COMMENT ON COLUMN public.wake_requests.snooze_until     IS 'If snoozed, wake again after this time';
