package com.wakeupsunshine.ui.alarm

import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Vibrator
import android.util.Log
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.wakeupsunshine.data.HistoryRefreshSignal
import com.wakeupsunshine.data.SupabaseClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setupWindowFlags()

        val senderName = intent.getStringExtra(EXTRA_SENDER_NAME) ?: "Someone"
        val message = intent.getStringExtra(EXTRA_MESSAGE) ?: ""
        val alarmSoundId = intent.getStringExtra(EXTRA_ALARM_SOUND_ID)
        val alarmSound = AlarmSound.from(alarmSoundId)
        val wakeRequestId = intent.getStringExtra("wake_request_id") ?: ""

        setContent {
            AlarmScreen(
                senderName = senderName,
                message = message,
                alarmSound = alarmSound,
                onDismiss = {
                    stopAlarmSound()
                    cancelNotification()
                    sendWakeResponse(wakeRequestId, "confirmed")
                    finish()
                },
                onSnooze = {
                    stopAlarmSound()
                    cancelNotification()
                    sendWakeResponse(wakeRequestId, "snoozed", snoozeMinutes = 5)
                    finish()
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

    private fun stopAlarmSound() {
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        
        vibrator?.cancel()
        vibrator = null
    }

    private fun playAlarmSound(sound: AlarmSound) {
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

    private fun sendWakeResponse(wakeRequestId: String, action: String, snoozeMinutes: Int = 0) {
        if (wakeRequestId.isEmpty()) return
        val ctx = applicationContext
        val jsonMediaType = "application/json; charset=utf-8".toMediaType()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                SupabaseClient.restoreSession(ctx)
                val session = SupabaseClient.session
                if (session == null) {
                    Log.e("AlarmActivity", "sendWakeResponse: no session after restore, skipping")
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
                val response = OkHttpClient().newCall(request).execute()
                com.wakeupsunshine.data.DebugLogger.debug("AlarmActivity", "sendWakeResponse action=$action response=${response.code}")
                if (response.isSuccessful) {
                    HistoryRefreshSignal.emit()
                }
            } catch (e: Exception) {
                Log.e("AlarmActivity", "sendWakeResponse: failed", e)
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
