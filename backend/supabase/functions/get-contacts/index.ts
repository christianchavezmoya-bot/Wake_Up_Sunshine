// @ts-nocheck — Deno runtime globals not available in local TS config
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { generateTraceId, logFunctionStart, logFunctionEnd, logDbQuery } from '../_shared/debugLogger.ts'

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
    // Anon client — only used for auth verification
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    // Service role — bypasses RLS for all cross-user data queries
    const admin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) {
      await logFunctionEnd(admin, traceId, 'get-contacts', false, null, 'Unauthorized')
      return new Response(JSON.stringify({
        success: false, error: 'Unauthorized', traceId,
        peopleICanWake: [], peopleWhoCanWakeMe: [],
        pendingInvitesSent: [], pendingInvitesReceived: [],
        blockedContacts: []
      }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    await logFunctionStart(admin, traceId, 'get-contacts', user.id, { email: user.email })
    const userEmailLower = (user.email || '').toLowerCase().trim()

    // ── 1. People I can wake (I am trustee, they are granters) ──────────
    const { data: trusteePerms } = await admin
      .from('wake_permissions')
      .select('granter_id')
      .eq('trustee_id', user.id)
      .eq('status', 'active')

    // ── 2. People who can wake me (I am granter, they are trustees) ─────
    const { data: granterPerms } = await admin
      .from('wake_permissions')
      .select('trustee_id')
      .eq('granter_id', user.id)
      .eq('status', 'active')

    // ── 2b. People I blocked from waking me (I am granter) ──────────────
    const { data: blockedPerms } = await admin
      .from('wake_permissions')
      .select('trustee_id')
      .eq('granter_id', user.id)
      .eq('status', 'blocked')

    // ── 3. Batch-fetch user profiles for all referenced IDs ─────────────
    const allUserIds = [
      ...new Set([
        ...(trusteePerms || []).map((p: any) => p.granter_id),
        ...(granterPerms || []).map((p: any) => p.trustee_id),
        ...(blockedPerms || []).map((p: any) => p.trustee_id),
      ])
    ]

    let profileMap: Record<string, { id: string; email: string; display_name: string }> = {}
    if (allUserIds.length > 0) {
      const { data: profiles } = await admin
        .from('users')
        .select('id, email, display_name')
        .in('id', allUserIds)
      for (const p of (profiles || [])) profileMap[p.id] = p
    }

    const peopleICanWake = (trusteePerms || []).map((p: any) => {
      const profile = profileMap[p.granter_id]
      return {
        id: p.granter_id,
        userId: p.granter_id,
        email: profile?.email || '',
        displayName: profile?.display_name || profile?.email || 'Unknown',
        status: 'active'
      }
    })

    const peopleWhoCanWakeMe = (granterPerms || []).map((p: any) => {
      const profile = profileMap[p.trustee_id]
      return {
        id: p.trustee_id,
        userId: p.trustee_id,
        email: profile?.email || '',
        displayName: profile?.display_name || profile?.email || 'Unknown',
        status: 'active'
      }
    })

    const blockedContacts = (blockedPerms || []).map((p: any) => {
      const profile = profileMap[p.trustee_id]
      return {
        id: p.trustee_id,
        userId: p.trustee_id,
        email: profile?.email || '',
        displayName: profile?.display_name || profile?.email || 'Unknown',
        status: 'blocked'
      }
    })

    // ── 4. Pending invites sent by me ────────────────────────────────────
    const { data: sentData } = await admin
      .from('contact_invites')
      .select('id, invitee_email, invitee_label, status, created_at, expires_at, invite_token')
      .eq('inviter_id', user.id)
      .eq('status', 'pending')

    const pendingInvitesSent = (sentData || []).map((i: any) => ({
      id: i.id,
      inviteToken: i.invite_token,
      inviteeEmail: i.invitee_email,
      inviteeLabel: i.invitee_label,
      inviterEmail: user.email || '',
      status: i.status,
      createdAt: i.created_at,
      expiresAt: i.expires_at,
    }))

    // ── 5. Pending invites received (matched by email) ───────────────────
    const { data: receivedRaw } = await admin
      .from('contact_invites')
      .select('id, inviter_id, invitee_email, invite_token, created_at, message')
      .ilike('invitee_email', userEmailLower)
      .eq('status', 'pending')

    // Batch-fetch inviter profiles
    let inviterMap: Record<string, { email: string; display_name: string }> = {}
    if (receivedRaw && receivedRaw.length > 0) {
      const inviterIds = [...new Set(receivedRaw.map((i: any) => i.inviter_id))]
      const { data: inviterProfiles } = await admin
        .from('users')
        .select('id, email, display_name')
        .in('id', inviterIds)
      for (const p of (inviterProfiles || [])) inviterMap[p.id] = p
    }

    const pendingInvitesReceived = (receivedRaw || []).map((i: any) => {
      const inviter = inviterMap[i.inviter_id]
      return {
        id: i.id,
        inviteToken: i.invite_token,
        inviterId: i.inviter_id,
        inviterEmail: inviter?.email || '',
        inviterName: inviter?.display_name || inviter?.email || 'Unknown',
        inviteeEmail: i.invitee_email || '',
        message: i.message,
        createdAt: i.created_at,
        status: 'pending'
      }
    })

    // Log query results
    await logDbQuery(admin, traceId, 'wake_permissions_trustee', trusteePerms?.length || 0)
    await logDbQuery(admin, traceId, 'wake_permissions_granter', granterPerms?.length || 0)
    await logDbQuery(admin, traceId, 'wake_permissions_blocked', blockedContacts.length)
    await logDbQuery(admin, traceId, 'contact_invites_sent', pendingInvitesSent.length)
    await logDbQuery(admin, traceId, 'contact_invites_received', pendingInvitesReceived.length)

    const result = {
      success: true,
      traceId,
      peopleICanWake,
      peopleWhoCanWakeMe,
      blockedContacts,
      pendingInvitesSent,
      pendingInvitesReceived,
      message: null,
      error: null
    }

    await logFunctionEnd(admin, traceId, 'get-contacts', true, {
      peopleICanWake: peopleICanWake.length,
      peopleWhoCanWakeMe: peopleWhoCanWakeMe.length,
      blockedContacts: blockedContacts.length,
      pendingSent: pendingInvitesSent.length,
      pendingReceived: pendingInvitesReceived.length
    })

    return new Response(JSON.stringify(result), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error('[get-contacts] Error:', error)
    return new Response(JSON.stringify({
      success: false, error: String(error), traceId,
      peopleICanWake: [], peopleWhoCanWakeMe: [],
      pendingInvitesSent: [], pendingInvitesReceived: [],
      blockedContacts: []
    }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
