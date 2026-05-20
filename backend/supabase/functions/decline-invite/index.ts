// @ts-nocheck — Deno runtime globals not available in local TS config
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

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
      return new Response(JSON.stringify({ success: false, error: 'Unauthorized' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const body = await req.json()
    const inviteId: string | undefined = body.inviteId
    const inviteToken: string | undefined = body.inviteToken

    if (!inviteId && !inviteToken) {
      return new Response(JSON.stringify({ success: false, error: 'inviteId or inviteToken is required' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Fetch the invite via service role
    let query = admin.from('contact_invites')
      .select('id, inviter_id, invitee_email, status, expires_at')
      .eq('status', 'pending')

    if (inviteId) {
      query = query.eq('id', inviteId)
    } else {
      query = query.eq('invite_token', inviteToken!)
    }

    const { data: invite, error: fetchError } = await query.single()

    if (fetchError || !invite) {
      console.log('[decline-invite] Not found | inviteId:', inviteId, '| error:', fetchError?.message)
      return new Response(JSON.stringify({ success: false, error: 'Invite not found or already processed' }), {
        status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Verify email ownership
    const userEmailLower = (user.email || '').toLowerCase().trim()
    const inviteeEmailLower = (invite.invitee_email || '').toLowerCase().trim()
    const isPlaceholder = inviteeEmailLower.endsWith('@share.link') || inviteeEmailLower.endsWith('@qr.code')

    if (!isPlaceholder && userEmailLower !== inviteeEmailLower) {
      console.log('[decline-invite] Email mismatch | user:', userEmailLower, '| invite:', inviteeEmailLower)
      return new Response(JSON.stringify({
        success: false,
        error: 'This invite was sent to a different email address'
      }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // Call decline_invite RPC (SECURITY DEFINER)
    const { data, error: rpcError } = await supabaseClient.rpc('decline_invite', {
      p_invite_id: invite.id,
      p_invite_token: null,
      p_user_id: user.id
    })

    if (rpcError) {
      console.error('[decline-invite] RPC error:', rpcError.message)
      return new Response(JSON.stringify({ success: false, error: rpcError.message }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    console.log('[decline-invite] Declined | user:', user.id, '| invite:', invite.id)
    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('[decline-invite] Error:', error)
    return new Response(JSON.stringify({ success: false, error: String(error) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
