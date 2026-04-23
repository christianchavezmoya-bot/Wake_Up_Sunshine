package com.wakeupsunshine

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class WakeUpSunshineApp : Application() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        val wakeChannel = NotificationChannel(
            CHANNEL_WAKE_ALARM,
            "Wake Alarms",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Critical wake-up alarms that override Do Not Disturb"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
            setBypassDnd(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
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
        notificationManager.createNotificationChannel(normalChannel)
    }

    companion object {
        const val CHANNEL_WAKE_ALARM = "wake_alarm_channel"
        const val CHANNEL_NORMAL = "normal_notifications"
    }
}