// @ts-nocheck — Deno runtime globals not available in local TS config
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const traceId = crypto.randomUUID();

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ success: false, error: "Missing authorization" }, 401);
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: user, error: userError } = await supabase.auth.getUser(token);
    if (userError || !user.user) return json({ success: false, error: "Invalid token" }, 401);

    const receiverId = user.user.id;
    const body = await req.json();

    // Accept both naming conventions for backward compat
    const wakeRequestId: string = body.wakeRequestId || body.requestId;
    const rawAction: string = body.action;
    const snoozeMinutes: number = body.snoozeMinutes ?? 5;
    const responseMessage: string | null = body.message ?? null;

    if (!wakeRequestId || !rawAction) {
      return json({ success: false, error: "Missing wakeRequestId or action", traceId }, 400);
    }

    // Normalize action names (accept both short and full forms)
    const action = normalizeAction(rawAction);
    if (!action) {
      return json({ success: false, error: `Invalid action '${rawAction}'. Use confirmed|snoozed|dismissed`, traceId }, 400);
    }

    // Fetch wake request — receiver must own it
    const { data: wakeRequest, error: fetchError } = await supabase
      .from("wake_requests")
      .select("*")
      .eq("id", wakeRequestId)
      .eq("receiver_id", receiverId)
      .single();

    if (fetchError || !wakeRequest) {
      return json({ success: false, error: "Wake request not found or not yours", traceId }, 404);
    }

    const now = new Date().toISOString();
    const updates: Record<string, unknown> = {
      status: action,
      response_action: action,
      response_message: responseMessage,
      responded_at: now,
      updated_at: now,
    };

    if (action === "snoozed") {
      const snoozeUntil = new Date(Date.now() + snoozeMinutes * 60 * 1000).toISOString();
      updates.snooze_until = snoozeUntil;
      updates.snoozed_at = now;          // backward compat column
    } else if (action === "confirmed") {
      updates.confirmed_at = now;        // backward compat column
    } else if (action === "dismissed") {
      updates.dismissed_at = now;        // backward compat column
    }

    const { error: updateError } = await supabase
      .from("wake_requests")
      .update(updates)
      .eq("id", wakeRequestId);

    if (updateError) {
      console.error("[wake-response] DB update failed:", updateError);
      return json({ success: false, error: "Failed to update wake request", traceId }, 500);
    }

    // Notify sender on all actions
    const receiverName = user.user.user_metadata?.display_name
      || user.user.email?.split("@")[0]
      || "Someone";

    const { data: senderDevices } = await supabase
      .from("user_devices")
      .select("id, device_token, platform")
      .eq("user_id", wakeRequest.sender_id)
      .eq("is_active", true);

    if (senderDevices && senderDevices.length > 0) {
      await Promise.all(
        senderDevices.map((d) =>
          sendResponsePush(d.device_token, d.platform, d.id, receiverName, action, snoozeMinutes, wakeRequestId, supabase)
        )
      );
    }

    console.log(`[wake-response] traceId=${traceId} wakeRequestId=${wakeRequestId} action=${action}`);

    return json({
      success: true,
      wakeRequestId,
      status: action,
      respondedAt: now,
      traceId,
    });
  } catch (err) {
    console.error("[wake-response] Unexpected error:", err);
    return json({ success: false, error: "Internal server error", traceId }, 500);
  }
});

