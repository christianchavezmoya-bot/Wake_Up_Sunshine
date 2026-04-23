package com.wakeupsunshine.service

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.wakeupsunshine.R
import com.wakeupsunshine.WakeUpSunshineApp
import com.wakeupsunshine.ui.alarm.AlarmActivity
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class WakeMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        val data = remoteMessage.data
        val senderName = data["sender_name"] ?: "Someone"
        val message = data["message"] ?: ""
        val wakeRequestId = data["wake_request_id"] ?: ""

        showWakeNotification(senderName, message, wakeRequestId)
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // Send token to backend
        // Supabase will handle this via Edge Function
    }

    private fun showWakeNotification(
        senderName: String,
        message: String,
        wakeRequestId: String
    ) {
        val notificationManager = getSystemService(NotificationManager::class.java)

        // Intent to open AlarmActivity
        val intent = Intent(this, AlarmActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(AlarmActivity.EXTRA_SENDER_NAME, senderName)
            putExtra(AlarmActivity.EXTRA_MESSAGE, message)
            putExtra("wake_request_id", wakeRequestId)
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
        }

        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            1,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Alarm sound
        val alarmSoundUri = Uri.parse("android.resource://com.wakeupsunshine/raw/alarm_sound")
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        // Vibration pattern
        val vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500, 200, 500)

        val notification = NotificationCompat.Builder(this, WakeUpSunshineApp.CHANNEL_WAKE_ALARM)
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
            .setSound(alarmSoundUri, audioAttributes)
            .setVibrate(vibrationPattern)
            .setOnlyAlertOnce(true)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    companion object {
        private const val NOTIFICATION_ID = 1001
    }
}