// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

// Real public tables confirmed from live schema (2026-05-24):
//   users, user_devices, wake_permissions, wake_requests,
//   contact_invites, rate_limits, debug_events,
//   unlock_users, purchases, unlock_invites, invite_redemptions, users_backup
//
// unlock_users / purchases / unlock_invites / invite_redemptions are device-based
// (purchases.user_id → unlock_users.id, NOT auth.users.id) — skip on account deletion.

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ success: false, error: "Missing authorization" }, 401);

    const { data: auth, error: authErr } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", "")
    );
    if (authErr || !auth.user) return json({ success: false, error: "Invalid token" }, 401);

    const userId = auth.user.id;
    console.log(`[delete-account] Starting deletion for userId=${userId}`);

    // ── Step 1: debug_events (nullable user_id, no FK) ──────────────────────
    const { error: deErr } = await supabase
      .from("debug_events")
      .delete()
      .eq("user_id", userId);
    if (deErr) console.error("[delete-account] debug_events:", deErr.message);

    // ── Step 2: rate_limits ──────────────────────────────────────────────────
    const { error: rlErr } = await supabase
      .from("rate_limits")
      .delete()
      .or(`sender_id.eq.${userId},target_id.eq.${userId}`);
    if (rlErr) {
      console.error("[delete-account] rate_limits:", rlErr.message);
      return json({ success: false, error: "Could not delete account. Please try again." }, 500);
    }

    // ── Step 3: wake_requests ────────────────────────────────────────────────
    const { error: wrErr } = await supabase
      .from("wake_requests")
      .delete()
      .or(`sender_id.eq.${userId},receiver_id.eq.${userId}`);
    if (wrErr) {
      console.error("[delete-account] wake_requests:", wrErr.message);
      return json({ success: false, error: "Could not delete account. Please try again." }, 500);
    }

    // ── Step 4: wake_permissions ─────────────────────────────────────────────
    const { error: wpErr } = await supabase
      .from("wake_permissions")
      .delete()
      .or(`granter_id.eq.${userId},trustee_id.eq.${userId}`);
    if (wpErr) {
      console.error("[delete-account] wake_permissions:", wpErr.message);
      return json({ success: false, error: "Could not delete account. Please try again." }, 500);
    }

    // ── Step 5: contact_invites ──────────────────────────────────────────────
    const { error: ciErr } = await supabase
      .from("contact_invites")
      .delete()
      .or(`inviter_id.eq.${userId},invitee_id.eq.${userId}`);
    if (ciErr) {
      console.error("[delete-account] contact_invites:", ciErr.message);
      return json({ success: false, error: "Could not delete account. Please try again." }, 500);
    }

    // ── Step 6: user_devices ─────────────────────────────────────────────────
    const { error: udErr } = await supabase
      .from("user_devices")
      .delete()
      .eq("user_id", userId);
    if (udErr) {
      console.error("[delete-account] user_devices:", udErr.message);
      return json({ success: false, error: "Could not delete account. Please try again." }, 500);
    }

    // ── Step 7: public.users profile row ────────────────────────────────────
    const { error: uErr } = await supabase
      .from("users")
      .delete()
      .eq("id", userId);
    if (uErr) {
      console.error("[delete-account] users:", uErr.message);
      return json({ success: false, error: "Could not delete account. Please try again." }, 500);
    }

    // ── Step 8: auth user (must be last) ─────────────────────────────────────
    const { error: authDelErr } = await supabase.auth.admin.deleteUser(userId);
    if (authDelErr) {
      console.error("[delete-account] auth.deleteUser:", authDelErr.message);
      return json({ success: false, error: "Could not delete account. Please try again." }, 500);
    }

    console.log(`[delete-account] Success for userId=${userId}`);
    return json({ success: true, message: "Account deleted successfully" });

  } catch (err) {
    console.error("[delete-account] Unexpected error:", err);
    return json({ success: false, error: "Could not delete account. Please try again." }, 500);
  }
});
