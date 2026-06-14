package com.wakeupsunshine.ui.auth

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wakeupsunshine.data.AuthRepository
import com.wakeupsunshine.data.DebugLogger
import com.wakeupsunshine.data.FcmTokenManager
import com.wakeupsunshine.data.SupabaseClient
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    @ApplicationContext private val context: Context
) : ViewModel() {

    private val _authState = MutableStateFlow<AuthState>(AuthState.Idle)
    val authState: StateFlow<AuthState> = _authState.asStateFlow()

    init {
        // Restore persisted session on every cold start (process killed by OS / Samsung aggressive
        // battery management). Auto-refreshes the access token if it has expired.
        viewModelScope.launch {
            SupabaseClient.restoreSession(context)
            if (SupabaseClient.isAuthenticated()) {
                val valid = if (SupabaseClient.isSessionExpired()) {
                    val result = SupabaseClient.refreshSession()
                    if (result.isFailure) {
                        SupabaseClient.clearPersistedSession(context)
                    }
                    result.isSuccess
                } else {
                    true
                }
                if (valid) {
                    registerCurrentDeviceIfPossible()
                    _authState.value = AuthState.Authenticated
                }
            }
        }
    }

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    // MARK: - Email Authentication (Primary)

    /**
     * Sign up with email and password
     */
    fun signUp(email: String, password: String, displayName: String, onResult: (Boolean, String?) -> Unit) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null

            val result = authRepository.signUp(email, password, displayName)

            _isLoading.value = false

            result.fold(
                onSuccess = {
                    registerCurrentDeviceIfPossible()
                    _authState.value = AuthState.Authenticated
                    onResult(true, null)
                },
                onFailure = { e ->
                    _error.value = e.message
                    onResult(false, e.message)
                }
            )
        }
    }

    /**
     * Sign in with email and password
     */
    fun signIn(email: String, password: String, onResult: (Boolean, String?) -> Unit) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null

            val result = authRepository.signIn(email, password)

            _isLoading.value = false

            result.fold(
                onSuccess = {
                    registerCurrentDeviceIfPossible()
                    _authState.value = AuthState.Authenticated
                    onResult(true, null)
                },
                onFailure = { e ->
                    _error.value = e.message
                    onResult(false, e.message)
                }
            )
        }
    }

    // MARK: - Phone Authentication (Optional)

    /**
     * Send OTP to phone number
     * @param phoneNumber E.164 formatted phone number
     */
    fun sendOTP(phoneNumber: String, onResult: (Boolean, String?) -> Unit) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null

            val result = authRepository.sendOTP(phoneNumber)

            _isLoading.value = false

            result.fold(
                onSuccess = {
                    _authState.value = AuthState.OTPSent(phoneNumber)
                    onResult(true, null)
                },
                onFailure = { e ->
                    _error.value = e.message
                    onResult(false, e.message)
                }
            )
        }
    }

    /**
     * Verify OTP code
     * @param phoneNumber E.164 formatted phone number
     * @param otp 6-digit OTP code
     */
    fun verifyOTP(phoneNumber: String, otp: String, onResult: (Boolean, String?) -> Unit) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null

            val result = authRepository.verifyOTP(phoneNumber, otp)

            _isLoading.value = false

            result.fold(
                onSuccess = {
                    registerCurrentDeviceIfPossible()
                    _authState.value = AuthState.Authenticated
                    onResult(true, null)
                },
                onFailure = { e ->
                    _error.value = e.message
                    onResult(false, e.message)
                }
            )
        }
    }

    /**
     * Handle auth callback from email verification / password reset deep link.
     * Parses tokens from the URL fragment and establishes a session.
     */
    fun handleAuthCallback(accessToken: String, refreshToken: String) {
        val ok = SupabaseClient.setSessionFromAuthCallback(accessToken, refreshToken)
        if (ok) {
            viewModelScope.launch {
                registerCurrentDeviceIfPossible()
                _authState.value = AuthState.Authenticated
            }
        }
    }

    /**
     * Check if user is already authenticated
     */
    fun checkAuthState() {
        if (authRepository.isAuthenticated()) {
            _authState.value = AuthState.Authenticated
        }
    }

    /**
     * Sign out
     */
    fun signOut() {
        viewModelScope.launch {
            authRepository.signOut()
            _authState.value = AuthState.Idle
        }
    }

    /**
     * Send password reset email
     */
    fun resendVerification(email: String, onResult: (Boolean, String?) -> Unit) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null

            val result = SupabaseClient.resendVerification(email)

            _isLoading.value = false

            result.fold(
                onSuccess = {
                    onResult(true, null)
                },
                onFailure = { e ->
                    _error.value = e.message
                    onResult(false, e.message)
                }
            )
        }
    }

    fun resetPassword(email: String, onResult: (Boolean, String?) -> Unit) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null

            val result = SupabaseClient.resetPassword(email)

            _isLoading.value = false

            result.fold(
                onSuccess = {
                    onResult(true, null)
                },
                onFailure = { e ->
                    _error.value = e.message
                    onResult(false, e.message)
                }
            )
        }
    }

    /**
     * Delete account permanently
     */
    fun deleteAccount(onResult: (Boolean, String?) -> Unit) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null

            val result = SupabaseClient.deleteAccount()

            _isLoading.value = false

            result.fold(
                onSuccess = {
                    _authState.value = AuthState.Idle
                    onResult(true, null)
                },
                onFailure = { e ->
                    _error.value = e.message
                    onResult(false, e.message)
                }
            )
        }
    }

    private fun registerCurrentDeviceIfPossible() {
        if (FcmTokenManager.token.isNullOrBlank()) return
        if (!FcmTokenManager.pendingRegistration && !FcmTokenManager.currentDeviceId().isNullOrBlank()) return

        viewModelScope.launch {
            val result = SupabaseClient.registerCurrentAndroidDevice()
            result.onSuccess { deviceId ->
                if (deviceId.isNotBlank()) {
                    DebugLogger.logDeviceTokenRegisterSuccess(deviceId)
                }
            }.onFailure { error ->
                DebugLogger.logDeviceTokenRegisterFailure(error.message ?: "Unknown error")
            }
        }
    }
}

sealed class AuthState {
    object Idle : AuthState()
    data class OTPSent(val phoneNumber: String) : AuthState()
    object Authenticated : AuthState()
}