function normalizeAction(raw: string): string | null {
  const map: Record<string, string> = {
    confirmed: "confirmed", confirm: "confirmed",
    snoozed: "snoozed", snooze: "snoozed",
    dismissed: "dismissed", dismiss: "dismissed",
  };
  return map[raw.toLowerCase()] ?? null;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function sendResponsePush(
  deviceToken: string,
  platform: string,
  deviceId: string,
  receiverName: string,
  action: string,
  snoozeMinutes: number,
  wakeRequestId: string,
  supabase: any
) {
  try {
    const title = action === "confirmed" ? "They're Awake! 🌅"
                : action === "snoozed"   ? "Snoozed 💤"
                :                          "Dismissed ❌";
    const body  = action === "confirmed" ? `${receiverName} confirmed they're awake`
                : action === "snoozed"   ? `${receiverName} snoozed for ${snoozeMinutes} minutes`
                :                          `${receiverName} dismissed the alarm`;

    if (platform === "ios") {
      const apnsKeyId     = Deno.env.get("APNS_KEY_ID");
      const apnsTeamId    = Deno.env.get("APNS_TEAM_ID");
      const apnsPrivateKey = Deno.env.get("APNS_PRIVATE_KEY")?.replace(/\\n/g, "\n");
      if (!apnsKeyId || !apnsTeamId || !apnsPrivateKey) return;

      const jwt = await generateAPNsJWT(apnsKeyId, apnsTeamId, apnsPrivateKey);
      const payload = {
        aps: { alert: { title, body }, sound: "default", badge: 0 },
        type: "wake_response",
        responseAction: action,
        wakeRequestId,
        receiverName,
        snoozeMinutes,
      };

      const apnsHost = Deno.env.get("APNS_HOST") ?? "api.push.apple.com";
      const r = await fetch(`https://${apnsHost}/3/device/${deviceToken}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${jwt}`,
          "apns-topic": "com.wakeupsunshine.app",
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        body: JSON.stringify(payload),
      });
      if (!r.ok) console.error(`[wake-response] APNs error ${r.status}: ${await r.text()}`);
    } else if (platform === "android") {
      const fcmProjectId     = Deno.env.get("FCM_PROJECT_ID");
      const fcmServiceAccount = Deno.env.get("FCM_SERVICE_ACCOUNT");
      if (!fcmProjectId || !fcmServiceAccount) return;

      const accessToken = await getFCMAccessToken(fcmServiceAccount);
      const r = await fetch(
        `https://fcm.googleapis.com/v1/projects/${fcmProjectId}/messages:send`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${accessToken}`,
          },
          body: JSON.stringify({
            message: {
              token: deviceToken,
              data: {
                type: "wake_response",
                response_action: action,
                wake_request_id: wakeRequestId,
                receiver_name: receiverName,
                snooze_minutes: String(snoozeMinutes),
              },
              android: { priority: "high" },
            },
          }),
        }
      );
      if (!r.ok) {
        const errText = await r.text();
        console.error(`[wake-response] FCM error ${r.status}: ${errText}`);
        if (parseFCMUnregistered(errText, r.status)) {
          console.log(`[wake-response] FCM token unregistered for device ${deviceId} — marking inactive`);
          await supabase
            .from("user_devices")
            .update({ is_active: false, last_error: `${r.status}: ${errText}`, updated_at: new Date().toISOString() })
            .eq("id", deviceId);
        }
      }
    }
  } catch (e) {
    console.error("[wake-response] sendResponsePush failed:", e);
  }
}

function parseFCMUnregistered(errorText: string, status: number): boolean {
  if (status === 404) return true;
  try {
    const body = JSON.parse(errorText);
    const errorCode = body?.error?.details?.find((d: any) => d.errorCode)?.errorCode;
    const errorStatus = body?.error?.status;
    return errorCode === "UNREGISTERED" || errorStatus === "NOT_FOUND";
  } catch {
    return errorText.includes("UNREGISTERED") || errorText.includes("NOT_FOUND");
  }
}

async function generateAPNsJWT(keyId: string, teamId: string, privateKey: string) {
  const iat = Math.floor(Date.now() / 1000);
  const h64 = toB64U(JSON.stringify({ alg: "ES256", kid: keyId }));
  const p64 = toB64U(JSON.stringify({ iss: teamId, iat }));
  const inp = `${h64}.${p64}`;

  const pemBody = privateKey
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");

  console.log(`[generateAPNsJWT] kid=${keyId} iss=${teamId} iat=${iat} pemBodyLen=${pemBody.length}`);

  const keyBytes = b64ToBytes(pemBody);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes.buffer as ArrayBuffer,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign({ name: "ECDSA", hash: { name: "SHA-256" } }, key, new TextEncoder().encode(inp));
  return `${inp}.${bytesToB64U(new Uint8Array(sig))}`;
}

async function getFCMAccessToken(serviceAccountJson: string) {
  const sa  = JSON.parse(serviceAccountJson);
  const now = Math.floor(Date.now() / 1000);
  const enc = new TextEncoder();
  const h64 = toB64U(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const c64 = toB64U(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now, exp: now + 3600,
  }));
  const inp = `${h64}.${c64}`;
  const pem = sa.private_key.replace(/-----.*?-----/g, "").replace(/\n/g, "");
  const key = await crypto.subtle.importKey(
    "pkcs8", b64ToBytes(pem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]
  );
  const sig = await crypto.subtle.sign({ name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, key, enc.encode(inp));
  const jwt = `${inp}.${bytesToB64U(new Uint8Array(sig))}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });
  const d = await res.json();
  if (!d.access_token) throw new Error(`FCM token exchange failed: ${JSON.stringify(d)}`);
  return d.access_token;
}

function b64ToBytes(b: string): Uint8Array {
  const s = atob(b); const a = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) a[i] = s.charCodeAt(i);
  return a;
}
function toB64U(s: string) {
  return btoa(unescape(encodeURIComponent(s))).replace(/\+/g,"-").replace(/\//g,"_").replace(/=/g,"");
}
function bytesToB64U(b: Uint8Array) {
  return btoa(String.fromCharCode(...b)).replace(/\+/g,"-").replace(/\//g,"_").replace(/=/g,"");
}
