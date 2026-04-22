import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface WakeRequestBody {
  targetUserId: string;
  message?: string;
  urgency?: "low" | "normal" | "high" | "emergency";
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const apnsKeyId = Deno.env.get("APNS_KEY_ID")!;
    const apnsTeamId = Deno.env.get("APNS_TEAM_ID")!;
    const apnsPrivateKey = Deno.env.get("APNS_PRIVATE_KEY")!.replace(/\\n/g, "\n");

    // Create Supabase client with service role
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get auth header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get current user
    const token = authHeader.replace("Bearer ", "");
    const { data: user, error: userError } = await supabase.auth.getUser(token);

    if (userError || !user.user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const senderId = user.user.id;

    // Parse request body
    const body: WakeRequestBody = await req.json();
    const { targetUserId, message, urgency = "normal" } = body;

    if (!targetUserId) {
      return new Response(JSON.stringify({ error: "Missing targetUserId" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check permission
    const { data: permission, error: permissionError } = await supabase
      .from("wake_permissions")
      .select("*")
      .eq("granter_id", targetUserId)
      .eq("trustee_id", senderId)
      .eq("status", "active")
      .single();

    if (permissionError || !permission) {
      return new Response(JSON.stringify({ error: "Permission denied" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check rate limit
    const { data: rateLimit, error: rateLimitError } = await supabase
      .from("rate_limits")
      .select("*")
      .eq("sender_id", senderId)
      .eq("target_id", targetUserId)
      .single();

    if (rateLimit?.is_blocked) {
      return new Response(JSON.stringify({ error: "Blocked" }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check daily limit (10 requests)
    if (rateLimit && rateLimit.requests_today >= 10 && isSameDay(rateLimit.last_request_at)) {
      return new Response(JSON.stringify({ error: "Daily limit exceeded" }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check cooldown (30 minutes)
    if (rateLimit?.last_request_at && !isCooldownComplete(rateLimit.last_request_at)) {
      return new Response(JSON.stringify({ error: "Please wait before sending another wake" }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get receiver's primary device
    const { data: device, error: deviceError } = await supabase
      .from("user_devices")
      .select("*")
      .eq("user_id", targetUserId)
      .eq("is_primary", true)
      .single();

    if (deviceError || !device) {
      return new Response(JSON.stringify({ error: "Receiver has no registered devices" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Create wake request
    const { data: wakeRequest, error: wakeError } = await supabase
      .from("wake_requests")
      .insert({
        sender_id: senderId,
        receiver_id: targetUserId,
        message: message || null,
        urgency: urgency,
        status: "pending",
      })
      .select()
      .single();

    if (wakeError || !wakeRequest) {
      return new Response(JSON.stringify({ error: "Failed to create wake request" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Send push notification via APNs
    await sendPushNotification(device.device_token, {
      requestId: wakeRequest.id,
      senderName: user.user.user_metadata?.display_name || "Someone",
      message: message,
      urgency: urgency,
    });

    // Update wake request status to delivered
    await supabase
      .from("wake_requests")
      .update({ status: "delivered", delivered_at: new Date().toISOString() })
      .eq("id", wakeRequest.id);

    // Update rate limit
    await updateRateLimit(supabase, senderId, targetUserId);

    return new Response(
      JSON.stringify({
        success: true,
        requestId: wakeRequest.id,
        status: "delivered",
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Error sending wake:", error);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

// Helper functions
function isSameDay(date: string): boolean {
  const d = new Date(date);
  const now = new Date();
  return d.toDateString() === now.toDateString();
}

function isCooldownComplete(lastRequest: string): boolean {
  const last = new Date(lastRequest);
  const now = new Date();
  const diffMinutes = (now.getTime() - last.getTime()) / (1000 * 60);
  return diffMinutes >= 30;
}

async function sendPushNotification(deviceToken: string, payload: any) {
  // APNs implementation would go here
  // This requires proper JWT authentication with Apple
  console.log("Sending push to:", deviceToken, payload);
}

async function updateRateLimit(supabase: any, senderId: string, targetId: string) {
  const { data: existing } = await supabase
    .from("rate_limits")
    .select("*")
    .eq("sender_id", senderId)
    .eq("target_id", targetId)
    .single();

  if (existing) {
    await supabase
      .from("rate_limits")
      .update({
        requests_today: existing.requests_today + 1,
        last_request_at: new Date().toISOString(),
      })
      .eq("id", existing.id);
  } else {
    await supabase.from("rate_limits").insert({
      sender_id: senderId,
      target_id: targetId,
      requests_today: 1,
      last_request_at: new Date().toISOString(),
    });
  }
}