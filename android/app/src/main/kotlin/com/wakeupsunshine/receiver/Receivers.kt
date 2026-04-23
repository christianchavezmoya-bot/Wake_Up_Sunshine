package com.wakeupsunshine.receiver

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val notificationManager = context.getSystemService(NotificationManager::class.java)

        // Cancel any existing wake notifications
        notificationManager.cancel(1001)
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // Reschedule any pending alarms after device reboot
            // This would involve reading from local storage and rescheduling
        }
    }
}

class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_AWAKE -> {
                // User confirmed they are awake
                val wakeRequestId = intent.getStringExtra("wake_request_id") ?: ""
                // Send response to backend
                // Cancel notification
                val notificationManager = context.getSystemService(NotificationManager::class.java)
                notificationManager.cancel(1001)
            }
            ACTION_SNOOZE -> {
                // Snooze for 5 minutes
                // Reschedule alarm
            }
        }
    }

    companion object {
        const val ACTION_AWAKE = "com.wakeupsunshine.ACTION_AWAKE"
        const val ACTION_SNOOZE = "com.wakeupsunshine.ACTION_SNOOZE"
    }
}