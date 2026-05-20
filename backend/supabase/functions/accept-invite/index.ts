// @ts-nocheck — Deno runtime globals not available in local TS config
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { generateTraceId, logFunctionStart, logFunctionEnd } from '../_shared/debugLogger.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const traceId = generateTraceId()

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const admin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) {
      await logFunctionEnd(admin, traceId, 'accept-invite', false, null, 'Unauthorized')
      return new Response(JSON.stringify({ success: false, error: 'Unauthorized', traceId }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    await logFunctionStart(admin, traceId, 'accept-invite', user.id, { email: user.email })

    const body = await req.json()
    const inviteId: string | undefined = body.inviteId
    const inviteToken: string | undefined = body.inviteToken

    if (!inviteId && !inviteToken) {
      return new Response(JSON.stringify({ success: false, error: 'inviteId or inviteToken is required' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Fetch the invite via service role (bypasses RLS)
    let query = admin.from('contact_invites')
      .select('id, inviter_id, invitee_email, status, expires_at, invite_token')
      .eq('status', 'pending')

    if (inviteId) {
      query = query.eq('id', inviteId)
    } else {
      query = query.eq('invite_token', inviteToken!)
    }

    const { data: invite, error: fetchError } = await query.single()

    if (fetchError || !invite) {
      console.log('[accept-invite] Not found | inviteId:', inviteId, '| token prefix:', inviteToken?.slice(0, 8), '| error:', fetchError?.message)
      return new Response(JSON.stringify({
        success: false,
        error: 'Invite not found or not available for this account',
        debugCode: 'INVITE_NOT_FOUND_FOR_USER'
      }), { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // Verify not expired
    if (invite.expires_at && new Date(invite.expires_at) < new Date()) {
      return new Response(JSON.stringify({ success: false, error: 'Invite has expired', debugCode: 'INVITE_EXPIRED' }), {
        status: 410, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Verify email ownership (allow placeholder invites from share-link / QR flow)
    const userEmailLower = (user.email || '').toLowerCase().trim()
    const inviteeEmailLower = (invite.invitee_email || '').toLowerCase().trim()
    const isPlaceholder = inviteeEmailLower.endsWith('@share.link') || inviteeEmailLower.endsWith('@qr.code')

    if (!isPlaceholder && userEmailLower !== inviteeEmailLower) {
      console.log('[accept-invite] Email mismatch | user:', userEmailLower, '| invite:', inviteeEmailLower)
      return new Response(JSON.stringify({
        success: false,
        error: 'This invite was sent to a different email address',
        debugCode: 'EMAIL_MISMATCH'
      }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // Call accept_invite RPC (SECURITY DEFINER — handles DB writes atomically)
    const { data, error: rpcError } = await supabaseClient.rpc('accept_invite', {
      p_invite_id: invite.id,
      p_invite_token: null,
      p_user_id: user.id
    })

    if (rpcError) {
      console.error('[accept-invite] RPC error:', rpcError.message)
      return new Response(JSON.stringify({ success: false, error: rpcError.message }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    console.log('[accept-invite] Accepted | user:', user.id, '| invite:', invite.id)
    await logFunctionEnd(admin, traceId, 'accept-invite', true, { inviteId: invite.id, inviterId: invite.inviter_id })
    
    return new Response(JSON.stringify({ ...data, traceId }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('[accept-invite] Error:', error)
    return new Response(JSON.stringify({ success: false, error: String(error), traceId }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
