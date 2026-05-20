package com.wakeupsunshine.service

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.wakeupsunshine.R
import com.wakeupsunshine.WakeUpSunshineApp
import com.wakeupsunshine.data.DebugLogger
import com.wakeupsunshine.data.FcmTokenManager
import com.wakeupsunshine.data.HistoryRefreshSignal
import com.wakeupsunshine.data.SupabaseClient
import com.wakeupsunshine.data.WakeResponseEvent
import com.wakeupsunshine.data.WakeResponseSignal
import com.wakeupsunshine.ui.alarm.AlarmActivity
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

@AndroidEntryPoint
class WakeMessagingService : FirebaseMessagingService() {
    
    private val tag = "WakeMessagingService"

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        val data = remoteMessage.data
        val type = data["type"] ?: ""

        DebugLogger.debug(tag, "onMessageReceived: type=$type")
        DebugLogger.logFCMMessageReceived(
            payload = data.toMap().mapValues { it.value as Any? },
            inForeground = true
        )

        when (type) {
            "wake_response" -> handleWakeResponse(data)
            else -> {
                // wake_alarm or legacy messages without explicit type
                val senderName = data["sender_name"] ?: "Someone"
                val message = data["message"] ?: ""
                val wakeRequestId = data["wake_request_id"] ?: data["request_id"] ?: ""
                val alarmSoundId = data["alarm_sound_id"]
                DebugLogger.debug(tag, "Showing wake alarm: sender=$senderName wakeRequestId=$wakeRequestId")
                showWakeNotification(senderName, message, wakeRequestId, alarmSoundId)
            }
        }
    }

    private fun handleWakeResponse(data: Map<String, String>) {
        val receiverName = data["receiver_name"] ?: "They"
        val action = data["response_action"] ?: "confirmed"
        val wakeRequestId = data["wake_request_id"] ?: ""

        DebugLogger.debug(tag, "handleWakeResponse: action=$action receiverName=$receiverName wakeRequestId=$wakeRequestId")

        val title = when (action) {
            "confirmed" -> "They're Awake! 🌅"
            "snoozed"   -> "Snoozed 💤"
            else        -> "Dismissed ❌"
        }
        val body = when (action) {
            "confirmed" -> "$receiverName confirmed they're awake"
            "snoozed"   -> "$receiverName snoozed the alarm"
            else        -> "$receiverName dismissed the alarm"
        }

        // Emit to HomeScreen so the waiting dialog updates immediately
        WakeResponseSignal.emit(WakeResponseEvent(receiverName = receiverName, action = action))
        HistoryRefreshSignal.emit()

        // Show a regular notification in case the app is backgrounded
        val notificationManager = getSystemService(NotificationManager::class.java)
        val notification = android.app.Notification.Builder(this, WakeUpSunshineApp.CHANNEL_NORMAL)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .build()
        notificationManager.notify(RESPONSE_NOTIFICATION_ID, notification)
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        DebugLogger.debug(tag, "onNewToken: ${token.take(8)}...${token.takeLast(6)}")
        
        // Store token in FcmTokenManager
        FcmTokenManager.token = token
        
        // Log token received
        DebugLogger.logFCMTokenReceived(token)
        
        // Register with backend
        registerTokenWithBackend(token)
    }
    
    private fun registerTokenWithBackend(token: String) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val session = SupabaseClient.session
                if (session == null) {
                    DebugLogger.debug(tag, "No session, caching token for later registration")
                    FcmTokenManager.pendingRegistration = true
                    return@launch
                }
                
                DebugLogger.logDeviceTokenRegisterStart(token)
                val result = SupabaseClient.registerCurrentAndroidDevice(token)
                result.onSuccess { deviceId ->
                    DebugLogger.debug(tag, "Token registered successfully: deviceId=$deviceId")
                    DebugLogger.logDeviceTokenRegisterSuccess(deviceId)
                }.onFailure { error ->
                    Log.e(tag, "Failed to register token: ${error.message}")
                    DebugLogger.logDeviceTokenRegisterFailure(error.message ?: "Unknown error")
                }
            } catch (e: Exception) {
                Log.e(tag, "Error registering token", e)
                DebugLogger.logDeviceTokenRegisterFailure(e.message ?: "Unknown error")
            }
        }
    }

    private fun showWakeNotification(
        senderName: String,
        message: String,
        wakeRequestId: String,
        alarmSoundId: String?
    ) {
        val notificationManager = getSystemService(NotificationManager::class.java)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val canFsi = notificationManager.canUseFullScreenIntent()
            DebugLogger.debug(tag, "canUseFullScreenIntent=$canFsi")
            DebugLogger.log("full_screen_intent_check", "Full screen intent capability",
                metadata = mapOf("canUseFullScreenIntent" to canFsi.toString()))
        }

        // Intent to open AlarmActivity
        val intent = Intent(this, AlarmActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(AlarmActivity.EXTRA_SENDER_NAME, senderName)
            putExtra(AlarmActivity.EXTRA_MESSAGE, message)
            putExtra("wake_request_id", wakeRequestId)
            putExtra(AlarmActivity.EXTRA_ALARM_SOUND_ID, alarmSoundId)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Full-screen intent for lock screen
        val fullScreenIntent = Intent(this, AlarmActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(AlarmActivity.EXTRA_SENDER_NAME, senderName)
            putExtra(AlarmActivity.EXTRA_MESSAGE, message)
            putExtra("wake_request_id", wakeRequestId)
            putExtra(AlarmActivity.EXTRA_ALARM_SOUND_ID, alarmSoundId)
        }

        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            1,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Resolve alarm sound URI — fall back to system alarm if the raw file doesn't exist
        val soundResId = alarmSoundId?.let { id ->
            resources.getIdentifier(id, "raw", packageName).takeIf { it != 0 }
        }
        val alarmSoundUri: Uri = if (soundResId != null) {
            Uri.parse("android.resource://$packageName/$soundResId")
        } else {
            android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_ALARM)
                ?: android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_NOTIFICATION)
        }

        // Vibration pattern
        val vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500, 200, 500)

        val notification = NotificationCompat.Builder(this, WakeUpSunshineApp.CHANNEL_WAKE_ALARM_SILENT)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Wake Up! 🌅")
            .setContentText("$senderName is trying to wake you")
            .setStyle(NotificationCompat.BigTextStyle().bigText("$senderName is trying to wake you\n$message"))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setSound(alarmSoundUri)
            .setVibrate(vibrationPattern)
            .setOnlyAlertOnce(true)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    companion object {
        const val NOTIFICATION_ID = 1001
        const val RESPONSE_NOTIFICATION_ID = 1002
    }
}
