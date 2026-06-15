// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    // Service role — bypasses RLS, same pattern as get-contacts
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // Verify JWT using anon client
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ success: false, error: "Missing authorization" }, 401);

    const anon = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );
    const { data: { user }, error: authErr } = await anon.auth.getUser();
    if (authErr || !user) return json({ success: false, error: "Invalid token" }, 401);
    const userId = user.id;

    console.log("[get-history] get_history_start userId=" + userId);

    const url   = new URL(req.url);
    const limit = Math.min(parseInt(url.searchParams.get("limit") || "50"), 100);
    const page  = Math.max(parseInt(url.searchParams.get("page") || "1"), 1);
    const offset = (page - 1) * limit;

    // ── 1. Fetch raw wake_requests rows (no FK join — sender/receiver ref auth.users) ──
    const [sentResult, receivedResult] = await Promise.all([
      admin
        .from("wake_requests")
        .select("id, sender_id, receiver_id, status, response_action, response_message, responded_at, snooze_until, alarm_sound_id, message, urgency, sent_at, delivered_at, created_at")
        .eq("sender_id", userId)
        .order("created_at", { ascending: false })
        .range(offset, offset + limit - 1),
      admin
        .from("wake_requests")
        .select("id, sender_id, receiver_id, status, response_action, response_message, responded_at, snooze_until, alarm_sound_id, message, urgency, sent_at, delivered_at, created_at")
        .eq("receiver_id", userId)
        .order("created_at", { ascending: false })
        .range(offset, offset + limit - 1),
    ]);

    if (sentResult.error) console.warn("[get-history] sent query error:", sentResult.error);
    if (receivedResult.error) console.warn("[get-history] received query error:", receivedResult.error);

    const sentRows     = sentResult.data     || [];
    const receivedRows = receivedResult.data || [];
    const totalRows    = sentRows.length + receivedRows.length;

    console.log("[get-history] get_history_query_result rowCount=" + totalRows + " sent=" + sentRows.length + " received=" + receivedRows.length);

    // ── 2. Batch-fetch public.users profiles for all other-party IDs ──
    const otherUserIds = [
      ...sentRows.map((r: any) => r.receiver_id),
      ...receivedRows.map((r: any) => r.sender_id),
    ];
    const uniqueIds = [...new Set(otherUserIds)].filter(Boolean);

    let userMap: Record<string, { id: string; email: string; display_name: string; avatar_color: string }> = {};
    if (uniqueIds.length > 0) {
      const { data: userRows, error: userErr } = await admin
        .from("users")
        .select("id, email, display_name, avatar_color")
        .in("id", uniqueIds);
      if (userErr) console.warn("[get-history] user lookup error:", userErr);
      for (const u of (userRows || [])) userMap[u.id] = u;
    }

    // ── 3. Build history items ──
    const toItem = (r: any, direction: "sent" | "received") => {
      const otherUserId = direction === "sent" ? r.receiver_id : r.sender_id;
      const u = userMap[otherUserId] || {};
      return {
        id:              r.id,
        direction,
        otherUserId:     otherUserId,
        otherUserName:   u.display_name || u.email?.split("@")[0] || otherUserId || "Unknown",
        otherUserEmail:  u.email || "",
        avatarColor:     u.avatar_color || "#FF6B35",
        alarmSoundId:    r.alarm_sound_id,
        message:         r.message,
        status:          r.status,
        responseAction:  r.response_action,
        responseMessage: r.response_message,
        respondedAt:     r.responded_at,
        snoozeUntil:     r.snooze_until,
        sentAt:          r.sent_at || r.created_at,
        deliveredAt:     r.delivered_at,
        createdAt:       r.created_at,
      };
    };

    const history = [
      ...sentRows.map((r: any) => toItem(r, "sent")),
      ...receivedRows.map((r: any) => toItem(r, "received")),
    ].sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

    console.log("[get-history] get_history_complete returnedCount=" + history.length);

    return json({ success: true, history, page, limit });
  } catch (err) {
    console.error("[get-history] get_history_error:", err);
    return json({ success: false, error: "Internal server error" }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
