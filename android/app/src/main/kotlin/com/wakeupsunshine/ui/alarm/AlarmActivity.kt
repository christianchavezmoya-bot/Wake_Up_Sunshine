package com.wakeupsunshine.ui.alarm

import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.database.ContentObserver
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Vibrator
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.lifecycle.lifecycleScope
import com.wakeupsunshine.data.HistoryRefreshSignal
import com.wakeupsunshine.data.SupabaseClient
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Alarm
import com.wakeupsunshine.data.AlarmSound
import com.wakeupsunshine.service.WakeMessagingService
import com.wakeupsunshine.ui.theme.Orange500
import com.wakeupsunshine.ui.theme.Orange600
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class AlarmActivity : ComponentActivity() {

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var audioManager: AudioManager? = null
    private var originalAlarmVolume: Int = -1
    private var volumeObserver: ContentObserver? = null
    private var wakeRequestId: String = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setupWindowFlags()

        val senderName = intent.getStringExtra(EXTRA_SENDER_NAME) ?: "Someone"
        val message = intent.getStringExtra(EXTRA_MESSAGE) ?: ""
        val alarmSoundId = intent.getStringExtra(EXTRA_ALARM_SOUND_ID)
        val alarmSound = AlarmSound.from(alarmSoundId)
        wakeRequestId = intent.getStringExtra("wake_request_id") ?: ""

        setContent {
            AlarmScreen(
                senderName = senderName,
                message = message,
                alarmSound = alarmSound,
                onDismiss = {
                    stopAlarmSound()
                    cancelNotification()
                    sendWakeResponseAndFinish(wakeRequestId, "confirmed")
                },
                onSnooze = {
                    stopAlarmSound()
                    cancelNotification()
                    sendWakeResponseAndFinish(wakeRequestId, "snoozed", snoozeMinutes = 5)
                }
            )
        }
    }

    override fun onStart() {
        super.onStart()
        if (mediaPlayer == null) {
            val alarmSoundId = intent.getStringExtra(EXTRA_ALARM_SOUND_ID)
            playAlarmSound(AlarmSound.from(alarmSoundId))
        }
        // Auto-dismiss after 5 minutes if the user doesn't respond
        Handler(Looper.getMainLooper()).postDelayed({
            if (!isFinishing) {
                stopAlarmSound()
                cancelNotification()
                sendWakeResponseAndFinish(wakeRequestId, "missed")
            }
        }, 5 * 60 * 1000L)
    }

    override fun onDestroy() {
        super.onDestroy()
        stopAlarmSound()
    }

    private fun startVibration() {
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        vibrator?.let {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val pattern = longArrayOf(0, 500, 500)
                val vibrationEffect = android.os.VibrationEffect.createWaveform(pattern, 0)
                val vibrationAttributes = android.os.VibrationAttributes.Builder()
                    .setUsage(android.os.VibrationAttributes.USAGE_ALARM)
                    .build()
                it.vibrate(vibrationEffect, vibrationAttributes)
            } else {
                @Suppress("DEPRECATION")
                it.vibrate(longArrayOf(0, 500, 500), 0)
            }
        }
    }

    private fun forceMaxVolume() {
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val am = audioManager ?: return
        val maxVol = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        originalAlarmVolume = am.getStreamVolume(AudioManager.STREAM_ALARM)
        am.setStreamVolume(AudioManager.STREAM_ALARM, maxVol, 0)

        // Make hardware volume buttons control the alarm stream
        setVolumeControlStream(AudioManager.STREAM_ALARM)

        // Reset to max if the user tries to lower it while the alarm is active
        volumeObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) {
                val current = am.getStreamVolume(AudioManager.STREAM_ALARM)
                if (current < maxVol) {
                    am.setStreamVolume(AudioManager.STREAM_ALARM, maxVol, 0)
                }
            }
        }
        volumeObserver?.let {
            contentResolver.registerContentObserver(Settings.System.CONTENT_URI, true, it)
        }
    }

    private fun restoreVolume() {
        volumeObserver?.let { contentResolver.unregisterContentObserver(it) }
        volumeObserver = null
        if (originalAlarmVolume >= 0) {
            audioManager?.setStreamVolume(AudioManager.STREAM_ALARM, originalAlarmVolume, 0)
        }
    }

    private fun stopAlarmSound() {
        restoreVolume()

        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null

        vibrator?.cancel()
        vibrator = null
    }

    private fun playAlarmSound(sound: AlarmSound) {
        forceMaxVolume()

        // Try to play custom sound from res/raw
        val resourceId = resources.getIdentifier(
            sound.id,
            "raw",
            packageName
        )
        
        if (resourceId != 0) {
            // Custom sound found
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(this@AlarmActivity, Uri.parse("android.resource://$packageName/$resourceId"))
                isLooping = true
                prepare()
                start()
            }
        } else {
            // Fallback: Play default alarm sound and vibrate
            try {
                val defaultRingtone = android.media.RingtoneManager.getDefaultUri(
                    android.media.RingtoneManager.TYPE_ALARM
                ) ?: android.media.RingtoneManager.getDefaultUri(
                    android.media.RingtoneManager.TYPE_NOTIFICATION
                )
                
                mediaPlayer = MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    setDataSource(this@AlarmActivity, defaultRingtone)
                    isLooping = true
                    prepare()
                    start()
                }
            } catch (e: Exception) {
                // If all else fails, just vibrate
                startVibration()
            }
        }
        
        // Also start vibration
        startVibration()
    }

    private fun cancelNotification() {
        val nm = getSystemService(NotificationManager::class.java)
        nm.cancel(WakeMessagingService.NOTIFICATION_ID)
    }

    private fun sendWakeResponseAndFinish(wakeRequestId: String, action: String, snoozeMinutes: Int = 0) {
        if (wakeRequestId.isEmpty()) {
            finish()
            return
        }
        val ctx = applicationContext
        val jsonMediaType = "application/json; charset=utf-8".toMediaType()
        lifecycleScope.launch(
            Dispatchers.IO + CoroutineExceptionHandler { _, e ->
                Log.e("AlarmActivity", "sendWakeResponseAndFinish: unhandled error", e)
                runOnUiThread { finish() }
            }
        ) {
            try {
                SupabaseClient.restoreSession(ctx)
                val session = SupabaseClient.session
                if (session == null) {
                    Log.e("AlarmActivity", "sendWakeResponseAndFinish: no session, skipping")
                    withContext(Dispatchers.Main) { finish() }
                    return@launch
                }
                val payload = JSONObject()
                    .put("wakeRequestId", wakeRequestId)
                    .put("action", action)
                if (action == "snoozed" && snoozeMinutes > 0) {
                    payload.put("snoozeMinutes", snoozeMinutes)
                }
                val request = Request.Builder()
                    .url("${SupabaseClient.SUPABASE_URL}/functions/v1/wake-response")
                    .addHeader("Content-Type", "application/json")
                    .addHeader("apikey", SupabaseClient.SUPABASE_ANON_KEY)
                    .addHeader("Authorization", "Bearer ${session.accessToken}")
                    .post(payload.toString().toRequestBody(jsonMediaType))
                    .build()
                val response = SupabaseClient.sharedHttpClient.newCall(request).execute()
                com.wakeupsunshine.data.DebugLogger.debug("AlarmActivity", "sendWakeResponseAndFinish action=$action response=${response.code}")
                if (response.isSuccessful) {
                    HistoryRefreshSignal.emit()
                }
            } catch (e: Exception) {
                Log.e("AlarmActivity", "sendWakeResponseAndFinish: failed", e)
            } finally {
                withContext(Dispatchers.Main) { finish() }
            }
        }
    }

    private fun setupWindowFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    companion object {
        const val EXTRA_SENDER_NAME = "sender_name"
        const val EXTRA_MESSAGE = "message"
        const val EXTRA_ALARM_SOUND_ID = "alarm_sound_id"
    }
}

