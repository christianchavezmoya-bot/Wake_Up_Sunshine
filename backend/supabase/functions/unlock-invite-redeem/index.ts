import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface RedeemRequest {
  code: string
  device_id: string
  platform?: 'ios' | 'android'
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

    const body: RedeemRequest = await req.json()
    const { code, device_id, platform } = body

    console.log('[unlock-invite-redeem] Request:', { code, device_id, platform })

    if (!code || !device_id) {
      return new Response(JSON.stringify({ 
        success: false, 
        error: 'Missing required fields: code, device_id' 
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Redeem the invite code
    const { data: result, error: redeemError } = await supabaseAdmin
      .rpc('redeem_unlock_invite', {
        p_code: code.toUpperCase(),
        p_device_id: device_id,
        p_platform: platform || null
      })

    if (redeemError) {
      console.log('[unlock-invite-redeem] Redeem error:', redeemError)
      return new Response(JSON.stringify({ 
        success: false, 
        error: redeemError.message || 'Failed to redeem invite' 
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Parse the JSON result from the function
    const redeemResult = typeof result === 'string' ? JSON.parse(result) : result

    console.log('[unlock-invite-redeem] Result:', redeemResult)

    const statusCode = redeemResult.success ? 200 : 400

    return new Response(JSON.stringify(redeemResult), {
      status: statusCode,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('[unlock-invite-redeem] Unexpected error:', error)
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    return new Response(JSON.stringify({ success: false, error: errorMessage }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})