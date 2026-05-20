package com.wakeupsunshine.ui.settings

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.wakeupsunshine.data.AlarmSound
import com.wakeupsunshine.data.AndroidBiometricManager
import com.wakeupsunshine.data.FcmTokenManager
import com.wakeupsunshine.data.ContactItem
import com.wakeupsunshine.data.SupabaseClient
import com.wakeupsunshine.data.InviteRepository
import com.wakeupsunshine.ui.alarm.AlarmSoundPicker
import com.wakeupsunshine.ui.theme.AppTheme
import com.wakeupsunshine.ui.theme.Orange500
import com.wakeupsunshine.ui.theme.Pink500
import com.wakeupsunshine.ui.theme.ProfessionalBlue
import com.wakeupsunshine.ui.theme.Red500
import com.wakeupsunshine.ui.auth.AuthViewModel
import com.wakeupsunshine.ui.theme.ThemeManager
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.net.URL
import javax.net.ssl.HttpsURLConnection
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.Duration
import java.time.OffsetDateTime

private const val PREFS_NAME = "alarm_prefs"
private const val KEY_ALARM_SOUND_ID = "selected_alarm_sound_id"

// MARK: - Profile Data
data class ProfileData(
    val id: String = "",
    val email: String = "",
    val displayName: String = "",
    val phoneNumber: String = "",
    val avatarColor: String = "#FF6B35"
)

data class DeviceDataAndroid(
    val id: String = "",
    val platform: String = "",
    val deviceType: String = "",
    val deviceName: String = "",
    val isPrimary: Boolean = false,
    val criticalAlertsEnabled: Boolean = false,
    val isActive: Boolean = false,
    val isCurrent: Boolean = false,
    val lastActiveAt: String? = null
)

data class BlockedContactDataAndroid(
    val id: String,
    val email: String,
    val displayName: String
)

// MARK: - Profile ViewModel
class ProfileViewModelAndroid : androidx.lifecycle.ViewModel() {
    var profile by mutableStateOf<ProfileData?>(null)
        private set
    var isLoading by mutableStateOf(false)
        private set
    var isSaving by mutableStateOf(false)
        private set
    var error by mutableStateOf<String?>(null)
        private set

    suspend fun load(force: Boolean = false) {
        if (isLoading) return
        if (profile != null && !force) return
        isLoading = true
        error = null
        try {
            val fallbackEmail = SupabaseClient.getCurrentUserEmail().orEmpty()
            if (profile == null && fallbackEmail.isNotBlank()) {
                profile = ProfileData(
                    id = SupabaseClient.getCurrentUserId().orEmpty(),
                    email = fallbackEmail,
                    avatarColor = "#FF6B35"
                )
                // Save display name to shared prefs for greeting
                saveDisplayNameToPrefs(profile!!.displayName)
            }

            val session = SupabaseClient.getValidSession()
            if (session == null) {
                error = "Not authenticated"
                isLoading = false
                return
            }

            withContext(Dispatchers.IO) {
                val url = URL("${SupabaseClient.SUPABASE_URL}/functions/v1/get-profile")
                val connection = url.openConnection() as HttpsURLConnection
                connection.requestMethod = "GET"
                connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
                connection.setRequestProperty("apikey", SupabaseClient.SUPABASE_ANON_KEY)
                connection.setRequestProperty("Content-Type", "application/json")

                if (connection.responseCode == 200) {
                    val response = connection.inputStream.bufferedReader().readText()
                    val json = JSONObject(response)
                    if (json.optBoolean("success", false)) {
                        val profileJson = json.optJSONObject("profile")
                        if (profileJson != null) {
                            profile = profileJson.toProfileData()
                        }
                    } else {
                        error = json.optString("error", "Failed to load profile")
                    }
                } else {
                    error = "Server error: ${connection.responseCode}"
                }
                connection.disconnect()
            }
        } catch (e: Exception) {
            error = e.message
        }
        isLoading = false
    }

