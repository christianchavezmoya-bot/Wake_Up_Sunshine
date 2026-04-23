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

    // iOS APNs credentials
    const apnsKeyId = Deno.env.get("APNS_KEY_ID");
    const apnsTeamId = Deno.env.get("APNS_TEAM_ID");
    const apnsPrivateKey = Deno.env.get("APNS_PRIVATE_KEY")?.replace(/\\n/g, "\n");

    // Android FCM credentials
    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY");

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

    // Get receiver's devices (all devices, not just primary)
    const { data: devices, error: deviceError } = await supabase
      .from("user_devices")
      .select("*")
      .eq("user_id", targetUserId);

    if (deviceError || !devices || devices.length === 0) {
      return new Response(JSON.stringify({ error: "Receiver has no registered devices" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get sender's display name
    const senderName = user.user.user_metadata?.display_name || user.user.email?.split('@')[0] || "Someone";

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

    // Send push notifications to all devices
    const pushPromises = devices.map(device => {
      if (device.platform === 'ios' && apnsKeyId && apnsTeamId && apnsPrivateKey) {
        return sendAPNsNotification(device.device_token, {
          requestId: wakeRequest.id,
          senderId: senderId,
          senderName: senderName,
          message: message,
          urgency: urgency,
        });
      } else if (device.platform === 'android' && fcmServerKey) {
        return sendFCMNotification(device.device_token, {
          requestId: wakeRequest.id,
          senderId: senderId,
          senderName: senderName,
          message: message,
          urgency: urgency,
        });
      } else {
        console.log(`Skipping device ${device.id}: missing credentials for ${device.platform}`);
        return Promise.resolve();
      }
    });

    await Promise.all(pushPromises);

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
        devicesNotified: devices.length,
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

// iOS APNs notification
async function sendAPNsNotification(deviceToken: string, payload: any) {
  try {
    const apnsKeyId = Deno.env.get("APNS_KEY_ID")!;
    const apnsTeamId = Deno.env.get("APNS_TEAM_ID")!;
    const apnsPrivateKey = Deno.env.get("APNS_PRIVATE_KEY")!.replace(/\\n/g, "\n");

    // Generate JWT for APNs authentication
    const jwt = await generateAPNsJWT(apnsKeyId, apnsTeamId, apnsPrivateKey);

    // Build APNs payload
    const apnsPayload = {
      aps: {
        "alert": {
          "title": "Wake Up! 🌅",
          "body": `${payload.senderName} is trying to wake you`,
          "launch-image": "alarm",
        },
        "sound": "criticalalarm.caf",
        "badge": 1,
        "interruption-level": "critical",
        "content-available": 1,
      },
      "requestId": payload.requestId,
      "senderId": payload.senderId,
      "senderName": payload.senderName,
      "message": payload.message || "",
      "urgency": payload.urgency,
    };

    // Send to APNs
    const response = await fetch(`https://api.push.apple.com/3/device/${deviceToken}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${jwt}`,
        "apns-topic": "com.wakeupsunshine.app",
        "apns-priority": "10",
        "apns-push-type": "alert",
      },
      body: JSON.stringify(apnsPayload),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`APNs error: ${response.status} - ${errorText}`);
    }

    return response.ok;
  } catch (error) {
    console.error("APNs notification failed:", error);
    return false;
  }
}

// Generate APNs JWT
async function generateAPNsJWT(keyId: string, teamId: string, privateKey: string): Promise<string> {
  const header = { alg: "ES256", kid: keyId };
  const payload = { iss: teamId, iat: Math.floor(Date.now() / 1000) };

  const encoder = new TextEncoder();
  const headerBase64 = btoa(JSON.stringify(header)).replace(/=/g, "");
  const payloadBase64 = btoa(JSON.stringify(payload)).replace(/=/g, "");

  const signingInput = `${headerBase64}.${payloadBase64}`;

  // Import the private key
  const keyData = `-----BEGIN PRIVATE KEY-----\n${privateKey}\n-----END PRIVATE KEY-----`;
  const cryptoKey = await crypto.subtle.importKey(
    "pem",
    new TextEncoder().encode(keyData),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    cryptoKey,
    encoder.encode(signingInput)
  );

  const signatureBase64 = btoa(String.fromCharCode(...new Uint8Array(signature))).replace(/=/g, "");
  return `${signingInput}.${signatureBase64}`;
}

// Android FCM notification
async function sendFCMNotification(deviceToken: string, payload: any) {
  try {
    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY");
    if (!fcmServerKey) {
      console.log("FCM server key not configured");
      return false;
    }

    const fcmPayload = {
      to: deviceToken,
      priority: "high",
      data: {
        requestId: payload.requestId,
        senderId: payload.senderId,
        senderName: payload.senderName,
        message: payload.message || "",
        urgency: payload.urgency,
        type: "wake_alarm",
      },
      notification: {
        title: "Wake Up! 🌅",
        body: `${payload.senderName} is trying to wake you`,
        sound: "default",
        tag: "wake_alarm",
        priority: "max",
      },
      android: {
        priority: "high",
        notification: {
          channel_id: "wake_alarm_channel",
          sound: "default",
          priority: "max",
          default_vibrate_timings": true,
        },
      },
    };

    const response = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `key=${fcmServerKey}`,
      },
      body: JSON.stringify(fcmPayload),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`FCM error: ${response.status} - ${errorText}`);
    }

    return response.ok;
  } catch (error) {
    console.error("FCM notification failed:", error);
    return false;
  }
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