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
    const email  = auth.user.email || "";
    const preferredDisplayName =
      typeof auth.user.user_metadata?.display_name === "string" &&
      auth.user.user_metadata.display_name.trim().length > 0
        ? auth.user.user_metadata.display_name.trim()
        : email.split("@")[0];

    // Fetch or upsert public.users row
    let { data: profile, error: profileErr } = await supabase
      .from("users")
      .select("id, display_name, email, phone_number, avatar_color, created_at, updated_at")
      .eq("id", userId)
      .single();

    if (profileErr || !profile) {
      // Auto-create profile row if missing (can happen for existing auth users)
      const { data: created } = await supabase
        .from("users")
        .upsert({
          id: userId,
          email,
          display_name: preferredDisplayName,
          avatar_color: "#FF6B35",
        }, { onConflict: "id" })
        .select()
        .single();
      profile = created;
    } else {
      const storedDisplayName = (profile.display_name || "").trim();
      const canBackfillDisplayName =
        !!preferredDisplayName &&
        (
          !storedDisplayName ||
          storedDisplayName === "User" ||
          storedDisplayName === email ||
          storedDisplayName === email.split("@")[0]
        ) &&
        storedDisplayName !== preferredDisplayName;

      if (canBackfillDisplayName) {
        const { data: updated } = await supabase
          .from("users")
          .update({ display_name: preferredDisplayName, updated_at: new Date().toISOString() })
          .eq("id", userId)
          .select("id, display_name, email, phone_number, avatar_color, created_at, updated_at")
          .single();

        if (updated) {
          profile = updated;
        }
      }
    }

    return json({
      success: true,
      profile: {
        id:           profile?.id || userId,
        email:        profile?.email || email,
        displayName:  profile?.display_name || "",
        phoneNumber:  profile?.phone_number || "",
        avatarColor:  profile?.avatar_color || "#FF6B35",
        createdAt:    profile?.created_at,
        updatedAt:    profile?.updated_at,
      },
    });
  } catch (err) {
    console.error("[get-profile]", err);
    return json({ success: false, error: "Internal server error" }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
