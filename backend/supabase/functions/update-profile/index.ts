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
    const body   = await req.json().catch(() => ({}));

    const updates: Record<string, unknown> = { updated_at: new Date().toISOString() };

    if (typeof body.displayName === "string") updates.display_name = body.displayName.trim().slice(0, 100);
    if (typeof body.phoneNumber === "string") updates.phone_number = body.phoneNumber.trim().slice(0, 30);
    if (typeof body.avatarColor === "string") updates.avatar_color = body.avatarColor;

    if (Object.keys(updates).length === 1) {
      return json({ success: false, error: "No updatable fields provided" }, 400);
    }

    const { data: profile, error: updateErr } = await supabase
      .from("users")
      .update(updates)
      .eq("id", userId)
      .select("id, display_name, email, phone_number, avatar_color, updated_at")
      .single();

    if (updateErr) {
      console.error("[update-profile] DB error:", updateErr);
      return json({ success: false, error: "Failed to update profile" }, 500);
    }

    // Also sync display_name to auth.users user_metadata
    if (updates.display_name) {
      await supabase.auth.admin.updateUserById(userId, {
        user_metadata: { display_name: updates.display_name },
      });
    }

    return json({
      success: true,
      profile: {
        id:          profile.id,
        email:       profile.email,
        displayName: profile.display_name,
        phoneNumber: profile.phone_number || "",
        avatarColor: profile.avatar_color || "#FF6B35",
        updatedAt:   profile.updated_at,
      },
    });
  } catch (err) {
    console.error("[update-profile]", err);
    return json({ success: false, error: "Internal server error" }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
