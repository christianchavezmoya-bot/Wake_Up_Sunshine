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
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    // Get device_id from URL query parameter or request body
    const url = new URL(req.url)
    let device_id = url.searchParams.get('device_id')

    if (!device_id && req.method === 'POST') {
      const body = await req.json()
      device_id = body.device_id
    }

    console.log('[unlock-get-status] Request:', { device_id })

    if (!device_id) {
      return new Response(JSON.stringify({ 
        success: false, 
        error: 'Missing required field: device_id' 
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Get unlock status
    const { data: result, error: statusError } = await supabaseAdmin
      .rpc('get_unlock_status', {
        p_device_id: device_id
      })

    if (statusError) {
      console.log('[unlock-get-status] Status error:', statusError)
      return new Response(JSON.stringify({ 
        success: false, 
        error: statusError.message || 'Failed to get status' 
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Parse the JSON result from the function
    const statusResult = typeof result === 'string' ? JSON.parse(result) : result

    console.log('[unlock-get-status] Result:', statusResult)

    return new Response(JSON.stringify({
      success: true,
      ...statusResult
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('[unlock-get-status] Unexpected error:', error)
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    return new Response(JSON.stringify({ success: false, error: errorMessage }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})