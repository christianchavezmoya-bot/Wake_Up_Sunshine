-- Cleanup script: remove stale wake_permissions and test invite data
-- Run in Supabase SQL editor before fresh testing
-- Safe to run multiple times (uses conditional deletes)

-- 1. Remove wake_permissions that have no corresponding accepted invite
--    (orphaned rows from deleted invites or stale test data)
DELETE FROM public.wake_permissions
WHERE id NOT IN (
  SELECT wp.id
  FROM public.wake_permissions wp
  JOIN public.contact_invites ci
    ON ci.status = 'accepted'
    AND ci.invitee_id   = wp.granter_id
    AND ci.inviter_id   = wp.trustee_id
);

-- 2. Remove all non-pending contact_invites older than 7 days
--    (accepted / declined rows that are no longer needed for reference)
DELETE FROM public.contact_invites
WHERE status IN ('accepted', 'declined')
  AND created_at < NOW() - INTERVAL '7 days';

-- 3. Full reset (uncomment for a clean-slate test environment)
-- DELETE FROM public.wake_permissions;
-- DELETE FROM public.contact_invites;

-- Verify remaining rows
SELECT 'wake_permissions' AS tbl, COUNT(*) FROM public.wake_permissions
UNION ALL
SELECT 'contact_invites',         COUNT(*) FROM public.contact_invites;