@Composable
fun AlarmScreen(
    senderName: String,
    message: String,
    alarmSound: AlarmSound = AlarmSound.CLASSIC,
    onDismiss: () -> Unit,
    onSnooze: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(Orange500, Orange600)
                )
            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // Alarm Icon
            Icon(
                imageVector = androidx.compose.material.icons.Icons.Default.Alarm,
                contentDescription = "Alarm",
                modifier = Modifier.size(100.dp),
                tint = MaterialTheme.colorScheme.onPrimary
            )

            Spacer(modifier = Modifier.height(32.dp))

            // Title
            Text(
                text = "Wake Up!",
                fontSize = 36.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onPrimary
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Sender info
            Text(
                text = "Wake request from $senderName",
                fontSize = 18.sp,
                color = MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.9f)
            )

            // Message
            if (message.isNotEmpty()) {
                Spacer(modifier = Modifier.height(16.dp))
                Surface(
                    color = MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.2f),
                    shape = MaterialTheme.shapes.medium
                ) {
                    Text(
                        text = message,
                        modifier = Modifier.padding(16.dp),
                        color = MaterialTheme.colorScheme.onPrimary
                    )
                }
            }

            Spacer(modifier = Modifier.height(48.dp))

            // Action buttons
            Button(
                onClick = onDismiss,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.onPrimary
                )
            ) {
                Text(
                    text = "I'm Awake",
                    color = Orange500,
                    fontWeight = FontWeight.SemiBold
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            OutlinedButton(
                onClick = onSnooze,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = MaterialTheme.colorScheme.onPrimary
                )
            ) {
                Text("Snooze (5 min)")
            }
        }
    }
}
