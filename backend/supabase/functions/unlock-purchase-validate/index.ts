import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface PurchaseRequest {
  device_id: string
  platform: 'ios' | 'android'
  receipt_token: string
  product_id?: string
  transaction_id?: string
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

    const body: PurchaseRequest = await req.json()
    const { device_id, platform, receipt_token, product_id, transaction_id } = body

    console.log('[unlock-purchase-validate] Request:', { device_id, platform, product_id })

    if (!device_id || !platform || !receipt_token) {
      return new Response(JSON.stringify({ 
        success: false, 
        error: 'Missing required fields: device_id, platform, receipt_token' 
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Validate platform
    if (!['ios', 'android'].includes(platform)) {
      return new Response(JSON.stringify({ 
        success: false, 
        error: 'Invalid platform. Must be ios or android' 
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // For iOS: Validate receipt with Apple
    // For Android: Validate purchase with Google Play
    // In production, you would call Apple/Google servers here
    // For now, we'll do basic validation and trust the receipt

    let isValid = false
    let validationResponse: any = {}

    if (platform === 'ios') {
      // Apple App Store receipt validation
      // In production: Call Apple's verifyReceipt endpoint
      // For development: Basic validation
      try {
        // Decode the receipt (base64) - in production, verify with Apple
        const receiptData = atob(receipt_token)
        console.log('[unlock-purchase-validate] iOS receipt decoded')
        
        // Basic validation - in production, verify with Apple's servers
        // Production would call: https://buy.itunes.apple.com/verifyReceipt (prod) 
        // or https://sandbox.itunes.apple.com/verifyReceipt (sandbox)
        isValid = receipt_token.length > 50 // Basic check
        validationResponse = { platform: 'ios', verified: isValid }
      } catch (e) {
        console.log('[unlock-purchase-validate] iOS receipt decode error:', e)
        // For testing, allow the purchase anyway
        isValid = true
        validationResponse = { platform: 'ios', verified: true, note: 'dev mode' }
      }
    } else if (platform === 'android') {
      // Google Play purchase validation
      // In production: Call Google Play Developer API
      // For development: Basic validation
      try {
        // The receipt_token is the purchaseToken from Google Play
        console.log('[unlock-purchase-validate] Android purchase token received')
        
        // In production, verify with Google Play Developer API
        // GET https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{packageName}/purchases/products/{productId}/tokens/{token}
        isValid = receipt_token.length > 20
        validationResponse = { platform: 'android', verified: isValid }
      } catch (e) {
        console.log('[unlock-purchase-validate] Android validation error:', e)
        isValid = true
        validationResponse = { platform: 'android', verified: true, note: 'dev mode' }
      }
    }

    if (!isValid) {
      return new Response(JSON.stringify({ 
        success: false, 
        error: 'Purchase validation failed' 
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Get or create unlock user
    const { data: user, error: userError } = await supabaseAdmin
      .rpc('get_or_create_unlock_user', { 
        p_device_id: device_id, 
        p_platform: platform 
      })

    if (userError) {
      console.log('[unlock-purchase-validate] User creation error:', userError)
      return new Response(JSON.stringify({ 
        success: false, 
        error: 'Failed to create user' 
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Validate purchase and grant credits
    const { data: result, error: purchaseError } = await supabaseAdmin
      .rpc('validate_purchase_and_grant_credits', {
        p_user_id: user,
        p_platform: platform,
        p_receipt_token: receipt_token,
        p_original_transaction_id: transaction_id || null,
        p_validation_response: validationResponse
      })

    if (purchaseError) {
      console.log('[unlock-purchase-validate] Purchase validation error:', purchaseError)
      return new Response(JSON.stringify({ 
        success: false, 
        error: 'Failed to validate purchase' 
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    console.log('[unlock-purchase-validate] Result:', result)

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('[unlock-purchase-validate] Unexpected error:', error)
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    return new Response(JSON.stringify({ success: false, error: errorMessage }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})