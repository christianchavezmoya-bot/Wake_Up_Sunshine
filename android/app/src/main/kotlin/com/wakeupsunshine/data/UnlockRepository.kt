package com.wakeupsunshine.data

import android.content.Context
import android.provider.Settings
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.MediaType.Companion.toMediaType
import org.json.JSONObject

/**
 * Repository for unlock/purchase functionality
 */
object UnlockRepository {
    private const val TAG = "UnlockRepository"
    
    private val client = OkHttpClient()
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()
    
    // Product ID for lifetime unlock
    const val PRODUCT_ID = "wake_unlock_lifetime"
    
    // MARK: - Device ID
    
    fun getDeviceId(context: Context): String {
        return Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ANDROID_ID
        ) ?: java.util.UUID.randomUUID().toString()
    }
    
    // MARK: - API URLs
    
    private val baseUrl: String
        get() = SupabaseClient.SUPABASE_URL
    
    private val validatePurchaseUrl: String
        get() = "$baseUrl/functions/v1/unlock-purchase-validate"
    
    private val createInviteUrl: String
        get() = "$baseUrl/functions/v1/unlock-invite-create"
    
    private val validateInviteUrl: String
        get() = "$baseUrl/functions/v1/unlock-invite-validate"
    
    private val redeemInviteUrl: String
        get() = "$baseUrl/functions/v1/unlock-invite-redeem"
    
    private val getStatusUrl: String
        get() = "$baseUrl/functions/v1/unlock-get-status"
    
    // MARK: - Response Models
    
    data class UnlockStatus(
        val exists: Boolean,
        val hasPaid: Boolean,
        val isInvited: Boolean,
        val inviteCredits: Int,
        val userId: String?,
        val platform: String?
    )
    
    data class ValidatePurchaseResponse(
        val success: Boolean,
        val error: String?,
        val inviteCredits: Int?,
        val hasPaid: Boolean?
    )
    
    data class UnlockInvite(
        val success: Boolean,
        val code: String?,
        val inviteId: String?,
        val inviteLink: String?,
        val deepLink: String?,
        val remainingCredits: Int?,
        val error: String?
    )
    
    data class RedeemResult(
        val success: Boolean,
        val message: String?,
        val error: String?,
        val status: String?,
        val userId: String?
    )
    
    data class ValidateInviteResponse(
        val valid: Boolean,
        val error: String?,
        val status: String?
    )
    
    // MARK: - API Calls
    
    suspend fun getUnlockStatus(deviceId: String): Result<UnlockStatus> = withContext(Dispatchers.IO) {
        try {
            val request = Request.Builder()
                .url("$getStatusUrl?device_id=$deviceId")
                .get()
                .addHeader("apikey", SupabaseClient.SUPABASE_ANON_KEY)
                .addHeader("Authorization", "Bearer ${SupabaseClient.SUPABASE_ANON_KEY}")
                .addHeader("Content-Type", "application/json")
                .build()
            
            val response = client.newCall(request).execute()
            
            if (response.isSuccessful) {
                val responseBody = response.body?.string()
                DebugLogger.debug(TAG, "getUnlockStatus response: $responseBody")
                
                val json = JSONObject(responseBody ?: "{}")
                val statusJson = json.optJSONObject("data") ?: json
                
                val status = UnlockStatus(
                    exists = statusJson.optBoolean("exists", false),
                    hasPaid = statusJson.optBoolean("has_paid", false),
                    isInvited = statusJson.optBoolean("is_invited", false),
                    inviteCredits = statusJson.optInt("invite_credits", 0),
                    userId = statusJson.optString("user_id", null),
                    platform = statusJson.optString("platform", null)
                )
                
                Result.success(status)
            } else {
                val errorBody = response.body?.string() ?: "Unknown error"
                Log.e(TAG, "getUnlockStatus failed: $errorBody")
                Result.failure(Exception("Failed to get status: $errorBody"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "getUnlockStatus exception", e)
            Result.failure(e)
        }
    }
    
    suspend fun validatePurchase(
        deviceId: String,
        purchaseToken: String,
        transactionId: String? = null
    ): Result<ValidatePurchaseResponse> = withContext(Dispatchers.IO) {
        try {
            val requestBody = JSONObject()
                .put("device_id", deviceId)
                .put("platform", "android")
                .put("receipt_token", purchaseToken)
                .put("product_id", PRODUCT_ID)
                .put("transaction_id", transactionId)
                .toString()
            
            val request = Request.Builder()
                .url(validatePurchaseUrl)
                .post(requestBody.toRequestBody(jsonMediaType))
                .addHeader("apikey", SupabaseClient.SUPABASE_ANON_KEY)
                .addHeader("Authorization", "Bearer ${SupabaseClient.SUPABASE_ANON_KEY}")
                .addHeader("Content-Type", "application/json")
                .build()
            
            DebugLogger.debug(TAG, "validatePurchase request: $requestBody")
            
            val response = client.newCall(request).execute()
            val responseBody = response.body?.string()
            
            DebugLogger.debug(TAG, "validatePurchase response: $responseBody")
            
            if (response.isSuccessful) {
                val json = JSONObject(responseBody ?: "{}")
                
                val result = ValidatePurchaseResponse(
                    success = json.optBoolean("success", false),
                    error = json.optString("error", null),
                    inviteCredits = json.optInt("invite_credits", 0),
                    hasPaid = json.optBoolean("has_paid", false)
                )
                
                Result.success(result)
            } else {
                Result.failure(Exception("Purchase validation failed: $responseBody"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "validatePurchase exception", e)
            Result.failure(e)
        }
    }
    
    suspend fun createInvite(deviceId: String): Result<UnlockInvite> = withContext(Dispatchers.IO) {
        try {
            val requestBody = JSONObject()
                .put("device_id", deviceId)
                .toString()
            
            val request = Request.Builder()
                .url(createInviteUrl)
                .post(requestBody.toRequestBody(jsonMediaType))
                .addHeader("apikey", SupabaseClient.SUPABASE_ANON_KEY)
                .addHeader("Authorization", "Bearer ${SupabaseClient.SUPABASE_ANON_KEY}")
                .addHeader("Content-Type", "application/json")
                .build()
            
            val response = client.newCall(request).execute()
            val responseBody = response.body?.string()
            
            DebugLogger.debug(TAG, "createInvite response: $responseBody")
            
            if (response.isSuccessful) {
                val json = JSONObject(responseBody ?: "{}")
                
                val invite = UnlockInvite(
                    success = json.optBoolean("success", false),
                    code = json.optString("code", null),
                    inviteId = json.optString("invite_id", null),
                    inviteLink = json.optString("invite_link", null),
                    deepLink = json.optString("deep_link", null),
                    remainingCredits = json.optInt("remaining_credits", 0),
                    error = json.optString("error", null)
                )
                
                Result.success(invite)
            } else {
                Result.failure(Exception("Failed to create invite: $responseBody"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "createInvite exception", e)
            Result.failure(e)
        }
    }
    
    suspend fun validateInviteCode(code: String): Result<ValidateInviteResponse> = withContext(Dispatchers.IO) {
        try {
            val request = Request.Builder()
                .url("$validateInviteUrl?code=${code.uppercase()}")
                .get()
                .addHeader("apikey", SupabaseClient.SUPABASE_ANON_KEY)
                .addHeader("Authorization", "Bearer ${SupabaseClient.SUPABASE_ANON_KEY}")
                .addHeader("Content-Type", "application/json")
                .build()
            
            val response = client.newCall(request).execute()
            val responseBody = response.body?.string()
            
            DebugLogger.debug(TAG, "validateInviteCode response: $responseBody")
            
            if (response.isSuccessful) {
                val json = JSONObject(responseBody ?: "{}")
                
                val result = ValidateInviteResponse(
                    valid = json.optBoolean("valid", false),
                    error = json.optString("error", null),
                    status = json.optString("status", null)
                )
                
                Result.success(result)
            } else {
                Result.failure(Exception("Failed to validate invite: $responseBody"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "validateInviteCode exception", e)
            Result.failure(e)
        }
    }
    
    suspend fun redeemInvite(
        code: String,
        deviceId: String
    ): Result<RedeemResult> = withContext(Dispatchers.IO) {
        try {
            val requestBody = JSONObject()
                .put("code", code.uppercase())
                .put("device_id", deviceId)
                .put("platform", "android")
                .toString()
            
            val request = Request.Builder()
                .url(redeemInviteUrl)
                .post(requestBody.toRequestBody(jsonMediaType))
                .addHeader("apikey", SupabaseClient.SUPABASE_ANON_KEY)
                .addHeader("Authorization", "Bearer ${SupabaseClient.SUPABASE_ANON_KEY}")
                .addHeader("Content-Type", "application/json")
                .build()
            
            DebugLogger.debug(TAG, "redeemInvite request: $requestBody")
            
            val response = client.newCall(request).execute()
            val responseBody = response.body?.string()
            
            DebugLogger.debug(TAG, "redeemInvite response: $responseBody")
            
            if (response.isSuccessful) {
                val json = JSONObject(responseBody ?: "{}")
                
                val result = RedeemResult(
                    success = json.optBoolean("success", false),
                    message = json.optString("message", null),
                    error = json.optString("error", null),
                    status = json.optString("status", null),
                    userId = json.optString("user_id", null)
                )
                
                Result.success(result)
            } else {
                Result.failure(Exception("Failed to redeem invite: $responseBody"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "redeemInvite exception", e)
            Result.failure(e)
        }
    }
}
