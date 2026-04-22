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
    const page = parseInt(url.searchParams.get("page") || "1");
    const limit = parseInt(url.searchParams.get("limit") || "50");
    const offset = (page - 1) * limit;

    // Get wake history (both sent and received)
    const { data: sentRequests, error: sentError } = await supabase
      .from("wake_requests")
      .select(`
        id,
        sender_id,
        receiver_id,
        message,
        urgency,
        status,
        sent_at,
        delivered_at,
        confirmed_at,
        dismissed_at,
        receiver:users!receiver_id (
          id,
          display_name,
          avatar_color
        )
      `)
      .eq("sender_id", userId)
      .order("sent_at", { ascending: false })
      .range(offset, offset + limit - 1);

    if (sentError) {
      return new Response(JSON.stringify({ error: "Failed to fetch history" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Transform to history format
    const history = (sentRequests || []).map((r: any) => ({
      id: r.id,
      name: r.receiver?.display_name || "Unknown",
      avatarColor: r.receiver?.avatar_color || "#FF6B35",
      title: `Woke ${r.receiver?.display_name || "Unknown"}`,
      message: r.message,
      timestamp: r.sent_at,
      status: r.status,
      isIncoming: false,
    }));

    return new Response(
      JSON.stringify({
        success: true,
        history,
        page,
        limit,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Error fetching history:", error);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});