package com.wakeupsunshine.data

import io.supabase.SupabaseClient
import io.supabase.createSupabaseClient

object SupabaseClient {
    private const val SUPABASE_URL = "https://jehouatjcfcxjjuowzbd.supabase.co"
    private const val SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

    val client: SupabaseClient = createSupabaseClient(
        supabaseUrl = SUPABASE_URL,
        supabaseKey = SUPABASE_ANON_KEY
    )
}