    suspend fun save(displayName: String, phoneNumber: String) {
        isSaving = true
        error = null
        try {
            val session = SupabaseClient.getValidSession()
            if (session == null) {
                error = "Not authenticated"
                isSaving = false
                return
            }

            val url = URL("${SupabaseClient.SUPABASE_URL}/functions/v1/update-profile")
            val connection = url.openConnection() as HttpsURLConnection
            connection.requestMethod = "POST"
            connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            connection.setRequestProperty("apikey", SupabaseClient.SUPABASE_ANON_KEY)
            connection.setRequestProperty("Content-Type", "application/json")
            connection.doOutput = true

            val body = JSONObject().apply {
                put("displayName", displayName.trim())
                put("phoneNumber", phoneNumber.trim())
            }

            connection.outputStream.use { output ->
                output.write(body.toString().toByteArray())
            }

            if (connection.responseCode == 200) {
                val response = connection.inputStream.bufferedReader().readText()
                val json = JSONObject(response)
                if (json.optBoolean("success", false)) {
                    val profileJson = json.optJSONObject("profile")
                    if (profileJson != null) {
                        profile = profileJson.toProfileData()
                    }
                } else {
                    error = json.optString("error", "Failed to save profile")
                }
            } else {
                error = "Server error: ${connection.responseCode}"
            }
            connection.disconnect()
        } catch (e: Exception) {
            error = e.message
        }
        isSaving = false
    }

    private fun JSONObject.toProfileData(): ProfileData {
        val data = ProfileData(
            id = optString("id"),
            email = optString("email"),
            displayName = optString("displayName"),
            phoneNumber = optString("phoneNumber"),
            avatarColor = optString("avatarColor", "#FF6B35")
        )
        // Save display name to shared prefs for greeting
        saveDisplayNameToPrefs(data.displayName)
        return data
    }

    private fun saveDisplayNameToPrefs(name: String) {
        if (name.isNotBlank()) {
            try {
                val ctx = com.wakeupsunshine.WakeUpSunshineApp.INSTANCE
                if (ctx != null) {
                    ctx.getSharedPreferences("user_profile", android.content.Context.MODE_PRIVATE)
                        .edit().putString("display_name", name).apply()
                }
            } catch (_: Exception) {}
        }
    }
}

class DevicesViewModelAndroid : androidx.lifecycle.ViewModel() {
    var devices by mutableStateOf<List<DeviceDataAndroid>>(emptyList())
        private set
    var isLoading by mutableStateOf(false)
        private set
    var error by mutableStateOf<String?>(null)
        private set

    suspend fun load(force: Boolean = false) {
        if (isLoading) return
        if (devices.isNotEmpty() && !force) return
        isLoading = true
        error = null
        try {
            val session = SupabaseClient.getValidSession()
            if (session == null) {
                error = "Not authenticated"
                isLoading = false
                return
            }

            withContext(Dispatchers.IO) {
                val url = URL("${SupabaseClient.SUPABASE_URL}/functions/v1/get-devices")
                val connection = url.openConnection() as HttpsURLConnection
                connection.requestMethod = "GET"
                connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
                connection.setRequestProperty("apikey", SupabaseClient.SUPABASE_ANON_KEY)
                connection.setRequestProperty("Content-Type", "application/json")
                FcmTokenManager.currentDeviceId()?.let { deviceId ->
                    connection.setRequestProperty("x-device-id", deviceId)
                }

                if (connection.responseCode == 200) {
                    val response = connection.inputStream.bufferedReader().readText()
                    val json = JSONObject(response)
                    if (json.optBoolean("success", false)) {
                        val devicesJson = json.optJSONArray("devices")
                        devices = buildList {
                            if (devicesJson != null) {
                                for (index in 0 until devicesJson.length()) {
                                    val item = devicesJson.optJSONObject(index) ?: continue
                                    add(
                                        DeviceDataAndroid(
                                            id = item.optString("id"),
                                            platform = item.optString("platform"),
                                            deviceType = item.optString("deviceType"),
                                            deviceName = item.optString("deviceName"),
                                            isPrimary = item.optBoolean("isPrimary", false),
                                            criticalAlertsEnabled = item.optBoolean("criticalAlertsEnabled", false),
                                            isActive = item.optBoolean("isActive", false),
                                            isCurrent = item.optBoolean("isCurrent", false),
                                            lastActiveAt = item.optString("lastActiveAt").takeIf { it.isNotBlank() }
                                        )
                                    )
                                }
                            }
                        }
                    } else {
                        error = json.optString("error", "Failed to load devices")
                    }
                } else {
                    error = "Server error: ${connection.responseCode}"
                }
                connection.disconnect()
            }
        } catch (e: Exception) {
            error = e.message
        }
        isLoading = false
    }
}

