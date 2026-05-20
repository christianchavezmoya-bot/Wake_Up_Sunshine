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

    const body = await req.json().catch(() => ({}));
    const wakeRequestId: string = body.wakeRequestId;

    if (!wakeRequestId) return json({ success: false, error: "Missing wakeRequestId" }, 400);

    // Fetch the request — caller must be sender or receiver
    const { data: wr, error: wrErr } = await supabase
      .from("wake_requests")
      .select(`
        id, sender_id, receiver_id, status,
        response_action, response_message,
        responded_at, snooze_until,
        alarm_sound_id, message, urgency,
        sent_at, delivered_at, created_at
      `)
      .eq("id", wakeRequestId)
      .or(`sender_id.eq.${userId},receiver_id.eq.${userId}`)
      .single();

    if (wrErr || !wr) return json({ success: false, error: "Wake request not found" }, 404);

    // Resolve other-party name/email
    const otherUserId = wr.sender_id === userId ? wr.receiver_id : wr.sender_id;
    const { data: otherUser } = await supabase
      .from("users")
      .select("display_name, email")
      .eq("id", otherUserId)
      .single();

    return json({
      success: true,
      wakeRequest: {
        id: wr.id,
        status: wr.status,
        responseAction: wr.response_action,
        responseMessage: wr.response_message,
        respondedAt: wr.responded_at,
        snoozeUntil: wr.snooze_until,
        alarmSoundId: wr.alarm_sound_id,
        message: wr.message,
        urgency: wr.urgency,
        sentAt: wr.sent_at,
        deliveredAt: wr.delivered_at,
        createdAt: wr.created_at,
        otherUserName: otherUser?.display_name || otherUser?.email?.split("@")[0] || "Unknown",
        otherUserEmail: otherUser?.email || "",
      },
    });
  } catch (err) {
    console.error("[get-wake-status]", err);
    return json({ success: false, error: "Internal server error" }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
