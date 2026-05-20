package com.wakeupsunshine.data

import androidx.compose.ui.graphics.Color
import com.wakeupsunshine.ui.theme.*

/**
 * 4 custom sounds + classic (system fallback). IDs match iOS and backend exactly.
 */
enum class AlarmSound(
    val id: String,
    val displayName: String,
    val description: String,
    val iconName: String,
    val iconColor: Color
) {
    WAKE_UP(
        id = "wake_up",
        displayName = "Wake Up",
        description = "Rise and shine!",
        iconName = "wb_sunny",
        iconColor = Orange500
    ),
    HEY_YOU(
        id = "hey_you",
        displayName = "Hey You Wake",
        description = "Hey, get up!",
        iconName = "music_note",
        iconColor = Green500
    ),
    MINIONS(
        id = "minions",
        displayName = "Minions",
        description = "Banana time!",
        iconName = "sentiment_very_satisfied",
        iconColor = Yellow500
    ),
    RINGING_TONE(
        id = "ringing_tone",
        displayName = "Ringing Tone",
        description = "Classic phone ring",
        iconName = "phone",
        iconColor = Blue500
    ),
    CLASSIC(
        id = "classic",
        displayName = "Classic Alarm",
        description = "Traditional alarm",
        iconName = "alarm",
        iconColor = Red500
    );

    companion object {
        fun from(id: String?): AlarmSound = entries.find { it.id == id } ?: CLASSIC

        val allSounds: List<AlarmSound> get() = entries
        val default: AlarmSound get() = CLASSIC
        val allowedIds: Set<String> get() = entries.map { it.id }.toSet()
    }
}
