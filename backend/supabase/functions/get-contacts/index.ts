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

    const userId = user.user.id;

    // Parse query params
    const url = new URL(req.url);
    const search = url.searchParams.get("search") || "";
    const page = parseInt(url.searchParams.get("page") || "1");
    const limit = parseInt(url.searchParams.get("limit") || "20");
    const offset = (page - 1) * limit;

    // Get trusted contacts (people who can wake me)
    let query = supabase
      .from("wake_permissions")
      .select(`
        id,
        trustee_id,
        status,
        created_at,
        user:users!trustee_id (
          id,
          display_name,
          avatar_color
        )
      `)
      .eq("granter_id", userId)
      .eq("status", "active")
      .order("created_at", { ascending: false })
      .range(offset, offset + limit - 1);

    // Search filter
    if (search) {
      query = query.ilike("user.display_name", `%${search}%`);
    }

    const { data: permissions, error: permissionsError } = await query;

    if (permissionsError) {
      return new Response(JSON.stringify({ error: "Failed to fetch contacts" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Transform to contacts format
    const contacts = (permissions || []).map((p: any) => ({
      id: p.id,
      userId: p.trustee_id,
      displayName: p.user?.display_name || "Unknown",
      avatarColor: p.user?.avatar_color || "#FF6B35",
      permissionStatus: p.status,
      isOnline: false, // Would need a presence system
    }));

    return new Response(
      JSON.stringify({
        success: true,
        contacts,
        page,
        limit,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Error fetching contacts:", error);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});