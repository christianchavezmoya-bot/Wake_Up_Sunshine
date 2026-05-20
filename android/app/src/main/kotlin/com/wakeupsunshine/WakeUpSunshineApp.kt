package com.wakeupsunshine

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import com.wakeupsunshine.data.SupabaseClient
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class WakeUpSunshineApp : Application() {

    companion object {
        var INSTANCE: WakeUpSunshineApp? = null
            private set
        const val CHANNEL_WAKE_ALARM = "wake_alarm_channel"
        const val CHANNEL_WAKE_ALARM_SILENT = "wake_alarm_silent_channel"
        const val CHANNEL_NORMAL = "normal_notifications"
    }

    override fun onCreate() {
        super.onCreate()
        INSTANCE = this
        SupabaseClient.appContext = applicationContext
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        val alarmAudioAttributes = AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .setUsage(AudioAttributes.USAGE_ALARM)
            .build()

        val wakeChannel = NotificationChannel(
            CHANNEL_WAKE_ALARM,
            "Wake Alarms",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "High-priority wake-up alarms"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            setSound(
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                alarmAudioAttributes
            )
        }

        // Silent wake channel — no sound so AlarmActivity is the sole audio source.
        // The old CHANNEL_WAKE_ALARM had sound baked in (Android caches channel settings),
        // so a new channel ID is required to avoid double-alarm.
        val wakeSilentChannel = NotificationChannel(
            CHANNEL_WAKE_ALARM_SILENT,
            "Wake Alarms",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "High-priority wake-up alarms"
            enableVibration(false)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            setSound(null, null)
        }

        val normalChannel = NotificationChannel(
            CHANNEL_NORMAL,
            "Notifications",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "General app notifications"
        }

        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.createNotificationChannel(wakeChannel)
        notificationManager.createNotificationChannel(wakeSilentChannel)
        notificationManager.createNotificationChannel(normalChannel)
    }

}
