// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-device-id",
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

    const currentDeviceId = req.headers.get("x-device-id")?.trim() || null;

    const { data: auth, error: authErr } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", "")
    );
    if (authErr || !auth.user) return json({ success: false, error: "Invalid token" }, 401);

    const { data: devices, error } = await supabase
      .from("user_devices")
      .select("id, platform, device_type, device_name, is_primary, critical_alerts_enabled, is_active, last_active_at, updated_at, created_at")
      .eq("user_id", auth.user.id)
      .order("last_active_at", { ascending: false, nullsFirst: false })
      .order("updated_at", { ascending: false, nullsFirst: false });

    if (error) {
      console.error("[get-devices] query failed", error);
      return json({ success: false, error: "Failed to load devices" }, 500);
    }

    return json({
      success: true,
      devices: (devices || []).map((device) => ({
        id: device.id,
        platform: device.platform || "ios",
        deviceType: device.device_type || (device.platform === "android" ? "android" : "iphone"),
        deviceName: device.device_name || (device.platform === "android" ? "Android Device" : "iPhone"),
        isPrimary: !!device.is_primary,
        criticalAlertsEnabled: !!device.critical_alerts_enabled,
        isActive: !!device.is_active,
        isCurrent: currentDeviceId ? device.id === currentDeviceId : false,
        lastActiveAt: device.last_active_at,
        updatedAt: device.updated_at,
        createdAt: device.created_at,
      })),
    });
  } catch (err) {
    console.error("[get-devices]", err);
    return json({ success: false, error: "Internal server error" }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
