package com.wakeupsunshine.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

// Orange Brand Colors
val Orange500 = Color(0xFFFF6B1A)
val Orange600 = Color(0xFFFF8533)
val Orange700 = Color(0xFFE65C00)

val Green500 = Color(0xFF34C759)
val Blue500 = Color(0xFF007AFF)
val Yellow500 = Color(0xFFF2C94C)
val Red500 = Color(0xFFFF3B30)

// Fun Theme Colors (Girly: pink header, black background, grey tabs, bright pink borders)
val Pink500 = Color(0xFFFF1493)        // Bright pink (header, buttons, borders)
val Pink400 = Color(0xFFFF69B4)        // Hot pink (card borders, accents)
val Pink300 = Color(0xFFFF85C8)        // Light pink
val PinkDark = Color(0xFFC71585)       // Medium violet red
val FunBlack = Color(0xFF0A0A0A)       // Black main background
val FunGreyTab = Color(0xFF4A4A4A)     // Grey tabs
val FunCardBg = Color(0xFF1A1A1A)      // Dark card background

// Professional Theme Colors (Dark modern)
val ProfessionalBlue = Color(0xFF60A5FA)   // Modern blue accent
val ProfessionalBlueDark = Color(0xFF1E293B) // Dark slate
val ProNavy = Color(0xFF0F172A)           // Very dark navy
val ProSlate = Color(0xFF334155)          // Slate border
val ProSurface = Color(0xFF1E293B)        // Dark surface

// Light theme colors (default orange)
private val LightColorScheme = lightColorScheme(
    primary = Orange500,
    onPrimary = Color.White,
    primaryContainer = Orange500.copy(alpha = 0.1f),
    onPrimaryContainer = Orange700,
    secondary = Orange600,
    onSecondary = Color.White,
    background = Color(0xFFFFFBFE),
    onBackground = Color(0xFF1C1B1F),
    surface = Color(0xFFFFFBFE),
    onSurface = Color(0xFF1C1B1F),
    error = Red500,
    onError = Color.White
)

// Dark theme colors
private val DarkColorScheme = darkColorScheme(
    primary = Orange500,
    onPrimary = Color.White,
    primaryContainer = Orange700,
    onPrimaryContainer = Orange500.copy(alpha = 0.9f),
    secondary = Orange600,
    onSecondary = Color.White,
    background = Color(0xFF1C1B1F),
    onBackground = Color(0xFFE6E1E5),
    surface = Color(0xFF1C1B1F),
    onSurface = Color(0xFFE6E1E5),
    error = Red500,
    onError = Color.White
)

// Fun theme colors (Girly: pink headers/buttons, black background, grey tabs, bright pink borders)
private val FunColorScheme = darkColorScheme(
    primary = Pink500,              // Bright pink (header, buttons)
    onPrimary = Color.White,
    primaryContainer = Pink400,     // Hot pink (card borders)
    onPrimaryContainer = Pink300,
    secondary = Pink400,            // Hot pink accent
    onSecondary = Color.White,
    background = FunBlack,          // Black main background
    onBackground = Color.White,
    surface = FunCardBg,            // Dark card background
    onSurface = Color.White,
    surfaceVariant = FunGreyTab,    // Grey for tabs
    onSurfaceVariant = Color(0xFFB0B0B0),
    error = Red500,
    onError = Color.White,
    outline = Pink400               // Bright pink card borders
)

// Professional theme colors (Dark modern with blue accent)
private val ProfessionalColorScheme = darkColorScheme(
    primary = ProfessionalBlue,     // Modern blue accent
    onPrimary = Color.White,
    primaryContainer = ProfessionalBlueDark,
    onPrimaryContainer = ProfessionalBlue,
    secondary = ProSlate,           // Slate border
    onSecondary = Color.White,
    background = ProNavy,           // Very dark navy
    onBackground = Color(0xFFE2E8F0),
    surface = ProSurface,           // Dark slate surface
    onSurface = Color(0xFFE2E8F0),
    surfaceVariant = ProSlate,
    onSurfaceVariant = Color(0xFF94A3B8),
    error = Red500,
    onError = Color.White,
    outline = ProSlate              // Slate card borders
)

/**
 * App theme enum matching iOS AppTheme
 */
enum class AppTheme(
    val id: String,
    val displayName: String,
    val description: String
) {
    LIGHT("light", "Light", "Always light mode"),
    DARK("dark", "Dark", "Always dark mode"),
    FUN("fun", "Girly", "Pink & playful vibes"),
    PROFESSIONAL("professional", "Professional", "Dark & modern");

    companion object {
        fun from(id: String?): AppTheme = entries.find { it.id == id } ?: LIGHT
    }
}

/**
 * Theme manager to persist and apply theme selection
 */
object ThemeManager {
    private const val PREFS_NAME = "theme_prefs"
    private const val KEY_THEME = "selected_theme"
    
    fun getSavedTheme(activity: Activity): AppTheme {
        val prefs = activity.getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)
        val themeId = prefs.getString(KEY_THEME, null)
        return AppTheme.from(themeId)
    }
    
    fun saveTheme(activity: Activity, theme: AppTheme) {
        val prefs = activity.getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)
        prefs.edit().putString(KEY_THEME, theme.id).apply()
    }
}

@Composable
fun WakeUpSunshineTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    appTheme: AppTheme = AppTheme.LIGHT,
    content: @Composable () -> Unit
) {
    val colorScheme = when (appTheme) {
        AppTheme.LIGHT -> LightColorScheme
        AppTheme.DARK -> DarkColorScheme
        AppTheme.FUN -> FunColorScheme
        AppTheme.PROFESSIONAL -> ProfessionalColorScheme
    }
    
    val isDark = when (appTheme) {
        AppTheme.LIGHT -> false
        AppTheme.DARK -> true
        AppTheme.FUN -> true
        AppTheme.PROFESSIONAL -> true
    }

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colorScheme.primary.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !isDark
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
