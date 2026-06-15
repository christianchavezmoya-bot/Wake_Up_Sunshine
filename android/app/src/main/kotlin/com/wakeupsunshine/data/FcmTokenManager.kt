package com.wakeupsunshine.data

object FcmTokenManager {
    private const val PREFS_NAME = "fcm_token_manager"
    private const val KEY_DEVICE_ID = "backend_device_id"

    var token: String? = null
    var deviceId: String? = null
        set(value) {
            field = value
            val context = SupabaseClient.appContext ?: return
            context.getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_DEVICE_ID, value)
                .apply()
        }
    var pendingRegistration: Boolean = false

    fun currentDeviceId(): String? {
        deviceId?.let { return it }
        val context = SupabaseClient.appContext ?: return null
        val persisted = context.getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)
            .getString(KEY_DEVICE_ID, null)
        deviceId = persisted
        return persisted
    }
}
