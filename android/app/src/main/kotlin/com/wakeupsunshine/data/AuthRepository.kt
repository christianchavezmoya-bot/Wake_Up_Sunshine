package com.wakeupsunshine.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthRepository @Inject constructor() {

    // MARK: - Email Authentication (Primary)

    /**
     * Sign up with email and password
     */
    suspend fun signUp(email: String, password: String, displayName: String): Result<Boolean> = withContext(Dispatchers.IO) {
        try {
            val result = SupabaseClient.signUpWithEmail(email, password, displayName)
            result.map { true }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Sign in with email and password
     */
    suspend fun signIn(email: String, password: String): Result<Boolean> = withContext(Dispatchers.IO) {
        try {
            val result = SupabaseClient.signInWithEmail(email, password)
            result.map { true }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    // MARK: - Phone Authentication (Optional)

    /**
     * Send OTP to phone number via Supabase
     * @param phoneNumber E.164 formatted phone number (e.g., +61412345678)
     */
    suspend fun sendOTP(phoneNumber: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            SupabaseClient.sendOTP(phoneNumber)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Verify OTP code
     * @param phoneNumber E.164 formatted phone number
     * @param otp 6-digit OTP code
     */
    suspend fun verifyOTP(phoneNumber: String, otp: String): Result<Boolean> = withContext(Dispatchers.IO) {
        try {
            val result = SupabaseClient.verifyPhoneOTP(phoneNumber, otp)
            result.map { true }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    // MARK: - Session Management

    /**
     * Check if user is authenticated
     */
    fun isAuthenticated(): Boolean {
        return SupabaseClient.isAuthenticated()
    }

    /**
     * Get current user ID
     */
    fun getCurrentUserId(): String? {
        return SupabaseClient.getCurrentUserId()
    }

    /**
     * Get current user email
     */
    fun getCurrentUserEmail(): String? {
        return SupabaseClient.getCurrentUserEmail()
    }

    /**
     * Sign out
     */
    suspend fun signOut() = withContext(Dispatchers.IO) {
        SupabaseClient.signOut()
    }
}
