-- Persist sender-defined invite labels for email, share-link, and QR invites.
-- This lets pending invites show who the sender intended the invite for.

ALTER TABLE public.contact_invites
  ADD COLUMN IF NOT EXISTS invitee_label TEXT;
