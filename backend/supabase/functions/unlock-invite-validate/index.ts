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

    // Get code from URL path or query parameter
    const url = new URL(req.url)
    const code = url.searchParams.get('code') || url.pathname.split('/').pop()

    console.log('[unlock-invite-validate] Request:', { code })

    if (!code) {
      return new Response(JSON.stringify({ 
        valid: false, 
        error: 'Missing invite code' 
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Validate the invite code
    const { data: result, error: validateError } = await supabaseAdmin
      .rpc('validate_unlock_invite', {
        p_code: code.toUpperCase()
      })

    if (validateError) {
      console.log('[unlock-invite-validate] Validation error:', validateError)
      return new Response(JSON.stringify({ 
        valid: false, 
        error: validateError.message || 'Failed to validate invite' 
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Parse the JSON result from the function
    const validationResult = typeof result === 'string' ? JSON.parse(result) : result

    console.log('[unlock-invite-validate] Result:', validationResult)

    return new Response(JSON.stringify(validationResult), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('[unlock-invite-validate] Unexpected error:', error)
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    return new Response(JSON.stringify({ valid: false, error: errorMessage }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})