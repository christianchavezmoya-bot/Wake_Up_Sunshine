// @ts-nocheck — Deno runtime globals not available in local TS config
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Retry helper for rate-limited requests
async function withRetry<T>(
  fn: () => Promise<T>,
  options: {
    maxRetries?: number;
    baseDelayMs?: number;
    name?: string;
  } = {}
): Promise<T> {
  const { maxRetries = 3, baseDelayMs = 1000, name = 'operation' } = options;
  let lastError: Error | null = null;
  
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      
      // Check if it's a rate limit error
      const isRateLimit = 
        error?.status === 429 || 
        error?.name === 'RateLimitError' ||
        error?.message?.includes('429') ||
        error?.message?.includes('rate limit');
      
      if (!isRateLimit || attempt === maxRetries) {
        throw error;
      }
      
      // Calculate delay with exponential backoff
      const delayMs = baseDelayMs * Math.pow(2, attempt);
      console.log(`[withRetry] ${name} rate limited, retrying in ${delayMs}ms (attempt ${attempt + 1}/${maxRetries})`);
      
      await new Promise(resolve => setTimeout(resolve, delayMs));
    }
  }
  
  throw lastError;
}

// Allowed alarm sound IDs - must match iOS and Android AlarmSound enum
const ALLOWED_ALARM_SOUNDS = [
  'wake_up',
  'hey_you',
  'minions',
  'classic',
] as const;

type AlarmSoundId = typeof ALLOWED_ALARM_SOUNDS[number];

interface WakeRequestBody {
  targetUserId: string;
  message?: string;
  urgency?: "low" | "normal" | "high" | "emergency";
  alarmSoundId?: string;
}

