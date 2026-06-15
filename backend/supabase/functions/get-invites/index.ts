import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const url = new URL(req.url)
    const type = url.searchParams.get('type') || 'all' // 'sent', 'received', or 'all'

    let sentInvites = []
    let receivedInvites = []

    if (type === 'sent' || type === 'all') {
      const { data, error } = await supabaseClient.rpc('get_my_sent_invites')
      if (!error) sentInvites = data
    }

    if (type === 'received' || type === 'all') {
      const { data, error } = await supabaseClient.rpc('get_my_received_invites')
      if (!error) receivedInvites = data
    }

    return new Response(JSON.stringify({
      success: true,
      sent: sentInvites,
      received: receivedInvites
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})