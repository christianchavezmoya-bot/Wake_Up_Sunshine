package com.wakeupsunshine.data

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.MediaType.Companion.toMediaType
import org.json.JSONObject

/**
 * Supabase Client for Wake Up Sunshine
 * Using HTTP client directly for auth operations
 */
object SupabaseClient {
    private const val TAG = "SupabaseClient"
    private const val PREFS_NAME = "supabase_session"

    // Supabase credentials - public for use by repositories
    const val SUPABASE_URL = "https://jehouatjcfcxjjuowzbd.supabase.co"
    const val SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImplaG91YXRqY2ZjeGpqdW93emJkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY4Mjk4MzEsImV4cCI6MjA5MjQwNTgzMX0.5nHtSx44b8U99WjaZUsRIIcUn4mHHdUMPFrM2Us3WjE"

    private val client = OkHttpClient()
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    // Current session
    private var currentSession: Session? = null

    data class Session(
        val accessToken: String,
        val refreshToken: String,
        val userId: String,
        val email: String?,
        val expiresAt: Long = 0L  // Unix timestamp seconds; 0 = unknown
    )

    // Returns the in-memory session; call restoreSession(context) first if the process may have restarted
    val session: Session?
        get() = currentSession

    fun persistSession(context: Context) {
        val s = currentSession ?: return
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            .putString("access_token", s.accessToken)
            .putString("refresh_token", s.refreshToken)
            .putString("user_id", s.userId)
            .putString("email", s.email)
            .putLong("expires_at", s.expiresAt)
            .apply()
    }

    fun restoreSession(context: Context) {
        if (currentSession != null) return
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val accessToken = prefs.getString("access_token", null) ?: return
        val refreshToken = prefs.getString("refresh_token", null) ?: return
        val userId = prefs.getString("user_id", null) ?: return
        val email = prefs.getString("email", null)
        val expiresAt = prefs.getLong("expires_at", 0L)
        currentSession = Session(accessToken, refreshToken, userId, email, expiresAt)
        DebugLogger.debug(TAG, "restoreSession: restored session for userId=$userId expiresAt=$expiresAt")
    }

    fun isSessionExpired(): Boolean {
        val s = currentSession ?: return true
        if (s.expiresAt == 0L) return true   // expiry unknown — force refresh
        // Treat as expired 5 minutes early to avoid races
        return System.currentTimeMillis() / 1000 >= s.expiresAt - 300
    }