class BlockedContactsViewModelAndroid : androidx.lifecycle.ViewModel() {
    var blockedContacts by mutableStateOf<List<BlockedContactDataAndroid>>(emptyList())
        private set
    var isLoading by mutableStateOf(false)
        private set
    var error by mutableStateOf<String?>(null)
        private set

    suspend fun load(force: Boolean = false) {
        if (isLoading) return
        if (blockedContacts.isNotEmpty() && !force) return
        isLoading = true
        error = null
        try {
            val result = InviteRepository.getContacts()
            if (result.success) {
                blockedContacts = result.blockedContacts.map { it.toBlockedContact() }
            } else {
                error = result.error ?: "Failed to load blocked contacts"
            }
        } catch (e: Exception) {
            error = e.message
        }
        isLoading = false
    }

    suspend fun unblock(contact: BlockedContactDataAndroid) {
        val myId = SupabaseClient.getCurrentUserId() ?: run {
            error = "Not authenticated"
            return
        }
        val ok = InviteRepository.updateWakePermissionStatus(myId, contact.id, "active")
        if (ok) {
            blockedContacts = blockedContacts.filterNot { it.id == contact.id }
        } else {
            error = "Could not unblock contact."
        }
    }

    private fun ContactItem.toBlockedContact(): BlockedContactDataAndroid {
        val identifier = userId ?: id
        return BlockedContactDataAndroid(
            id = identifier,
            email = email,
            displayName = displayName.ifBlank { email.ifBlank { "Unknown" } }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onBack: () -> Unit = {},
    onNavigateToDiagnostics: () -> Unit = {},
    onSignOut: () -> Unit = {},
    currentTheme: AppTheme = AppTheme.LIGHT,
    onThemeChange: (AppTheme) -> Unit = {},
    useScaffold: Boolean = true,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    val profileViewModel = remember { ProfileViewModelAndroid() }
    val devicesViewModel = remember { DevicesViewModelAndroid() }
    val blockedContactsViewModel = remember { BlockedContactsViewModelAndroid() }
    val scope = rememberCoroutineScope()

    var selectedSoundId by remember {
        mutableStateOf(prefs.getString(KEY_ALARM_SOUND_ID, "classic") ?: "classic")
    }
    var showAlarmPicker by remember { mutableStateOf(false) }
    var showThemePicker by remember { mutableStateOf(false) }
    var showProfileEditor by remember { mutableStateOf(false) }
    var showBlockedContacts by remember { mutableStateOf(false) }
    var testAlarmPlaying by remember { mutableStateOf(false) }
    var audioError by remember { mutableStateOf<String?>(null) }
    var mediaPlayer by remember { mutableStateOf<MediaPlayer?>(null) }
    var biometricEnabled by remember { mutableStateOf(AndroidBiometricManager.isEnabled(context)) }
    val authViewModel: AuthViewModel = androidx.hilt.navigation.compose.hiltViewModel()

    // Load profile on first composition
    LaunchedEffect(Unit) {
        profileViewModel.load(force = true)
        devicesViewModel.load(force = true)
        blockedContactsViewModel.load(force = true)
    }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                scope.launch {
                    profileViewModel.load(force = true)
                    devicesViewModel.load(force = true)
                    blockedContactsViewModel.load(force = true)
                }
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    val selectedAlarm = AlarmSound.from(selectedSoundId)

    fun stopAlarm() {
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        testAlarmPlaying = false
        com.wakeupsunshine.data.DebugLogger.debug("AlarmSettings", "Alarm stopped")
    }

    fun testAlarm() {
        if (testAlarmPlaying) { stopAlarm(); return }

        testAlarmPlaying = true
        audioError = null
        com.wakeupsunshine.data.DebugLogger.debug("AlarmSettings", "Testing alarm id='$selectedSoundId'")

        val resourceId = context.resources.getIdentifier(selectedSoundId, "raw", context.packageName)

        if (resourceId == 0) {
            // classic or missing file — system fallback
            val msg = if (selectedAlarm == AlarmSound.CLASSIC)
                "Playing system sound (classic fallback)"
            else
                "'$selectedSoundId' not found in res/raw — falling back to system sound"
            android.util.Log.w("AlarmSettings", msg)
            if (selectedAlarm != AlarmSound.CLASSIC) audioError = msg

            try {
                val defaultUri = android.media.RingtoneManager.getDefaultUri(
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
                    setDataSource(context, defaultUri)
                    prepare()
                    start()
                }
            } catch (e: Exception) {
                android.util.Log.e("AlarmSettings", "System fallback failed: ${e.message}")
            }
        } else {
            val uri = Uri.parse("android.resource://${context.packageName}/$resourceId")
            com.wakeupsunshine.data.DebugLogger.debug("AlarmSettings", "Resolved asset: $selectedSoundId (id=$resourceId)")
            try {
                mediaPlayer = MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    setDataSource(context, uri)
                    prepare()
                    start()
                }
                com.wakeupsunshine.data.DebugLogger.debug("AlarmSettings", "Playback started ✓")
            } catch (e: Exception) {
                val msg = "Playback error for '$selectedSoundId': ${e.message}"
                android.util.Log.e("AlarmSettings", msg)
                audioError = msg
                testAlarmPlaying = false
                return
            }
        }

        // Auto-stop after 10 seconds
        scope.launch {
            delay(10_000)
            if (testAlarmPlaying) stopAlarm()
        }
    }

    DisposableEffect(Unit) {
        onDispose { stopAlarm() }
    }

    val settingsContent: @Composable (PaddingValues) -> Unit = { padding ->
        Column(
            modifier = modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(0.dp)
        ) {

            // PROFILE SECTION
            SettingsSectionHeader("Profile")
            ProfileRow(
                profile = profileViewModel.profile,
                isLoading = profileViewModel.isLoading,
                onClick = { showProfileEditor = true }
            )

            profileViewModel.error?.let { error ->
                Text(
                    text = error,
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.error
                )
            }

            SettingsSectionHeader("Devices")

            when {
                devicesViewModel.isLoading && devicesViewModel.devices.isEmpty() -> {
                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = MaterialTheme.colorScheme.surface,
                        tonalElevation = 1.dp,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(20.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            CircularProgressIndicator()
                        }
                    }
                }
                devicesViewModel.devices.isEmpty() -> {
                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = MaterialTheme.colorScheme.surface,
                        tonalElevation = 1.dp,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = "No registered devices yet",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            fontSize = 14.sp,
                            modifier = Modifier.padding(16.dp)
                        )
                    }
                }
                else -> {
                    devicesViewModel.devices.forEach { device ->
                        DeviceRow(device = device)
                    }
                }
            }

