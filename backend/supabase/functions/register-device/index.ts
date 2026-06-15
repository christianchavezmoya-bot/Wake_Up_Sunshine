// @ts-nocheck — Deno runtime globals not available in local TS config
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface RegisterDeviceRequest {
  token: string;
  platform: 'ios' | 'android';
  deviceType?: string;
  deviceName?: string;
  isPrimary?: boolean;
}

function defaultDeviceName(platform: 'ios' | 'android', deviceType?: string) {
  if (platform === 'ios') {
    switch (deviceType) {
      case 'ipad':
        return 'iPad';
      case 'watch':
        return 'Apple Watch';
      default:
        return 'iPhone';
    }
  }
  return 'Android Device';
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const traceId = crypto.randomUUID();
  
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

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

    const userId = user.user.id;
    const userEmail = user.user.email;

    // Parse request body
    const body: RegisterDeviceRequest = await req.json();
    const { 
      token: deviceToken, 
      platform, 
      deviceType = platform === 'ios' ? 'iphone' : 'android',
      deviceName,
      isPrimary = true 
    } = body;
    const normalizedDeviceName =
      typeof deviceName === 'string' && deviceName.trim().length > 0
        ? deviceName.trim().slice(0, 100)
        : defaultDeviceName(platform, deviceType);

    if (!deviceToken) {
      return new Response(JSON.stringify({ 
        error: "Missing device token",
        traceId 
      }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!platform || !['ios', 'android'].includes(platform)) {
      return new Response(JSON.stringify({ 
        error: "Invalid platform. Must be 'ios' or 'android'",
        traceId 
      }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    console.log(`[register-device] traceId=${traceId} userId=${userId} email=${userEmail} platform=${platform} token=${deviceToken.substring(0, 8)}...`);

    // Log debug event
    await supabase.rpc('log_debug_event', {
      p_trace_id: traceId,
      p_event_type: 'register_device_start',
      p_message: `Registering device for user ${userEmail}`,
      p_metadata: { 
        platform, 
        deviceType, 
        deviceName: normalizedDeviceName,
        isPrimary,
        tokenPrefix: deviceToken.substring(0, 8),
        tokenSuffix: deviceToken.substring(deviceToken.length - 6)
      },
      p_platform: platform,
      p_user_id: userId
    });

    // Check if user exists in users table, create if not
    const { data: existingUser, error: userCheckError } = await supabase
      .from('users')
      .select('id')
      .eq('id', userId)
      .single();

    if (!existingUser) {
      // Create user record if it doesn't exist
      const { error: createUserError } = await supabase
        .from('users')
        .insert({
          id: userId,
          phone_number: user.user.phone || '',
          display_name: user.user.user_metadata?.display_name || userEmail?.split('@')[0] || 'User'
        });

      if (createUserError) {
        console.log(`[register-device] Created user record: ${userId}`);
      }
    }

    // Upsert device token
    const now = new Date().toISOString();
    const { data: device, error: deviceError } = await supabase
      .from('user_devices')
      .upsert({
        user_id: userId,
        device_token: deviceToken,
        platform: platform,
        device_type: deviceType,
        device_name: normalizedDeviceName,
        is_primary: isPrimary,
        is_active: true,
        last_active_at: now,
        updated_at: now
      }, {
        onConflict: 'user_id,device_token',
        ignoreDuplicates: false
      })
      .select()
      .single();

    if (deviceError) {
      console.error(`[register-device] Error upserting device:`, deviceError);
      
      // Log error
      await supabase.rpc('log_debug_event', {
        p_trace_id: traceId,
        p_event_type: 'register_device_error',
        p_message: `Failed to register device: ${deviceError.message}`,
        p_metadata: { error: deviceError },
        p_platform: 'backend',
        p_user_id: userId
      });

      return new Response(JSON.stringify({ 
        error: "Failed to register device",
        details: deviceError.message,
        traceId 
      }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Log success
    await supabase.rpc('log_debug_event', {
      p_trace_id: traceId,
      p_event_type: 'register_device_success',
      p_message: `Device registered successfully`,
      p_metadata: { 
        deviceId: device.id,
        platform,
        deviceName: device.device_name,
        isPrimary
      },
      p_platform: platform,
      p_user_id: userId
    });

    console.log(`[register-device] Success: deviceId=${device.id} userId=${userId} platform=${platform}`);

    return new Response(
      JSON.stringify({
        success: true,
        deviceId: device.id,
        platform: platform,
        deviceName: device.device_name,
        traceId,
        message: "Device registered successfully"
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("[register-device] Error:", error);
    
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
