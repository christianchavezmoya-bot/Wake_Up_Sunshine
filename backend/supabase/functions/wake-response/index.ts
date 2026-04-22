import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

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

    const receiverId = user.user.id;

    // Parse request body
    const body = await req.json();
    const { requestId, action } = body;

    if (!requestId || !action) {
      return new Response(JSON.stringify({ error: "Missing requestId or action" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Verify the request belongs to this user
    const { data: wakeRequest, error: requestError } = await supabase
      .from("wake_requests")
      .select("*")
      .eq("id", requestId)
      .eq("receiver_id", receiverId)
      .single();

    if (requestError || !wakeRequest) {
      return new Response(JSON.stringify({ error: "Wake request not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Update based on action
    const updates: any = {};
    const now = new Date().toISOString();

    switch (action) {
      case "confirm":
        updates.status = "confirmed";
        updates.confirmed_at = now;
        break;
      case "dismiss":
        updates.status = "dismissed";
        updates.dismissed_at = now;
        break;
      case "snooze":
        updates.status = "snoozed";
        updates.snoozed_at = now;
        break;
      default:
        return new Response(JSON.stringify({ error: "Invalid action" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    }

    const { error: updateError } = await supabase
      .from("wake_requests")
      .update(updates)
      .eq("id", requestId);

    if (updateError) {
      return new Response(JSON.stringify({ error: "Failed to update wake request" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // If confirmed, notify the sender
    if (action === "confirm") {
      // Get sender's devices
      const { data: senderDevices } = await supabase
        .from("user_devices")
        .select("device_token")
        .eq("user_id", wakeRequest.sender_id);

      // Send confirmation push to sender
      if (senderDevices) {
        for (const device of senderDevices) {
          await sendConfirmationPush(device.device_token, requestId);
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        status: updates.status,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Error handling wake response:", error);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

async function sendConfirmationPush(deviceToken: string, requestId: string) {
  // Send confirmation push to the sender
  console.log("Sending confirmation to:", deviceToken, "for request:", requestId);
}