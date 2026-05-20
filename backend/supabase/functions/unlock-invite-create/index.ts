import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CreateInviteRequest {
  device_id: string
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

    const body: CreateInviteRequest = await req.json()
    const { device_id } = body

    console.log('[unlock-invite-create] Request:', { device_id })

    if (!device_id) {
      return new Response(JSON.stringify({ 
        success: false, 
        error: 'Missing required field: device_id' 
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Get user by device_id
    const { data: user, error: userError } = await supabaseAdmin
      .from('unlock_users')
      .select('*')
      .eq('device_id', device_id)
      .single()

    if (userError || !user) {
      return new Response(JSON.stringify({ 
        success: false, 
        error: 'User not found. Please make a purchase first.' 
      }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Create unlock invite using the database function
    const { data: result, error: inviteError } = await supabaseAdmin
      .rpc('create_unlock_invite', {
        p_user_id: user.id
      })

    if (inviteError) {
      console.log('[unlock-invite-create] Invite creation error:', inviteError)
      return new Response(JSON.stringify({ 
        success: false, 
        error: inviteError.message || 'Failed to create invite' 
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Parse the JSON result from the function
    const inviteResult = typeof result === 'string' ? JSON.parse(result) : result

    if (!inviteResult.success) {
      return new Response(JSON.stringify(inviteResult), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    console.log('[unlock-invite-create] Invite created:', inviteResult.code)

    return new Response(JSON.stringify(inviteResult), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('[unlock-invite-create] Unexpected error:', error)
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    return new Response(JSON.stringify({ success: false, error: errorMessage }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})