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

function throwIfError(step: string, error: { message?: string } | null) {
  if (error) {
    console.error(`${step}:`, error);
    throw new Error(`${step} failed: ${error.message ?? "Unknown error"}`);
  }
}

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

    // Delete in order to respect foreign key constraints:
    // 1. Wake permissions (sent and received)
    const { error: wpErr } = await supabase
      .from("wake_permissions")
      .delete()
      .or(`user_id.eq.${userId},contact_id.eq.${userId}`);
    throwIfError("delete wake_permissions", wpErr);

    // 2. Contact invites (sent and received)
    const { error: ciErr } = await supabase
      .from("contact_invites")
      .delete()
      .or(`inviter_id.eq.${userId},invitee_id.eq.${userId}`);
    throwIfError("delete contact_invites", ciErr);

    // 3. Wake requests
    const { error: wrErr } = await supabase
      .from("wake_requests")
      .delete()
      .or(`sender_id.eq.${userId},receiver_id.eq.${userId}`);
    throwIfError("delete wake_requests", wrErr);

    // 4. User devices
    const { error: udErr } = await supabase
      .from("user_devices")
      .delete()
      .eq("user_id", userId);
    throwIfError("delete user_devices", udErr);

    // 5. Unlock purchases
    const { error: upErr } = await supabase
      .from("unlock_purchases")
      .delete()
      .eq("user_id", userId);
    throwIfError("delete unlock_purchases", upErr);

    // 6. Public user profile
    const { error: uErr } = await supabase
      .from("users")
      .delete()
      .eq("id", userId);
    throwIfError("delete users", uErr);

    // 7. Delete the auth user (admin API)
    const { error: deleteAuthErr } = await supabase.auth.admin.deleteUser(userId);
    if (deleteAuthErr) {
      console.error("delete auth user:", deleteAuthErr);
      return json({ success: false, error: "Failed to delete auth user: " + deleteAuthErr.message }, 500);
    }

    return json({ success: true, message: "Account deleted permanently" });
  } catch (err) {
    console.error("delete-account error:", err);
    return json({ success: false, error: err.message || "Internal server error" }, 500);
  }
});