    suspend fun refreshSession(): Result<Session> = withContext(Dispatchers.IO) {
        val s = currentSession ?: return@withContext Result.failure(Exception("No session to refresh"))
        try {
            val requestBody = JSONObject()
                .put("refresh_token", s.refreshToken)
                .toString()
            val request = Request.Builder()
                .url("$SUPABASE_URL/auth/v1/token?grant_type=refresh_token")
                .addHeader("apikey", SUPABASE_ANON_KEY)
                .addHeader("Content-Type", "application/json")
                .post(requestBody.toRequestBody(jsonMediaType))
                .build()
            val response = client.newCall(request).execute()
            if (response.isSuccessful) {
                val json = JSONObject(response.body?.string() ?: "{}")
                val newSession = Session(
                    accessToken = json.getString("access_token"),
                    refreshToken = json.optString("refresh_token", s.refreshToken),
                    userId = json.getJSONObject("user").getString("id"),
                    email = json.getJSONObject("user").optString("email"),
                    expiresAt = json.optLong("expires_at", 0L)
                )
                currentSession = newSession
                persistCurrentSession()
                DebugLogger.debug(TAG, "refreshSession: success expiresAt=${newSession.expiresAt}")
                Result.success(newSession)
            } else {
                val errorBody = response.body?.string() ?: ""
                Log.e(TAG, "refreshSession: failed $errorBody")
                Result.failure(Exception("Token refresh failed: $errorBody"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "refreshSession: exception", e)
            Result.failure(e)
        }
    }

    // Returns a valid session, refreshing transparently if the token is near expiry.
    // Returns null if there is no session or if refresh fails (caller should sign out).
    suspend fun getValidSession(): Session? {
        if (!isAuthenticated()) return null
        return if (isSessionExpired()) {
            DebugLogger.debug(TAG, "getValidSession: token expired — refreshing")
            refreshSession().getOrNull()
        } else {
            currentSession
        }
    }

    // Set this once from Application.onCreate() so session auto-persists on login
    var appContext: Context? = null

    fun clearPersistedSession(context: Context) {
        currentSession = null
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit().clear().apply()
    }

    fun currentDeviceName(): String {
        val manufacturer = android.os.Build.MANUFACTURER?.trim().orEmpty()
        val model = android.os.Build.MODEL?.trim().orEmpty()
        val combined = listOf(manufacturer, model)
            .filter { it.isNotBlank() }
            .joinToString(" ")
            .replace(Regex("\\s+"), " ")
            .trim()
        return if (combined.isNotBlank()) combined else "Android Device"
    }

    private fun persistCurrentSession() {
        val ctx = appContext ?: return
        persistSession(ctx)
    }
    
    suspend fun signUpWithEmail(email: String, password: String, displayName: String): Result<Session> = withContext(Dispatchers.IO) {
        try {
            DebugLogger.debug(TAG, "signUpWithEmail: Starting signup for $email")
            
            val requestBody = JSONObject()
                .put("email", email)
                .put("password", password)
                .put("data", JSONObject().put("display_name", displayName.trim()))
                .toString()
            
            val request = Request.Builder()
                .url("$SUPABASE_URL/auth/v1/signup")
                .addHeader("apikey", SUPABASE_ANON_KEY)
                .addHeader("Content-Type", "application/json")
                .post(requestBody.toRequestBody(jsonMediaType))
                .build()
            
            DebugLogger.debug(TAG, "signUpWithEmail: Sending request to ${request.url}")
            val response = client.newCall(request).execute()
            DebugLogger.debug(TAG, "signUpWithEmail: Response code ${response.code}")
            
            if (response.isSuccessful) {
                val responseBody = response.body?.string()
                DebugLogger.debug(TAG, "signUpWithEmail: Response body: $responseBody")
                
                if (responseBody.isNullOrBlank()) {
                    Log.e(TAG, "signUpWithEmail: Empty response body")
                    return@withContext Result.failure(Exception("Empty response from server"))
                }
                
                val json = JSONObject(responseBody)
                val sessionJson = json.optJSONObject("session")

                if (sessionJson != null) {
                    // Safely extract session data
                    val accessToken = sessionJson.optString("access_token")
                    val refreshToken = sessionJson.optString("refresh_token")
                    val expiresAt = sessionJson.optLong("expires_at", 0L)
                    val userId = json.optString("id")
                    val userEmail = json.optString("email")

                    if (accessToken.isBlank() || userId.isBlank()) {
                        Log.e(TAG, "signUpWithEmail: Missing required session data")
                        return@withContext Result.failure(Exception("Invalid session data received"))
                    }

                    val session = Session(
                        accessToken = accessToken,
                        refreshToken = refreshToken,
                        userId = userId,
                        email = userEmail,
                        expiresAt = expiresAt
                    )
                    currentSession = session
                    persistCurrentSession()
                    DebugLogger.debug(TAG, "signUpWithEmail: Success for user $userId")
                    Result.success(session)
                } else {
                    // Email confirmation may be required
                    DebugLogger.debug(TAG, "signUpWithEmail: No session - email verification may be required")
                    Result.failure(Exception("Signup successful, please check email for verification"))
                }
            } else {
                val errorBody = response.body?.string() ?: "Unknown error"
                Log.e(TAG, "signUpWithEmail: Failed with error: $errorBody")
                Result.failure(Exception("Signup failed: $errorBody"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "signUpWithEmail: Exception", e)
            Result.failure(e)
        }
    }
    
    suspend fun signInWithEmail(email: String, password: String): Result<Session> = withContext(Dispatchers.IO) {
        try {
            DebugLogger.debug(TAG, "signInWithEmail: Starting signin for $email")
            
            val requestBody = JSONObject()
                .put("email", email)
                .put("password", password)
                .toString()
            
            val request = Request.Builder()
                .url("$SUPABASE_URL/auth/v1/token?grant_type=password")
                .addHeader("apikey", SUPABASE_ANON_KEY)
                .addHeader("Content-Type", "application/json")
                .post(requestBody.toRequestBody(jsonMediaType))
                .build()
            
            DebugLogger.debug(TAG, "signInWithEmail: Sending request to ${request.url}")
            val response = client.newCall(request).execute()
            DebugLogger.debug(TAG, "signInWithEmail: Response code ${response.code}")
            
            if (response.isSuccessful) {
                val responseBody = response.body?.string()
                DebugLogger.debug(TAG, "signInWithEmail: Response body: $responseBody")
                
                if (responseBody.isNullOrBlank()) {
                    Log.e(TAG, "signInWithEmail: Empty response body")
                    return@withContext Result.failure(Exception("Empty response from server"))
                }
                
                val json = JSONObject(responseBody)
                
                // Safely extract session data
                val accessToken = json.optString("access_token")
                val refreshToken = json.optString("refresh_token")
                val expiresAt = json.optLong("expires_at", 0L)
                val userJson = json.optJSONObject("user")

                if (accessToken.isBlank()) {
                    Log.e(TAG, "signInWithEmail: Missing access_token")
                    return@withContext Result.failure(Exception("Invalid credentials"))
                }

                if (userJson == null) {
                    Log.e(TAG, "signInWithEmail: Missing user object")
                    return@withContext Result.failure(Exception("Invalid response from server"))
                }

                val userId = userJson.optString("id")
                val userEmail = userJson.optString("email")

                if (userId.isBlank()) {
                    Log.e(TAG, "signInWithEmail: Missing user ID")
                    return@withContext Result.failure(Exception("Invalid user data received"))
                }

                val session = Session(
                    accessToken = accessToken,
                    refreshToken = refreshToken,
                    userId = userId,
                    email = userEmail,
                    expiresAt = expiresAt
                )
                currentSession = session
                persistCurrentSession()
                DebugLogger.debug(TAG, "signInWithEmail: Success for user $userId")
                Result.success(session)
            } else {
                val errorBody = response.body?.string() ?: "Unknown error"
                Log.e(TAG, "signInWithEmail: Failed with error: $errorBody")
                Result.failure(Exception("Sign in failed: $errorBody"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "signInWithEmail: Exception", e)
            Result.failure(e)
        }
    }
    
    suspend fun sendOTP(phone: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val requestBody = JSONObject()
                .put("phone", phone)
                .toString()
            
            val request = Request.Builder()
                .url("$SUPABASE_URL/auth/v1/otp")
                .addHeader("apikey", SUPABASE_ANON_KEY)
                .addHeader("Content-Type", "application/json")
                .post(requestBody.toRequestBody(jsonMediaType))
                .build()
            
            val response = client.newCall(request).execute()
            
            if (response.isSuccessful) {
                Result.success(Unit)
            } else {
                val errorBody = response.body?.string() ?: "Unknown error"
                Result.failure(Exception("Failed to send OTP: $errorBody"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    suspend fun verifyPhoneOTP(phone: String, otp: String): Result<Session> = withContext(Dispatchers.IO) {
        try {
            val requestBody = JSONObject()
                .put("phone", phone)
                .put("token", otp)
                .put("type", "sms")
                .toString()
            
            val request = Request.Builder()
                .url("$SUPABASE_URL/auth/v1/verify")
                .addHeader("apikey", SUPABASE_ANON_KEY)
                .addHeader("Content-Type", "application/json")
                .post(requestBody.toRequestBody(jsonMediaType))
                .build()
            
            val response = client.newCall(request).execute()
            
            if (response.isSuccessful) {
                val responseBody = response.body?.string()
                val json = JSONObject(responseBody ?: "{}")
                
                val session = Session(
                    accessToken = json.getString("access_token"),
                    refreshToken = json.getString("refresh_token"),
                    userId = json.getJSONObject("user").getString("id"),
                    email = json.getJSONObject("user").optString("email"),
                    expiresAt = json.optLong("expires_at", 0L)
                )
                currentSession = session
                persistCurrentSession()
                Result.success(session)
            } else {
                val errorBody = response.body?.string() ?: "Unknown error"
                Result.failure(Exception("OTP verification failed: $errorBody"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    fun isAuthenticated(): Boolean = currentSession != null
    
    fun getCurrentUserId(): String? = currentSession?.userId
    
    fun getCurrentUserEmail(): String? = currentSession?.email

    suspend fun registerCurrentAndroidDevice(token: String? = FcmTokenManager.token): Result<String> = withContext(Dispatchers.IO) {
        val deviceToken = token
        if (deviceToken.isNullOrBlank()) {
            return@withContext Result.failure(Exception("No FCM token available"))
        }

        val session = getValidSession()
            ?: return@withContext Result.failure(Exception("Not authenticated"))

        try {
            val requestBody = JSONObject()
                .put("token", deviceToken)
                .put("platform", "android")
                .put("deviceType", "android")
                .put("deviceName", currentDeviceName())
                .toString()

            val request = Request.Builder()
                .url("$SUPABASE_URL/functions/v1/register-device")
                .addHeader("Content-Type", "application/json")
                .addHeader("apikey", SUPABASE_ANON_KEY)
                .addHeader("Authorization", "Bearer ${session.accessToken}")
                .post(requestBody.toRequestBody(jsonMediaType))
                .build()

            val response = client.newCall(request).execute()

            if (response.isSuccessful) {
                val responseBody = response.body?.string().orEmpty()
                val json = JSONObject(if (responseBody.isBlank()) "{}" else responseBody)
                val deviceId = json.optString("deviceId", "")
                if (deviceId.isNotBlank()) {
                    FcmTokenManager.deviceId = deviceId
                }
                FcmTokenManager.pendingRegistration = false
                Result.success(deviceId)
            } else {
                val errorBody = response.body?.string() ?: "Unknown error"
                Result.failure(Exception("Failed to register device: $errorBody"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    suspend fun signOut() = withContext(Dispatchers.IO) {
        currentSession = null
    }

    /**
     * Send password reset email with deep link redirect
     */
    suspend fun resetPassword(email: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val requestBody = JSONObject()
                .put("email", email.trim())
                .put("redirect_to", "wakeupsunshine://reset-password")
                .toString()

            val request = Request.Builder()
                .url("$SUPABASE_URL/auth/v1/recover")
                .addHeader("apikey", SUPABASE_ANON_KEY)
                .addHeader("Content-Type", "application/json")
                .post(requestBody.toRequestBody(jsonMediaType))
                .build()

            val response = client.newCall(request).execute()

            if (response.isSuccessful) {
                DebugLogger.debug(TAG, "resetPassword: email sent to $email")
                Result.success(Unit)
            } else {
                val errorBody = response.body?.string() ?: "Unknown error"
                Log.e(TAG, "resetPassword: failed $errorBody")
                Result.failure(Exception("Failed to send reset email: $errorBody"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "resetPassword failed", e)
            Result.failure(e)
        }
    }

    /**
     * Resend email verification for signup
     */
    suspend fun resendVerification(email: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val requestBody = JSONObject()
                .put("type", "signup")
                .put("email", email.trim())
                .toString()

            val request = Request.Builder()
                .url("$SUPABASE_URL/auth/v1/resend")
                .addHeader("apikey", SUPABASE_ANON_KEY)
                .addHeader("Content-Type", "application/json")
                .post(requestBody.toRequestBody(jsonMediaType))
                .build()

            val response = client.newCall(request).execute()

            if (response.isSuccessful) {
                DebugLogger.debug(TAG, "resendVerification: email sent to $email")
                Result.success(Unit)
            } else {
                val errorBody = response.body?.string() ?: "Unknown error"
                Log.e(TAG, "resendVerification: failed $errorBody")
                Result.failure(Exception("Failed to resend verification: $errorBody"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "resendVerification failed", e)
            Result.failure(e)
        }
    }

    /**
     * Delete account — calls backend edge function then signs out
     */
    suspend fun deleteAccount(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val userId = currentSession?.userId
                ?: return@withContext Result.failure(Exception("No authenticated user"))

            val session = currentSession
                ?: return@withContext Result.failure(Exception("No session"))

            val requestBody = JSONObject()
                .put("user_id", userId)
                .toString()

            val request = Request.Builder()
                .url("$SUPABASE_URL/functions/v1/delete-account")
                .addHeader("Content-Type", "application/json")
                .addHeader("apikey", SUPABASE_ANON_KEY)
                .addHeader("Authorization", "Bearer ${session.accessToken}")
                .post(requestBody.toRequestBody(jsonMediaType))
                .build()

            val response = client.newCall(request).execute()

            if (response.isSuccessful) {
                DebugLogger.debug(TAG, "deleteAccount: success for user $userId")
                // Sign out and clear local session
                val ctx = appContext
                if (ctx != null) {
                    clearPersistedSession(ctx)
                }
                currentSession = null
                Result.success(Unit)
            } else {
                val errorBody = response.body?.string() ?: "Unknown error"
                Log.e(TAG, "deleteAccount: failed $errorBody")
                Result.failure(Exception("Delete failed: $errorBody"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "deleteAccount failed", e)
            Result.failure(e)
        }
    }
}
