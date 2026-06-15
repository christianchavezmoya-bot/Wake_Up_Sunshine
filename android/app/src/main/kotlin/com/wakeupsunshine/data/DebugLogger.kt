package com.wakeupsunshine.data

import android.content.Context
import android.util.Log
import com.wakeupsunshine.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.URL
import java.net.HttpURLConnection
import java.text.SimpleDateFormat
import java.util.*

@Serializable
data class DebugEvent(
    val id: String = UUID.randomUUID().toString(),
    val timestamp: Long = System.currentTimeMillis(),
    val traceId: String? = null,
    val eventType: String,
    val message: String,
    val metadata: Map<String, String> = emptyMap(),
    val platform: String = "android"
)

object DebugLogger {
    private const val TAG = "WakeUpSunshine"
    private const val MAX_EVENTS = 100
    private const val PREFS_NAME = "debug_logger"
    private const val EVENTS_KEY = "debug_events"
    private const val LAST_WAKE_TRACE_KEY = "last_wake_trace_id"
    
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }
    
    @Volatile
    private var events: MutableList<DebugEvent> = mutableListOf()
    
    @Volatile
    var lastWakeTraceId: String? = null
        private set
    
    @Volatile
    var lastWakeResponse: Map<String, Any?>? = null
        private set
    
    @Volatile
    var lastNotificationPayload: Map<String, Any?>? = null
        private set
    
    @Volatile
    var lastAlarmTriggeredAt: Long? = null
        private set
    
    @Volatile
    var currentTraceId: String? = null
    
    private var context: Context? = null
    
    fun init(context: Context) {
        this.context = context.applicationContext
        loadEvents()
    }
    
    // MARK: - Core Logging
    
    fun log(
        eventType: String,
        message: String,
        traceId: String? = null,
        metadata: Map<String, String> = emptyMap()
    ) {
        val event = DebugEvent(
            traceId = traceId ?: currentTraceId,
            eventType = eventType,
            message = message,
            metadata = metadata
        )
        
        synchronized(events) {
            events.add(0, event)
            if (events.size > MAX_EVENTS) {
                events = events.take(MAX_EVENTS).toMutableList()
            }
        }
        
        saveEvents()
        
        // Log to Logcat
        val metadataStr = if (metadata.isEmpty()) "" else " | $metadata"
        if (BuildConfig.DEBUG) {
            Log.d(TAG, "[$eventType] $message$metadataStr")
        }
    }

    fun debug(tag: String, message: String) {
        if (BuildConfig.DEBUG) {
            Log.d(tag, message)
        }
    }
    
    // MARK: - Convenience Methods
    
    fun logAppLaunch() {
        log("app_launch", "App launched")
    }
    
    fun logAuthRestored(userId: String, email: String?) {
        log("auth_restored", "Auth session restored", metadata = mapOf(
            "userId" to userId,
            "email" to (email ?: "unknown")
        ))
    }
    
    fun logContactsRefreshStart() {
        log("contacts_refresh_start", "Refreshing contacts")
    }
    
    fun logContactsRefreshComplete(
        peopleICanWake: Int,
        peopleWhoCanWakeMe: Int,
        pendingSent: Int,
        pendingReceived: Int
    ) {
        log("contacts_refresh_complete", "Contacts loaded", metadata = mapOf(
            "peopleICanWake" to peopleICanWake.toString(),
            "peopleWhoCanWakeMe" to peopleWhoCanWakeMe.toString(),
            "pendingSent" to pendingSent.toString(),
            "pendingReceived" to pendingReceived.toString()
        ))
    }
    
    fun logHomeDataLoaded(peopleICanWake: Int) {
        log("home_data_loaded", "Home data loaded", metadata = mapOf(
            "peopleICanWake" to peopleICanWake.toString()
        ))
    }
    
    fun logWakeButtonTapped(targetUserId: String, targetName: String) {
        currentTraceId = UUID.randomUUID().toString()
        log("wake_button_tapped", "Wake button tapped", traceId = currentTraceId, metadata = mapOf(
            "targetUserId" to targetUserId,
            "targetName" to targetName
        ))
    }
    
    fun logWakeRequestSent(traceId: String, targetUserId: String, alarmSoundId: String) {
        lastWakeTraceId = traceId
        saveLastWakeTraceId(traceId)
        
        log("wake_request_sent", "Wake request sent to backend", traceId = traceId, metadata = mapOf(
            "targetUserId" to targetUserId,
            "alarmSoundId" to alarmSoundId
        ))
    }
    
    fun logWakeResponse(response: Map<String, Any?>) {
        lastWakeResponse = response
        
        val traceId = response["traceId"] as? String
        val success = response["success"] as? Boolean ?: false
        val requestId = response["requestId"] as? String ?: "unknown"
        val devicesNotified = response["devicesNotified"] as? Int ?: 0
        
        log("wake_response", "Wake response received", traceId = traceId, metadata = mapOf(
            "success" to success.toString(),
            "requestId" to requestId,
            "devicesNotified" to devicesNotified.toString()
        ))
    }
    
    fun logFCMTokenGenerated(tokenPrefix: String, tokenSuffix: String) {
        log("fcm_token_generated", "FCM token generated", metadata = mapOf(
            "tokenPrefix" to tokenPrefix,
            "tokenSuffix" to tokenSuffix
        ))
    }
    
    fun logFCMTokenReceived(token: String) {
        val prefix = token.take(8)
        val suffix = token.takeLast(6)
        log("fcm_token_received", "FCM token received", metadata = mapOf(
            "tokenPrefix" to prefix,
            "tokenSuffix" to suffix
        ))
    }
    
    fun logDeviceTokenRegisterStart(token: String) {
        val prefix = token.take(8)
        val suffix = token.takeLast(6)
        log("device_token_register_start", "Registering device token with backend", metadata = mapOf(
            "tokenPrefix" to prefix,
            "tokenSuffix" to suffix
        ))
    }
    
    fun logDeviceTokenRegisterSuccess(deviceId: String) {
        log("device_token_register_success", "Device token registered successfully", metadata = mapOf(
            "deviceId" to deviceId
        ))
    }
    
    fun logDeviceTokenRegisterFailure(error: String) {
        log("device_token_register_failure", "Failed to register device token", metadata = mapOf(
            "error" to error
        ))
    }
    
    fun logFCMMessageReceived(payload: Map<String, Any?>, inForeground: Boolean) {
        lastNotificationPayload = payload
        
        val requestId = payload["request_id"] as? String ?: "unknown"
        val senderName = payload["sender_name"] as? String ?: "unknown"
        
        log("fcm_message_received", "FCM message received", metadata = mapOf(
            "requestId" to requestId,
            "senderName" to senderName,
            "inForeground" to inForeground.toString()
        ))
    }
    
    fun logAlarmActivityLaunched(requestId: String, senderName: String) {
        lastAlarmTriggeredAt = System.currentTimeMillis()
        
        log("alarm_activity_launched", "AlarmActivity launched", metadata = mapOf(
            "requestId" to requestId,
            "senderName" to senderName
        ))
    }
    
    fun logAlarmSoundPlaybackStarted(soundId: String) {
        log("alarm_sound_playback_started", "Playing alarm sound", metadata = mapOf(
            "soundId" to soundId
        ))
    }
    
    fun logAlarmSoundPlaybackFailed(error: String) {
        log("alarm_sound_playback_failed", "Failed to play alarm sound", metadata = mapOf(
            "error" to error
        ))
    }
    
    fun logError(error: Throwable, context: String) {
        log("error", "Error: $context", metadata = mapOf(
            "error" to (error.message ?: error.javaClass.simpleName)
        ))
    }
    
    // MARK: - Trace ID
    
    fun generateTraceId(): String {
        return UUID.randomUUID().toString()
    }
    
    // MARK: - Persistence
    
    private fun saveEvents() {
        context?.let { ctx ->
            try {
                val eventsJson = json.encodeToString(
                    kotlinx.serialization.builtins.ListSerializer(DebugEvent.serializer()),
                    events.toList()
                )
                ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    .edit()
                    .putString(EVENTS_KEY, eventsJson)
                    .apply()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to save debug events", e)
            }
        }
    }
    
    private fun loadEvents() {
        context?.let { ctx ->
            try {
                val eventsJson = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    .getString(EVENTS_KEY, null)
                
                if (eventsJson != null) {
                    events = json.decodeFromString(
                        kotlinx.serialization.builtins.ListSerializer(DebugEvent.serializer()),
                        eventsJson
                    ).toMutableList()
                }
                
                lastWakeTraceId = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    .getString(LAST_WAKE_TRACE_KEY, null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load debug events", e)
            }
        }
    }
    
    private fun saveLastWakeTraceId(traceId: String) {
        context?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            ?.edit()
            ?.putString(LAST_WAKE_TRACE_KEY, traceId)
            ?.apply()
    }
    
    // MARK: - Clear
    
    fun clearEvents() {
        events.clear()
        lastWakeResponse = null
        lastNotificationPayload = null
        lastAlarmTriggeredAt = null
        
        context?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            ?.edit()
            ?.clear()
            ?.apply()
    }
    
    // MARK: - Get Events
    
    fun getEvents(): List<DebugEvent> = synchronized(events) { events.toList() }
    
    // MARK: - Export
    
    fun exportDiagnostics(): String {
        val sdf = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
        val sb = StringBuilder()
        
        sb.appendLine("=== Wake Up Sunshine Diagnostics ===")
        sb.appendLine("Generated: ${sdf.format(Date())}")
        sb.appendLine()
        
        sb.appendLine("--- Events (last ${events.size}) ---")
        events.forEach { event ->
            val metadataStr = if (event.metadata.isEmpty()) "" else " | ${event.metadata}"
            sb.appendLine("[${sdf.format(Date(event.timestamp))}] [${event.eventType}] ${event.message}$metadataStr")
        }
        
        lastWakeResponse?.let { response ->
            sb.appendLine()
            sb.appendLine("--- Last Wake Response ---")
            sb.appendLine(response.toString())
        }
        
        lastNotificationPayload?.let { payload ->
            sb.appendLine()
            sb.appendLine("--- Last FCM Payload ---")
            sb.appendLine(payload.toString())
        }
        
        lastAlarmTriggeredAt?.let { timestamp ->
            sb.appendLine()
            sb.appendLine("--- Last Alarm Triggered ---")
            sb.appendLine(sdf.format(Date(timestamp)))
        }
        
        return sb.toString()
    }
}
