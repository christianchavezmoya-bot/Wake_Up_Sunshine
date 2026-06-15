import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { generateTraceId, logFunctionStart, logFunctionEnd } from '../_shared/debugLogger.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const traceId = generateTraceId()

  try {
    // Use service role to bypass RLS
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    // Also create client with user's token for auth verification
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) {
      console.log('[create-invite] Unauthorized - no user found')
      await logFunctionEnd(supabaseAdmin, traceId, 'create-invite', false, null, 'Unauthorized')
      return new Response(JSON.stringify({ success: false, error: 'Unauthorized', traceId }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    await logFunctionStart(supabaseAdmin, traceId, 'create-invite', user.id, { email: user.email })
    console.log('[create-invite] Authenticated user:', user.id)

    const { inviteeEmail, message, inviteeLabel } = await req.json()
    const normalizedLabel = typeof inviteeLabel === 'string' ? inviteeLabel.trim() : ''
    console.log('[create-invite] Request body:', { inviteeEmail, message, inviteeLabel: normalizedLabel || null })
    
    if (!inviteeEmail) {
      console.log('[create-invite] Missing email')
      return new Response(JSON.stringify({ success: false, error: 'Email is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Ensure user exists in public.users table
    const { data: existingUser, error: userCheckError } = await supabaseAdmin
      .from('users')
      .select('id')
      .eq('id', user.id)
      .single()

    if (!existingUser) {
      console.log('[create-invite] User not in public.users, creating...')
      const { error: createUserError } = await supabaseAdmin
        .from('users')
        .insert({
          id: user.id,
          email: user.email,
          display_name: user.user_metadata?.display_name || user.email?.split('@')[0] || 'User',
          avatar_color: '#FF6B35'
        })
      if (createUserError) {
        console.log('[create-invite] Failed to create user:', createUserError.message)
      }
    }

    // Generate invite token
    const inviteToken = crypto.randomUUID().replace(/-/g, '') + crypto.randomUUID().replace(/-/g, '')

    // Create invite using admin client to bypass RLS
    const { data: invite, error } = await supabaseAdmin
      .from('contact_invites')
      .insert({
        inviter_id: user.id,
        invitee_email: inviteeEmail.toLowerCase(),
        invite_token: inviteToken,
        invitee_label: normalizedLabel || null,
        message: message || null,
        status: 'pending'
      })
      .select()
      .single()

    if (error) {
      console.log('[create-invite] Database error:', error.message)
      return new Response(JSON.stringify({ success: false, error: error.message }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    console.log('[create-invite] Invite created successfully:', invite.id)

    // Generate invite links
    const inviteLink = `wakeupsunshine://invite/${inviteToken}`
    const httpsLink = `https://wakeupsunshine.app/invite/${inviteToken}`

    const response = {
      success: true,
      traceId,
      inviteId: invite.id,
      inviteeEmail: inviteeEmail.toLowerCase(),
      inviteeLabel: normalizedLabel || null,
      status: 'pending',
      message: 'Invite sent successfully',
      inviteToken: inviteToken,
      inviteLink: inviteLink,
      httpsLink: httpsLink,
      qrPayload: inviteLink
    }
    console.log('[create-invite] Response:', JSON.stringify(response))

    await logFunctionEnd(supabaseAdmin, traceId, 'create-invite', true, { inviteId: invite.id, inviteeEmail })

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('[create-invite] Unexpected error:', error)
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    return new Response(JSON.stringify({ success: false, error: errorMessage, traceId }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