            devicesViewModel.error?.let { error ->
                Text(
                    text = error,
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.error
                )
            }

            // NOTIFICATIONS SECTION
            SettingsSectionHeader("Notifications")

            // Alarm Sound row
            SettingsRow(
                icon = Icons.Default.VolumeUp,
                iconTint = selectedAlarm.iconColor,
                title = "Alarm Sound",
                subtitle = selectedAlarm.displayName,
                onClick = {
                    com.wakeupsunshine.data.DebugLogger.debug("AlarmSettings", "Opening alarm picker")
                    showAlarmPicker = true
                }
            )

            // Test Alarm row
            val testIcon = if (testAlarmPlaying) Icons.Default.Stop else Icons.Default.PlayArrow
            val testTint = if (testAlarmPlaying) Red500 else MaterialTheme.colorScheme.primary
            SettingsRow(
                icon = testIcon,
                iconTint = testTint,
                title = if (testAlarmPlaying) "Stop Alarm" else "Test Alarm",
                subtitle = if (testAlarmPlaying) "Tap to stop"
                           else "Preview: ${selectedAlarm.displayName}",
                onClick = { testAlarm() }
            )

            // Error banner
            audioError?.let { error ->
                Surface(
                    color = MaterialTheme.colorScheme.errorContainer,
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            Icons.Default.Warning,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.error,
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = error,
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onErrorContainer,
                            modifier = Modifier.weight(1f)
                        )
                        TextButton(onClick = { audioError = null }) {
                            Text("Dismiss", fontSize = 12.sp)
                        }
                    }
                }
            }

            if (AndroidBiometricManager.canAuthenticate(context)) {
                SettingsSectionHeader("Security")

                SettingsRow(
                    icon = Icons.Default.Lock,
                    iconTint = MaterialTheme.colorScheme.primary,
                    title = AndroidBiometricManager.biometricTypeName(context),
                    subtitle = "Require biometric unlock to open the app",
                    onClick = {}
                )
                SwitchRow(
                    checked = biometricEnabled,
                    onCheckedChange = { enabled ->
                        val activity = context as? androidx.fragment.app.FragmentActivity
                        if (enabled && activity != null) {
                            scope.launch {
                                val ok = AndroidBiometricManager.authenticate(
                                    activity = activity,
                                    title = "Enable ${AndroidBiometricManager.biometricTypeName(context)}",
                                    subtitle = "Verify your identity to enable app unlock"
                                )
                                if (ok) {
                                    AndroidBiometricManager.setEnabled(context, true)
                                    biometricEnabled = true
                                } else {
                                    biometricEnabled = false
                                }
                            }
                        } else {
                            AndroidBiometricManager.setEnabled(context, false)
                            biometricEnabled = false
                        }
                    }
                )
            }
            
            // APPEARANCE SECTION
            SettingsSectionHeader("Appearance")
            
            SettingsRow(
                icon = Icons.Default.Palette,
                iconTint = MaterialTheme.colorScheme.primary,
                title = "App Theme",
                subtitle = currentTheme.displayName,
                onClick = { showThemePicker = true }
            )
            
            // PRIVACY SECTION
            SettingsSectionHeader("Privacy")
            
            SettingsRow(
                icon = Icons.Default.Block,
                iconTint = MaterialTheme.colorScheme.onSurfaceVariant,
                title = "Blocked Contacts",
                subtitle = "Manage blocked users",
                onClick = {
                    showBlockedContacts = true
                    scope.launch { blockedContactsViewModel.load(force = true) }
                }
            )

            SettingsSectionHeader("Developer")
            
            SettingsRow(
                icon = Icons.Default.BugReport,
                iconTint = Orange500,
                title = "Diagnostics",
                subtitle = "Debug logs and device info",
                onClick = onNavigateToDiagnostics
            )
            
            // ACCOUNT SECTION
            SettingsSectionHeader("Account")
            
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = MaterialTheme.colorScheme.surface,
                tonalElevation = 1.dp,
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .clickable { onSignOut() }
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .background(Red500.copy(alpha = 0.12f), RoundedCornerShape(8.dp)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Default.Logout,
                            contentDescription = null,
                            tint = Red500,
                            modifier = Modifier.size(22.dp)
                        )
                    }
                    Spacer(Modifier.width(12.dp))
                    Text(
                        text = "Log Out",
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 15.sp,
                        color = Red500
                    )
                }
            }

            // Delete Account
            var showDeleteDialog by remember { mutableStateOf(false) }
            var isDeletingAccount by remember { mutableStateOf(false) }
            var deleteError by remember { mutableStateOf<String?>(null) }

            Card(
                onClick = { showDeleteDialog = true },
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = Color.White),
                shape = RoundedCornerShape(12.dp),
                border = BorderStroke(1.dp, Red500.copy(alpha = 0.3f))
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .background(Red500.copy(alpha = 0.12f), RoundedCornerShape(8.dp)),
                        contentAlignment = Alignment.Center
                    ) {
                        if (isDeletingAccount) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(22.dp),
                                color = Red500,
                                strokeWidth = 2.dp
                            )
                        } else {
                            Icon(
                                Icons.Default.DeleteForever,
                                contentDescription = null,
                                tint = Red500,
                                modifier = Modifier.size(22.dp)
                            )
                        }
                    }
                    Spacer(Modifier.width(12.dp))
                    Text(
                        text = if (isDeletingAccount) "Deleting..." else "Delete Account",
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 15.sp,
                        color = Red500
                    )
                }
            }

            // Delete Account Confirmation Dialog
            if (showDeleteDialog) {
                AlertDialog(
                    onDismissRequest = {
                        if (!isDeletingAccount) showDeleteDialog = false
                    },
                    title = { Text("Delete Account") },
                    text = {
                        Column {
                            Text("This will permanently delete your account, all contacts, wake history, and device registrations. This action cannot be undone.")
                            deleteError?.let { err ->
                                Spacer(Modifier.height(8.dp))
                                Text(err, color = MaterialTheme.colorScheme.error, fontSize = 13.sp)
                            }
                        }
                    },
                    confirmButton = {
                        TextButton(
                            onClick = {
                                val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                                val network = cm.activeNetwork
                                val caps = cm.getNetworkCapabilities(network)
                                val offline = network == null || caps == null || !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                                if (offline) {
                                    deleteError = "Make sure your phone is connected to the internet before deleting your account"
                                    return@TextButton
                                }
                                isDeletingAccount = true
                                authViewModel.deleteAccount { success, err ->
                                    isDeletingAccount = false
                                    showDeleteDialog = false
                                    if (success) {
                                        onSignOut()
                                    }
                                }
                            },
                            enabled = !isDeletingAccount,
                            colors = ButtonDefaults.textButtonColors(contentColor = Red500)
                        ) {
                            if (isDeletingAccount) {
                                CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                            } else {
                                Text("Delete", fontWeight = FontWeight.Bold)
                            }
                        }
                    },
                    dismissButton = {
                        TextButton(
                            onClick = { showDeleteDialog = false },
                            enabled = !isDeletingAccount
                        ) {
                            Text("Cancel")
                        }
                    }
                )
            }
        }
    }

    if (useScaffold) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("Settings", fontWeight = FontWeight.Bold) },
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                        }
                    }
                )
            }
        ) { padding ->
            settingsContent(padding)
        }
    } else {
        settingsContent(PaddingValues())
    }

    // Alarm picker bottom sheet
    if (showAlarmPicker) {
        ModalBottomSheet(
            onDismissRequest = { showAlarmPicker = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ) {
            AlarmSoundPicker(
                contactName = "yourself",
                onSend = { sound ->
                    selectedSoundId = sound.id
                    prefs.edit().putString(KEY_ALARM_SOUND_ID, sound.id).apply()
                    com.wakeupsunshine.data.DebugLogger.debug("AlarmSettings", "Saved alarm: ${sound.id} (${sound.displayName})")
                    showAlarmPicker = false
                },
                onDismiss = { showAlarmPicker = false }
            )
        }
    }
    
    // Theme picker bottom sheet
    if (showThemePicker) {
        ModalBottomSheet(
            onDismissRequest = { showThemePicker = false },
            sheetState = rememberModalBottomSheetState()
        ) {
            ThemePickerContent(
                currentTheme = currentTheme,
                onThemeSelected = { theme ->
                    onThemeChange(theme)
                    showThemePicker = false
                }
            )
        }
    }

    if (showProfileEditor) {
        ProfileEditDialog(
            profile = profileViewModel.profile,
            isSaving = profileViewModel.isSaving,
            onDismiss = { showProfileEditor = false },
            onSave = { displayName, phoneNumber ->
                scope.launch {
                    profileViewModel.save(displayName, phoneNumber)
                    if (profileViewModel.error == null) {
                        showProfileEditor = false
                    }
                }
            }
        )
    }

    if (showBlockedContacts) {
        ModalBottomSheet(
            onDismissRequest = { showBlockedContacts = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ) {
            BlockedContactsSheet(
                blockedContacts = blockedContactsViewModel.blockedContacts,
                isLoading = blockedContactsViewModel.isLoading,
                error = blockedContactsViewModel.error,
                onRefresh = { scope.launch { blockedContactsViewModel.load(force = true) } },
                onUnblock = { contact ->
                    scope.launch { blockedContactsViewModel.unblock(contact) }
                }
            )
        }
    }
}

@Composable
private fun ThemePickerContent(
    currentTheme: AppTheme,
    onThemeSelected: (AppTheme) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .padding(bottom = 32.dp)
    ) {
        Text(
            text = "Choose Theme",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(bottom = 16.dp)
        )
        
        AppTheme.entries.forEach { theme ->
            val isSelected = currentTheme == theme
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 4.dp)
                    .clickable { onThemeSelected(theme) },
                shape = RoundedCornerShape(12.dp),
                color = if (isSelected) 
                    MaterialTheme.colorScheme.primaryContainer 
                else 
                    MaterialTheme.colorScheme.surface,
                tonalElevation = if (isSelected) 0.dp else 1.dp
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .background(
                                getThemeIconColor(theme).copy(alpha = 0.12f),
                                RoundedCornerShape(8.dp)
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = getThemeIcon(theme),
                            contentDescription = null,
                            tint = getThemeIconColor(theme),
                            modifier = Modifier.size(22.dp)
                        )
                    }
                    Spacer(Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = theme.displayName,
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 15.sp,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = theme.description,
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    if (isSelected) {
                        Icon(
                            Icons.Default.CheckCircle,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(24.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun getThemeIcon(theme: AppTheme): ImageVector {
    return when (theme) {
        AppTheme.LIGHT -> Icons.Default.LightMode
        AppTheme.DARK -> Icons.Default.DarkMode
        AppTheme.FUN -> Icons.Default.Favorite
        AppTheme.PROFESSIONAL -> Icons.Default.BusinessCenter
    }
}

@Composable
private fun getThemeIconColor(theme: AppTheme): androidx.compose.ui.graphics.Color {
    return when (theme) {
        AppTheme.LIGHT -> Orange500
        AppTheme.DARK -> androidx.compose.ui.graphics.Color(0xFF1C1B1F)
        AppTheme.FUN -> Pink500
        AppTheme.PROFESSIONAL -> ProfessionalBlue
    }
}

@Composable
private fun SettingsSectionHeader(title: String) {
    Text(
        text = title.uppercase(),
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        letterSpacing = 0.8.sp,
        modifier = Modifier.padding(top = 2.dp, bottom = 1.dp)
    )
}

@Composable
private fun SettingsRow(
    icon: ImageVector,
    iconTint: androidx.compose.ui.graphics.Color,
    title: String,
    subtitle: String,
    onClick: () -> Unit
) {
    val bgColor by animateColorAsState(
        targetValue = MaterialTheme.colorScheme.surface,
        label = "rowBg"
    )
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = bgColor,
        tonalElevation = 1.dp,
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .background(iconTint.copy(alpha = 0.12f), RoundedCornerShape(8.dp)),
                contentAlignment = Alignment.Center
            ) {
                Icon(icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(20.dp))
            }
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(title, fontWeight = FontWeight.SemiBold, fontSize = 15.sp,
                    color = MaterialTheme.colorScheme.onSurface)
                Text(subtitle, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Icon(Icons.Default.ChevronRight, contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun ProfileRow(
    profile: ProfileData?,
    isLoading: Boolean,
    onClick: () -> Unit
) {
    val initial = when {
        !profile?.displayName.isNullOrBlank() -> profile?.displayName?.take(1)?.uppercase() ?: "?"
        !profile?.email.isNullOrBlank() -> profile?.email?.take(1)?.uppercase() ?: "?"
        else -> "?"
    }
    val displayName = if (profile?.displayName.isNullOrEmpty()) {
        profile?.email ?: "—"
    } else {
        profile!!.displayName
    }
    val subtitle = if (profile?.phoneNumber.isNullOrEmpty()) {
        profile?.email ?: "—"
    } else {
        profile!!.phoneNumber
    }
    val avatarColor = parseProfileColor(profile?.avatarColor)
    
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 1.dp,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .background(avatarColor, RoundedCornerShape(24.dp)),
                contentAlignment = Alignment.Center
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        color = androidx.compose.ui.graphics.Color.White,
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp
                    )
                } else {
                    Text(
                        text = initial,
                        fontWeight = FontWeight.Bold,
                        fontSize = 18.sp,
                        color = androidx.compose.ui.graphics.Color.White
                    )
                }
            }
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                if (isLoading) {
                    Text(
                        text = "Loading...",
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 15.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                } else {
                    Text(
                        text = displayName,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 15.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = subtitle,
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            Icon(Icons.Default.ChevronRight, contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun DeviceRow(device: DeviceDataAndroid) {
    val icon = when (device.deviceType.lowercase()) {
        "ipad" -> Icons.Default.TabletMac
        "watch" -> Icons.Default.Watch
        "android" -> Icons.Default.Smartphone
        else -> Icons.Default.PhoneIphone
    }
    val status = remember(device.lastActiveAt, device.isActive, device.isCurrent) {
        deviceStatusText(device)
    }

    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 1.dp,
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .background(Orange500.copy(alpha = 0.12f), RoundedCornerShape(8.dp)),
                contentAlignment = Alignment.Center
            ) {
                Icon(icon, contentDescription = null, tint = Orange500, modifier = Modifier.size(22.dp))
            }
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = device.deviceName.ifBlank { "Unnamed device" },
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 15.sp,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    val statusColor = if (device.isCurrent) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                    Text(
                        text = status,
                        fontSize = 12.sp,
                        color = statusColor
                    )
                    if (device.isPrimary) {
                        Text(
                            text = "Primary",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    if (device.platform == "ios" && device.criticalAlertsEnabled) {
                        Text(
                            text = "Critical alerts on",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SwitchRow(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 1.dp,
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = if (checked) "Enabled" else "Disabled",
                fontSize = 14.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(1f)
            )
            Switch(
                checked = checked,
                onCheckedChange = onCheckedChange
            )
        }
    }
}

@Composable
private fun BlockedContactsSheet(
    blockedContacts: List<BlockedContactDataAndroid>,
    isLoading: Boolean,
    error: String?,
    onRefresh: () -> Unit,
    onUnblock: (BlockedContactDataAndroid) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .padding(bottom = 32.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Blocked Contacts",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )
            IconButton(onClick = onRefresh) {
                Icon(Icons.Default.Refresh, contentDescription = "Refresh blocked contacts")
            }
        }

        when {
            isLoading && blockedContacts.isEmpty() -> {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            }
            blockedContacts.isEmpty() -> {
                Text(
                    text = "No blocked contacts.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(vertical = 16.dp)
                )
            }
            else -> {
                blockedContacts.forEach { contact ->
                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = MaterialTheme.colorScheme.surface,
                        tonalElevation = 1.dp,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = contact.displayName,
                                    fontWeight = FontWeight.SemiBold,
                                    fontSize = 15.sp
                                )
                                if (contact.email.isNotBlank()) {
                                    Text(
                                        text = contact.email,
                                        fontSize = 12.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                            TextButton(onClick = { onUnblock(contact) }) {
                                Text("Unblock")
                            }
                        }
                    }
                }
            }
        }

        if (error != null) {
            Text(
                text = error,
                color = MaterialTheme.colorScheme.error,
                fontSize = 12.sp,
                modifier = Modifier.padding(top = 12.dp)
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ProfileEditDialog(
    profile: ProfileData?,
    isSaving: Boolean,
    onDismiss: () -> Unit,
    onSave: (String, String) -> Unit
) {
    var displayName by remember(profile?.displayName) { mutableStateOf(profile?.displayName.orEmpty()) }
    var phoneNumber by remember(profile?.phoneNumber) { mutableStateOf(profile?.phoneNumber.orEmpty()) }

    AlertDialog(
        onDismissRequest = { if (!isSaving) onDismiss() },
        title = { Text("Edit Profile") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = profile?.email.orEmpty(),
                    onValueChange = {},
                    label = { Text("Email") },
                    singleLine = true,
                    enabled = false,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = displayName,
                    onValueChange = { displayName = it },
                    label = { Text("Name or Nickname") },
                    singleLine = true,
                    enabled = !isSaving,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = phoneNumber,
                    onValueChange = { phoneNumber = it },
                    label = { Text("Phone Number") },
                    singleLine = true,
                    enabled = !isSaving,
                    keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = KeyboardType.Phone),
                    modifier = Modifier.fillMaxWidth()
                )
                Text(
                    text = "Email is tied to this account. Sign out to use a different email.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontSize = 12.sp
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = { onSave(displayName, phoneNumber) },
                enabled = !isSaving && displayName.trim().isNotEmpty()
            ) {
                Text(if (isSaving) "Saving..." else "Save")
            }
        },
        dismissButton = {
            TextButton(
                onClick = onDismiss,
                enabled = !isSaving
            ) {
                Text("Cancel")
            }
        }
    )
}

private fun parseProfileColor(raw: String?): androidx.compose.ui.graphics.Color {
    val value = raw?.removePrefix("#")?.takeIf { it.length == 6 } ?: return Orange500
    return try {
        androidx.compose.ui.graphics.Color(android.graphics.Color.parseColor("#$value"))
    } catch (_: IllegalArgumentException) {
        Orange500
    }
}

private fun deviceStatusText(device: DeviceDataAndroid): String {
    if (device.isCurrent) return "This device"
    val raw = device.lastActiveAt ?: return "Registered device"
    val parsed = try {
        OffsetDateTime.parse(raw)
    } catch (_: Exception) {
        null
    } ?: return "Registered device"

    val duration = Duration.between(parsed.toInstant(), java.time.Instant.now())
    val minutes = duration.toMinutes()
    return when {
        minutes < 15 -> "Active recently"
        minutes < 60 -> "Last active ${minutes} min ago"
        minutes < 24 * 60 -> "Last active ${duration.toHours()} hr ago"
        else -> "Last active ${duration.toDays()} d ago"
    }
}