// Helper function to log debug events
async function logDebugEvent(
  supabase: any,
  traceId: string,
  eventType: string,
  message: string,
  metadata: any = {},
  platform: string = 'backend',
  userId: string | null = null
) {
  try {
    await supabase.rpc('log_debug_event', {
      p_trace_id: traceId,
      p_event_type: eventType,
      p_message: message,
      p_metadata: metadata,
      p_platform: platform,
      p_user_id: userId
    });
  } catch (e) {
    console.error(`[send-wake] Failed to log debug event:`, e);
  }
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const traceId = crypto.randomUUID();
  const startTime = Date.now();

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // iOS APNs credentials
    const apnsKeyId = Deno.env.get("APNS_KEY_ID");
    const apnsTeamId = Deno.env.get("APNS_TEAM_ID");
    const apnsPrivateKey = Deno.env.get("APNS_PRIVATE_KEY")?.replace(/\\n/g, "\n");
    const enableCriticalAlerts = Deno.env.get("ENABLE_CRITICAL_ALERTS") === "true";

    // Android FCM credentials
    const fcmProjectId = Deno.env.get("FCM_PROJECT_ID");
    const fcmServiceAccount = Deno.env.get("FCM_SERVICE_ACCOUNT");

    // Create Supabase client with service role
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get auth header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ 
        error: "Missing authorization",
        traceId 
      }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get current user
    const token = authHeader.replace("Bearer ", "");
    const { data: user, error: userError } = await supabase.auth.getUser(token);

    if (userError || !user.user) {
      return new Response(JSON.stringify({ 
        error: "Invalid token",
        traceId 
      }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const senderId = user.user.id;
    const senderEmail = user.user.email;

    // Log function start
    console.log(`[send-wake] traceId=${traceId} START senderId=${senderId} senderEmail=${senderEmail}`);
    await logDebugEvent(supabase, traceId, 'send_wake_start', 'Wake request started', {
      senderId,
      senderEmail
    }, 'backend', senderId);

    // Parse request body
    const body: WakeRequestBody = await req.json();
    const { targetUserId, message, urgency = "normal", alarmSoundId } = body;

    console.log(`[send-wake] traceId=${traceId} targetUserId=${targetUserId} urgency=${urgency} alarmSoundId=${alarmSoundId}`);

    if (!targetUserId) {
      await logDebugEvent(supabase, traceId, 'send_wake_validation_error', 'Missing targetUserId', {
        body
      }, 'backend', senderId);

      return new Response(JSON.stringify({ 
        error: "Missing targetUserId",
        traceId 
      }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Validate and normalize alarmSoundId
    const validatedAlarmSoundId: AlarmSoundId = validateAlarmSound(alarmSoundId);

    // Check permission
    console.log(`[send-wake] traceId=${traceId} Checking permission: granter_id=${targetUserId} trustee_id=${senderId}`);
    const { data: permission, error: permissionError } = await supabase
      .from("wake_permissions")
      .select("*")
      .eq("granter_id", targetUserId)
      .eq("trustee_id", senderId)
      .eq("status", "active")
      .single();

    const permissionFound = !permissionError && !!permission;
    
    await logDebugEvent(supabase, traceId, 'send_wake_permission_check', 'Permission check result', {
      permissionFound,
      permissionError: permissionError?.message,
      permissionId: permission?.id
    }, 'backend', senderId);

    if (permissionError || !permission) {
      console.log(`[send-wake] traceId=${traceId} Permission denied`);
      return new Response(JSON.stringify({ 
        error: "Permission denied",
        traceId,
        debug: {
          permissionFound: false,
          reason: permissionError?.message || "No active permission found"
        }
      }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check rate limit (relaxed for development)
    const { data: rateLimit, error: rateLimitError } = await supabase
      .from("rate_limits")
      .select("*")
      .eq("sender_id", senderId)
      .eq("target_id", targetUserId)
      .single();

    if (rateLimit?.is_blocked) {
      await logDebugEvent(supabase, traceId, 'send_wake_rate_limited', 'User is blocked', {
        reason: 'blocked'
      }, 'backend', senderId);
      
      return new Response(JSON.stringify({ 
        error: "You have been blocked from sending wake requests to this user",
        traceId 
      }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check daily limit (500 for development)
    if (rateLimit && rateLimit.requests_today >= 500 && isSameDay(rateLimit.last_request_at)) {
      await logDebugEvent(supabase, traceId, 'send_wake_rate_limited', 'Daily limit exceeded', {
        reason: 'daily_limit',
        requestsToday: rateLimit.requests_today
      }, 'backend', senderId);
      
      return new Response(JSON.stringify({ 
        error: "Daily limit exceeded (50 requests per day)",
        traceId 
      }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check cooldown (reduced to 1 minute for development)
    if (rateLimit?.last_request_at && !isCooldownComplete(rateLimit.last_request_at)) {
      const remainingMinutes = getRemainingCooldown(rateLimit.last_request_at);
      await logDebugEvent(supabase, traceId, 'send_wake_rate_limited', 'Cooldown active', {
        reason: 'cooldown',
        remainingMinutes
      }, 'backend', senderId);

      return new Response(JSON.stringify({
        error: `Please wait ${remainingMinutes} minute(s) before sending another wake request`,
        traceId
      }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Anti-spam: block if there is already an active (unanswered) wake request
    // within the last 2 minutes for the same sender→receiver pair.
    const activeWindow = new Date(Date.now() - 2 * 60 * 1000).toISOString();
    const { data: activeRequest } = await supabase
      .from("wake_requests")
      .select("id, status, created_at")
      .eq("sender_id", senderId)
      .eq("receiver_id", targetUserId)
      .in("status", ["pending", "sent", "delivered", "snoozed"])
      .gte("created_at", activeWindow)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (activeRequest) {
      const sentMs     = new Date(activeRequest.created_at).getTime();
      const elapsedSec = Math.floor((Date.now() - sentMs) / 1000);
      const retryAfter = Math.max(0, 120 - elapsedSec);

      await logDebugEvent(supabase, traceId, 'send_wake_rate_limited', 'Active wake request exists', {
        reason: 'active_request',
        activeWakeRequestId: activeRequest.id,
        retryAfterSeconds: retryAfter
      }, 'backend', senderId);

      return new Response(JSON.stringify({
        success: false,
        error: "Wake request already active. Wait for a response or timeout.",
        activeWakeRequestId: activeRequest.id,
        retryAfterSeconds: retryAfter,
        traceId,
      }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get receiver's devices (all devices, not just primary)
    console.log(`[send-wake] traceId=${traceId} Looking up devices for user ${targetUserId}`);
    const { data: devices, error: deviceError } = await supabase
      .from("user_devices")
      .select("*")
      .eq("user_id", targetUserId)
      .eq("is_active", true);

    const devicesFound = devices?.length || 0;
    const iosDevices = devices?.filter(d => d.platform === 'ios') || [];
    const androidDevices = devices?.filter(d => d.platform === 'android') || [];

    await logDebugEvent(supabase, traceId, 'send_wake_device_lookup', 'Device lookup result', {
      devicesFound,
      iosDevices: iosDevices.length,
      androidDevices: androidDevices.length,
      deviceError: deviceError?.message,
      deviceDetails: devices?.map(d => ({
        id: d.id,
        platform: d.platform,
        hasToken: !!d.device_token,
        tokenPrefix: d.device_token?.substring(0, 8),
        tokenSuffix: d.device_token?.substring(d.device_token.length - 6)
      }))
    }, 'backend', senderId);

    console.log(`[send-wake] traceId=${traceId} devicesFound=${devicesFound} ios=${iosDevices.length} android=${androidDevices.length}`);

    if (deviceError || !devices || devices.length === 0) {
      console.log(`[send-wake] traceId=${traceId} No devices found for target user`);
      return new Response(JSON.stringify({ 
        error: "Receiver has no registered devices",
        traceId,
        debug: {
          permissionFound: true,
          devicesFound: 0,
          pushAttempted: false,
          reason: deviceError?.message || "No active devices found for target user"
        }
      }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get sender's display name
    const senderName = user.user.user_metadata?.display_name || user.user.email?.split('@')[0] || "Someone";

    // Check for existing wake request with same trace_id (idempotency)
    const { data: existingRequest } = await supabase
      .from("wake_requests")
      .select("*")
      .eq("trace_id", traceId)
      .single();

    let wakeRequest;
    
    if (existingRequest) {
      // Use existing request (idempotent retry)
      wakeRequest = existingRequest;
      console.log(`[send-wake] traceId=${traceId} Using existing wake request: ${wakeRequest.id}`);
      
      await logDebugEvent(supabase, traceId, 'send_wake_request_reused', 'Reused existing wake request (idempotent)', {
        wakeRequestId: wakeRequest.id
      }, 'backend', senderId);
    } else {
      // Create new wake request with trace_id for idempotency
      const { data: newRequest, error: wakeError } = await supabase
        .from("wake_requests")
        .insert({
          sender_id: senderId,
          receiver_id: targetUserId,
          message: message || null,
          urgency: urgency,
          alarm_sound_id: validatedAlarmSoundId,
          status: "pending",
          trace_id: traceId,
        })
        .select()
        .single();

      if (wakeError || !newRequest) {
        console.error(`[send-wake] traceId=${traceId} Failed to create wake request:`, wakeError);
        
        await logDebugEvent(supabase, traceId, 'send_wake_request_error', 'Failed to create wake request', {
          error: wakeError?.message
        }, 'backend', senderId);

        return new Response(JSON.stringify({ 
          error: "Failed to create wake request",
          traceId 
        }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      
      wakeRequest = newRequest;
    }

    await logDebugEvent(supabase, traceId, 'send_wake_request_created', 'Wake request created', {
      wakeRequestId: wakeRequest.id,
      senderId,
      targetUserId,
      alarmSoundId: validatedAlarmSoundId
    }, 'backend', senderId);

    console.log(`[send-wake] traceId=${traceId} Wake request created: ${wakeRequest.id}`);

    // Track push results
    const pushResults: {
      apns: { attempted: boolean; success: boolean; error?: string; devices: number; successCount: number };
      fcm: { attempted: boolean; success: boolean; error?: string; devices: number; successCount: number };
    } = {
      apns: { attempted: false, success: false, devices: 0, successCount: 0 },
      fcm: { attempted: false, success: false, devices: 0, successCount: 0 }
    };
    let successfulPushCount = 0;

    // Send push notifications to all devices
    const pushPromises = devices.map(async (device) => {
      const pushTraceId = crypto.randomUUID();

      if (device.platform === 'ios' && apnsKeyId && apnsTeamId && apnsPrivateKey && device.device_token) {
        pushResults.apns.attempted = true;
        pushResults.apns.devices++;

        console.log(`[send-wake] traceId=${traceId} Sending APNs to device ${device.id}`);

        try {
          const result = await sendAPNsNotification(device.device_token, {
            requestId: wakeRequest.id,
            traceId: pushTraceId,
            senderId: senderId,
            senderName: senderName,
            message: message,
            urgency: urgency,
            alarmSoundId: validatedAlarmSoundId,
          }, { apnsKeyId, apnsTeamId, apnsPrivateKey, enableCriticalAlerts });

          if (result.success) {
            pushResults.apns.success = true;
            pushResults.apns.successCount++;
            successfulPushCount++;
          } else {
            pushResults.apns.error = result.error;
          }

          await logDebugEvent(supabase, traceId, 'send_wake_apns_result', 'APNs push result', {
            deviceId: device.id,
            pushTraceId,
            success: result.success,
            error: result.error,
            apns_payload_mode: result.payloadMode ?? "normal",
            tokenPrefix: device.device_token?.substring(0, 8)
          }, 'backend', senderId);
        } catch (e) {
          pushResults.apns.error = e.message;
          console.error(`[send-wake] traceId=${traceId} APNs error:`, e);
        }
      } else if (device.platform === 'android' && fcmProjectId && fcmServiceAccount && device.device_token) {
        pushResults.fcm.attempted = true;
        pushResults.fcm.devices++;

        console.log(`[send-wake] traceId=${traceId} Sending FCM to device ${device.id} token=${device.device_token.substring(0, 8)}...`);

        try {
          const result = await sendFCMNotification(device.device_token, {
            requestId: wakeRequest.id,
            traceId: pushTraceId,
            senderId: senderId,
            senderName: senderName,
            message: message,
            urgency: urgency,
            alarmSoundId: validatedAlarmSoundId,
          }, { fcmProjectId, fcmServiceAccount });

          if (result.success) {
            pushResults.fcm.success = true;
            pushResults.fcm.successCount++;
            successfulPushCount++;
          } else {
            pushResults.fcm.error = result.error;
            if (result.isUnregistered) {
              console.log(`[send-wake] fcm_token_unregistered device=${device.id} — marking inactive`);
              await logDebugEvent(supabase, traceId, 'fcm_token_unregistered', 'FCM token unregistered — deactivating device', {
                deviceId: device.id,
                tokenPrefix: device.device_token?.substring(0, 8),
                error: result.error
              }, 'backend', senderId);
              await supabase
                .from("user_devices")
                .update({ is_active: false, last_error: result.error, updated_at: new Date().toISOString() })
                .eq("id", device.id);
              await logDebugEvent(supabase, traceId, 'user_device_deactivated', 'Device marked inactive due to unregistered token', {
                deviceId: device.id,
                platform: 'android'
              }, 'backend', senderId);
            }
          }

          await logDebugEvent(supabase, traceId, 'send_wake_fcm_result', 'FCM push result', {
            deviceId: device.id,
            pushTraceId,
            success: result.success,
            isUnregistered: result.isUnregistered ?? false,
            error: result.error,
            tokenPrefix: device.device_token?.substring(0, 8)
          }, 'backend', senderId);
        } catch (e) {
          pushResults.fcm.error = e.message;
          console.error(`[send-wake] traceId=${traceId} FCM error:`, e);
        }
      } else {
        console.log(`[send-wake] traceId=${traceId} Skipping device ${device.id}: missing credentials for ${device.platform} or no token`);

        await logDebugEvent(supabase, traceId, 'send_wake_device_skipped', 'Device skipped', {
          deviceId: device.id,
          platform: device.platform,
          hasApnsCredentials: !!(apnsKeyId && apnsTeamId && apnsPrivateKey),
          hasFcmCredentials: !!(fcmProjectId && fcmServiceAccount),
          hasToken: !!device.device_token
        }, 'backend', senderId);
      }
    });

    await Promise.all(pushPromises);

    const activeDeviceCount = devices.length;
    const deliverySucceeded = successfulPushCount > 0;

    await logDebugEvent(supabase, traceId, 'send_wake_push_summary', 'Push delivery summary', {
      activeDeviceCount,
      successfulDeviceCount: successfulPushCount,
      apnsSuccessCount: pushResults.apns.successCount,
      fcmSuccessCount: pushResults.fcm.successCount,
    }, 'backend', senderId);

    console.log(`[send-wake] traceId=${traceId} activeDeviceCount=${activeDeviceCount} successfulDeviceCount=${successfulPushCount}`);

    // Update wake request status based on delivery outcome
    const finalStatus = deliverySucceeded ? "delivered" : "pending_delivery";
    await supabase
      .from("wake_requests")
      .update({ status: finalStatus, delivered_at: deliverySucceeded ? new Date().toISOString() : null })
      .eq("id", wakeRequest.id);

    // Update rate limit
    await updateRateLimit(supabase, senderId, targetUserId);

    const duration = Date.now() - startTime;

    await logDebugEvent(supabase, traceId, 'send_wake_complete', 'Wake request completed', {
      wakeRequestId: wakeRequest.id,
      duration,
      pushResults,
      successfulPushCount,
      deliverySucceeded
    }, 'backend', senderId);

    console.log(`[send-wake] traceId=${traceId} COMPLETE duration=${duration}ms successfulPushCount=${successfulPushCount}`);

    if (!deliverySucceeded) {
      return new Response(
        JSON.stringify({
          success: false,
          requestId: wakeRequest.id,
          traceId,
          status: "pending_delivery",
          devicesNotified: 0,
          alarmSoundId: validatedAlarmSoundId,
          error: "No active device could be notified — tokens may be stale. Ask the recipient to reopen the app.",
          debug: {
            permissionFound: true,
            devicesFound,
            iosDevices: iosDevices.length,
            androidDevices: androidDevices.length,
            pushAttempted: pushResults.apns.attempted || pushResults.fcm.attempted,
            apns: pushResults.apns,
            fcm: pushResults.fcm,
            duration
          }
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        requestId: wakeRequest.id,
        traceId,
        status: "delivered",
        devicesNotified: successfulPushCount,
        alarmSoundId: validatedAlarmSoundId,
        debug: {
          permissionFound: true,
          devicesFound,
          iosDevices: iosDevices.length,
          androidDevices: androidDevices.length,
          pushAttempted: pushResults.apns.attempted || pushResults.fcm.attempted,
          apns: pushResults.apns,
          fcm: pushResults.fcm,
          duration
        }
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("[send-wake] Error:", error);
    
    return new Response(JSON.stringify({ 
      error: "Internal server error",
      details: error.message,
      traceId 
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

// Validate alarm sound ID
function validateAlarmSound(alarmSoundId: string | undefined): AlarmSoundId {
  if (!alarmSoundId) {
    return 'classic';
  }

  if (ALLOWED_ALARM_SOUNDS.includes(alarmSoundId as AlarmSoundId)) {
    return alarmSoundId as AlarmSoundId;
  }

  console.warn(`Invalid alarmSoundId "${alarmSoundId}", defaulting to classic`);
  return 'classic';
}

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
  // Reduced to 1 minute for development
  return diffMinutes >= 1;
}

function getRemainingCooldown(lastRequest: string): number {
  const last = new Date(lastRequest);
  const now = new Date();
  const diffMinutes = (now.getTime() - last.getTime()) / (1000 * 60);
  const remaining = Math.ceil(1 - diffMinutes);
  return Math.max(1, remaining);
}

// iOS APNs notification — uses sandbox endpoint for development builds
async function sendAPNsNotification(
  deviceToken: string,
  payload: any,
  credentials: { apnsKeyId: string; apnsTeamId: string; apnsPrivateKey: string; enableCriticalAlerts?: boolean }
): Promise<{ success: boolean; error?: string; payloadMode?: string }> {
  try {
    const { apnsKeyId, apnsTeamId, apnsPrivateKey, enableCriticalAlerts = false } = credentials;

    const jwt = await generateAPNsJWT(apnsKeyId, apnsTeamId, apnsPrivateKey);
    const soundFile = mapAlarmSoundToIOS(payload.alarmSoundId);
    const payloadMode = enableCriticalAlerts ? "critical" : "normal";

    // Use sandbox for development builds (aps-environment = development)
    const apnsHost = "api.sandbox.push.apple.com";

    const aps: Record<string, any> = {
      alert: {
        title: "Wake Up! 🌅",
        body: `${payload.senderName} is trying to wake you`,
      },
      badge: 1,
      "content-available": 1,
    };

    if (enableCriticalAlerts) {
      // Critical alert payload — overrides silent switch (requires Apple entitlement)
      aps.sound = { critical: 1, name: soundFile, volume: 1.0 };
      aps["interruption-level"] = "critical";
    } else {
      aps.sound = soundFile;
    }

    const apnsPayload = {
      aps,
      type: "wake_request",
      apnsPayloadMode: payloadMode,
      wakeRequestId: payload.requestId,
      requestId: payload.requestId,   // backward compat
      traceId: payload.traceId,
      senderId: payload.senderId,
      senderName: payload.senderName,
      message: payload.message || "",
      urgency: payload.urgency,
      alarmSoundId: payload.alarmSoundId,
    };

    console.log(`[sendAPNsNotification] host=${apnsHost} payloadMode=${payloadMode} token=${deviceToken.substring(0, 8)}...`);

    const response = await fetch(`https://${apnsHost}/3/device/${deviceToken}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${jwt}`,
        "apns-topic": "com.wakeupsunshine.app",
        "apns-priority": "10",
        "apns-push-type": enableCriticalAlerts ? "alert" : "alert",
      },
      body: JSON.stringify(apnsPayload),
    });

    const responseBody = await response.text();
    if (!response.ok) {
      console.error(`[sendAPNsNotification] ${response.status} ${responseBody}`);
      return { success: false, error: `${response.status}: ${responseBody}`, payloadMode };
    }

    console.log(`[sendAPNsNotification] success status=${response.status} payloadMode=${payloadMode}`);
    return { success: true, payloadMode };
  } catch (error) {
    console.error("[sendAPNsNotification] exception:", error);
    return { success: false, error: error.message };
  }
}

// Map alarm sound ID to iOS sound file name
function mapAlarmSoundToIOS(alarmSoundId: AlarmSoundId): string {
  const soundMap: Record<AlarmSoundId, string> = {
    wake_up: "wake_up.caf",
    hey_you: "hey_you.caf",
    minions: "minions.caf",
    classic:  "classic.caf",
  };
  return soundMap[alarmSoundId] || "classic.caf";
}

// Generate APNs JWT using ES256 + PKCS8 key import (Web Crypto standard)
async function generateAPNsJWT(keyId: string, teamId: string, privateKeyPem: string): Promise<string> {
  const iat = Math.floor(Date.now() / 1000);
  const headerB64  = toBase64Url(JSON.stringify({ alg: "ES256", kid: keyId }));
  const payloadB64 = toBase64Url(JSON.stringify({ iss: teamId, iat }));
  const signingInput = `${headerB64}.${payloadB64}`;

  // Strip PEM headers / footers / whitespace then decode to raw bytes
  const pemBody = privateKeyPem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");

  console.log(`[generateAPNsJWT] kid=${keyId} iss=${teamId} iat=${iat} pemBodyLen=${pemBody.length}`);

  const keyBytes = base64ToBytes(pemBody);

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes.buffer as ArrayBuffer,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: { name: "SHA-256" } },
    cryptoKey,
    new TextEncoder().encode(signingInput)
  );

  return `${signingInput}.${bytesToBase64Url(new Uint8Array(signature))}`;
}

// Android FCM notification using v1 API (OAuth2)
async function sendFCMNotification(
  deviceToken: string,
  payload: any,
  credentials: { fcmProjectId: string; fcmServiceAccount: string }
): Promise<{ success: boolean; error?: string; isUnregistered?: boolean }> {
  try {
    const { fcmProjectId, fcmServiceAccount } = credentials;

    const accessToken = await getFCMAccessToken(fcmServiceAccount);

    const fcmPayload = {
      message: {
        token: deviceToken,
        data: {
          "request_id": payload.requestId,
          "trace_id": payload.traceId,
          "sender_id": payload.senderId,
          "sender_name": payload.senderName,
          "message": payload.message || "",
          "urgency": payload.urgency,
          "alarm_sound_id": payload.alarmSoundId,
          "type": "wake_alarm",
          "wake_request_id": payload.requestId,
          "sent_at": new Date().toISOString(),
        },
        android: { priority: "high" },
      },
    };

    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${fcmProjectId}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${accessToken}`,
        },
        body: JSON.stringify(fcmPayload),
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`FCM v1 error: ${response.status} - ${errorText}`);
      const isUnregistered = parseFCMUnregistered(errorText, response.status);
      return { success: false, error: `${response.status}: ${errorText}`, isUnregistered };
    }

    return { success: true };
  } catch (error) {
    console.error("FCM v1 notification failed:", error);
    return { success: false, error: error.message };
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

// Map alarm sound ID to Android raw resource name
function mapAlarmSoundToAndroid(alarmSoundId: AlarmSoundId): string {
  const soundMap: Record<AlarmSoundId, string> = {
    'wake_up': 'wake_up',
    'hey_you': 'hey_you',
    'minions': 'minions',
    'classic': 'classic',
  };
  return soundMap[alarmSoundId] || 'classic';
}

// Get OAuth2 access token for FCM v1 API
async function getFCMAccessToken(serviceAccountJson: string): Promise<string> {
  const serviceAccount = JSON.parse(serviceAccountJson);

  // Create JWT for OAuth2
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encoder = new TextEncoder();
  const headerBase64 = toBase64Url(JSON.stringify(header));
  const claimsBase64 = toBase64Url(JSON.stringify(claims));
  const signingInput = `${headerBase64}.${claimsBase64}`;

  // Import private key
  const privateKeyPem = serviceAccount.private_key
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\n/g, "");

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    base64ToBytes(privateKeyPem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    cryptoKey,
    encoder.encode(signingInput)
  );

  const signatureBase64 = bytesToBase64Url(new Uint8Array(signature));
  const jwt = `${signingInput}.${signatureBase64}`;

  // Exchange JWT for access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenResponse.json();
  if (!tokenData.access_token) {
    throw new Error(`FCM token exchange failed: ${JSON.stringify(tokenData)}`);
  }
  return tokenData.access_token;
}

// Helper to decode a base64 string to bytes (for PEM key import)
function base64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

// base64url-encode a UTF-8 string (for JWT header/claims)
function toBase64Url(str: string): string {
  return btoa(unescape(encodeURIComponent(str)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");
}

// base64url-encode raw bytes (for JWT signature)
function bytesToBase64Url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");
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