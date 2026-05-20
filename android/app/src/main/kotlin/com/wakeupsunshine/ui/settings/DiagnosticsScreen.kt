package com.wakeupsunshine.ui.settings

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.widget.Toast
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.wakeupsunshine.data.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.time.Duration
import java.time.OffsetDateTime
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DiagnosticsScreen(
    onNavigateBack: () -> Unit = {}
) {
    val viewModel: DiagnosticsViewModel = viewModel()
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val snackbarHostState = remember { SnackbarHostState() }
    
    LaunchedEffect(Unit) {
        viewModel.loadDiagnostics(context)
    }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Diagnostics") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // User Info Section
            item {
                DiagnosticSection(title = "User Info") {
                    DiagnosticItem(label = "User ID", value = viewModel.userId)
                    DiagnosticItem(label = "Email", value = viewModel.userEmail)
                    DiagnosticItem(label = "Session Exists", value = if (viewModel.sessionExists) "Yes" else "No")
                }
            }
            
            // Push Notification Section
            item {
                DiagnosticSection(title = "Push Notifications") {
                    DiagnosticItem(label = "FCM Token Registered", value = if (viewModel.fcmTokenRegistered) "Yes" else "No")
                    if (viewModel.fcmTokenPrefix != null && viewModel.fcmTokenSuffix != null) {
                        DiagnosticItem(label = "Token", value = "${viewModel.fcmTokenPrefix}...${viewModel.fcmTokenSuffix}")
                    }
                    if (viewModel.backendDeviceId != null) {
                        DiagnosticItem(label = "Backend Device ID", value = viewModel.backendDeviceId!!)
                    }
                    DiagnosticItem(label = "Notification Permission", value = viewModel.notificationPermissionStatus)
                }
            }

            item {
                DiagnosticSection(title = "Registered Devices") {
                    DiagnosticItem(label = "Count", value = viewModel.registeredDevices.size.toString())
                    if (viewModel.registeredDevices.isEmpty()) {
                        Text(
                            text = "No registered devices found for this account",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            fontSize = 14.sp
                        )
                    } else {
                        viewModel.registeredDevices.forEach { device ->
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 4.dp)
                            ) {
                                Text(
                                    text = device.deviceName.ifBlank { "Unnamed device" },
                                    fontSize = 14.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                Text(
                                    text = viewModel.deviceSummary(device),
                                    fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                    viewModel.deviceError?.let { error ->
                        Text(
                            text = error,
                            color = MaterialTheme.colorScheme.error,
                            fontSize = 12.sp
                        )
                    }
                }
            }
            
            // Contacts Section
            item {
                DiagnosticSection(title = "Contacts") {
                    DiagnosticItem(label = "People I Can Wake", value = viewModel.peopleICanWakeCount.toString())
                    DiagnosticItem(label = "People Who Can Wake Me", value = viewModel.peopleWhoCanWakeMeCount.toString())
                    DiagnosticItem(label = "Pending Invites Sent", value = viewModel.pendingSentCount.toString())
                    DiagnosticItem(label = "Pending Invites Received", value = viewModel.pendingReceivedCount.toString())
                }
            }
            
            // Last Wake Section
            item {
                DiagnosticSection(title = "Last Wake Request") {
                    if (DebugLogger.lastWakeTraceId != null) {
                        DiagnosticItem(label = "Trace ID", value = DebugLogger.lastWakeTraceId ?: "N/A")
                    } else {
                        Text(
                            text = "No wake request sent",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            fontSize = 14.sp
                        )
                    }
                    
                    DebugLogger.lastWakeResponse?.let { response ->
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "Response:",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = formatMap(response),
                            fontSize = 12.sp,
                            fontFamily = FontFamily.Monospace,
                            modifier = Modifier
                                .background(
                                    MaterialTheme.colorScheme.surfaceVariant,
                                    RoundedCornerShape(4.dp)
                                )
                                .padding(8.dp)
                        )
                    }
                }
            }
            
            // Last Notification Section
            item {
                DiagnosticSection(title = "Last FCM Message") {
                    if (DebugLogger.lastNotificationPayload != null) {
                        Text(
                            text = "Payload:",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = formatMap(DebugLogger.lastNotificationPayload ?: emptyMap<String, Any?>()),
                            fontSize = 12.sp,
                            fontFamily = FontFamily.Monospace,
                            modifier = Modifier
                                .background(
                                    MaterialTheme.colorScheme.surfaceVariant,
                                    RoundedCornerShape(4.dp)
                                )
                                .padding(8.dp)
                        )
                    } else {
                        Text(
                            text = "No FCM message received",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            fontSize = 14.sp
                        )
                    }
                    
                    DebugLogger.lastAlarmTriggeredAt?.let { timestamp ->
                        val sdf = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
                        DiagnosticItem(label = "Last Alarm Triggered", value = sdf.format(Date(timestamp)))
                    }
                }
            }
            
            // Actions Section
            item {
                DiagnosticSection(title = "Actions") {
                    DiagnosticButton(
                        text = "Refresh Contacts",
                        icon = Icons.Default.Refresh,
                        onClick = { scope.launch { viewModel.refreshContacts() } }
                    )
                    DiagnosticButton(
                        text = "Refresh Registered Devices",
                        icon = Icons.Default.Devices,
                        onClick = { scope.launch { viewModel.refreshDevices() } }
                    )
                    DiagnosticButton(
                        text = "Register FCM Token Again",
                        icon = Icons.Default.Notifications,
                        onClick = { scope.launch { viewModel.registerPushToken() } }
                    )
                    DiagnosticButton(
                        text = "Send Test Debug Event",
                        icon = Icons.Default.BugReport,
                        onClick = {
                            viewModel.sendTestDebugEvent()
                            Toast.makeText(context, "Test event logged", Toast.LENGTH_SHORT).show()
                        }
                    )
                    DiagnosticButton(
                        text = "Simulate Incoming Wake",
                        icon = Icons.Default.Alarm,
                        onClick = { viewModel.simulateIncomingWake() }
                    )
                    DiagnosticButton(
                        text = "Clear Local Debug Logs",
                        icon = Icons.Default.Delete,
                        onClick = {
                            DebugLogger.clearEvents()
                            Toast.makeText(context, "Logs cleared", Toast.LENGTH_SHORT).show()
                        },
                        isDestructive = true
                    )
                    DiagnosticButton(
                        text = "Copy Diagnostics to Clipboard",
                        icon = Icons.Default.ContentCopy,
                        onClick = {
                            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                            val clip = ClipData.newPlainText("Diagnostics", viewModel.exportDiagnostics())
                            clipboard.setPrimaryClip(clip)
                            Toast.makeText(context, "Diagnostics copied to clipboard", Toast.LENGTH_SHORT).show()
                        }
                    )
                }
            }
            
            // Debug Log Section
            item {
                DiagnosticSection(title = "Debug Log (last ${DebugLogger.getEvents().size})") {
                    DebugLogger.getEvents().take(20).forEach { event ->
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 4.dp)
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(
                                    text = event.eventType,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.primary
                                )
                                Text(
                                    text = formatTime(event.timestamp),
                                    fontSize = 10.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            Text(
                                text = event.message,
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            if (event.metadata.isNotEmpty()) {
                                Text(
                                    text = event.metadata.entries.joinToString(", ") { "${it.key}: ${it.value}" },
                                    fontSize = 10.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun DiagnosticSection(
    title: String,
    content: @Composable ColumnScope.() -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Text(
                text = title,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary
            )
            Spacer(modifier = Modifier.height(12.dp))
            content()
        }
    }
}

@Composable
fun DiagnosticItem(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = label,
            fontSize = 14.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            text = value,
            fontSize = 14.sp,
            color = MaterialTheme.colorScheme.onSurface
        )
    }
}

@Composable
fun DiagnosticButton(
    text: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    onClick: () -> Unit,
    isDestructive: Boolean = false
) {
    Button(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        colors = if (isDestructive) {
            ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
        } else {
            ButtonDefaults.buttonColors()
        }
    ) {
        Icon(icon, contentDescription = null, modifier = Modifier.size(18.dp))
        Spacer(modifier = Modifier.width(8.dp))
        Text(text)
    }
}

fun formatTime(timestamp: Long): String {
    val sdf = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
    return sdf.format(Date(timestamp))
}

fun formatMap(map: Map<*, *>): String {
    return map.entries.joinToString("\n") { "  ${it.key}: ${it.value}" }
}

class DiagnosticsViewModel : ViewModel() {
    data class RegisteredDevice(
        val id: String,
        val platform: String,
        val deviceName: String,
        val isCurrent: Boolean,
        val isPrimary: Boolean,
        val isActive: Boolean,
        val lastActiveAt: String?
    )

    var userId by mutableStateOf("Not loaded")
        private set
    var userEmail by mutableStateOf("Not loaded")
        private set
    var sessionExists by mutableStateOf(false)
        private set
    var fcmTokenRegistered by mutableStateOf(false)
        private set
    var fcmTokenPrefix by mutableStateOf<String?>(null)
        private set
    var fcmTokenSuffix by mutableStateOf<String?>(null)
        private set
    var backendDeviceId by mutableStateOf<String?>(null)
        private set
    var notificationPermissionStatus by mutableStateOf("Unknown")
        private set
    var registeredDevices by mutableStateOf<List<RegisteredDevice>>(emptyList())
        private set
    var deviceError by mutableStateOf<String?>(null)
        private set
    var peopleICanWakeCount by mutableStateOf(0)
        private set
    var peopleWhoCanWakeMeCount by mutableStateOf(0)
        private set
    var pendingSentCount by mutableStateOf(0)
        private set
    var pendingReceivedCount by mutableStateOf(0)
        private set
    
    private val client = OkHttpClient()
    fun loadDiagnostics(context: Context) {
        // Load auth info
        SupabaseClient.session?.let { session ->
            userId = session.userId
            userEmail = session.email ?: "No email"
            sessionExists = true
        }
        
        // Load FCM token info
        FcmTokenManager.token?.let { token ->
            fcmTokenRegistered = true
            fcmTokenPrefix = token.take(8)
            fcmTokenSuffix = token.takeLast(6)
        }
        backendDeviceId = FcmTokenManager.deviceId
        
        // Check notification permission status
        notificationPermissionStatus = checkNotificationPermissionStatus(context)
        
        // Load contacts asynchronously
        viewModelScope.launch {
            refreshContacts()
            refreshDevices()
        }
    }
    
    private fun checkNotificationPermissionStatus(context: Context): String {
        return try {
            // Check if notifications are enabled
            val notificationManager = NotificationManagerCompat.from(context)
            val areNotificationsEnabled = notificationManager.areNotificationsEnabled()
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // Android 13+ requires POST_NOTIFICATIONS runtime permission
                val permissionStatus = ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.POST_NOTIFICATIONS
                )
                
                when {
                    permissionStatus == PackageManager.PERMISSION_GRANTED -> "Granted"
                    areNotificationsEnabled -> "Granted (via settings)"
                    else -> "Denied"
                }
            } else {
                // Below Android 13, notifications are enabled by default if the app allows
                if (areNotificationsEnabled) "Not required" else "Disabled"
            }
        } catch (e: Exception) {
            DebugLogger.logError(e, "Failed to check notification permission")
            "Unknown"
        }
    }
    
    suspend fun refreshContacts() {
        DebugLogger.logContactsRefreshStart()
        
        try {
            val result = InviteRepository.getContacts()
            peopleICanWakeCount = result.peopleICanWake.size
            peopleWhoCanWakeMeCount = result.peopleWhoCanWakeMe.size
            pendingSentCount = result.pendingInvitesSent.size
            pendingReceivedCount = result.pendingInvitesReceived.size
            
            DebugLogger.logContactsRefreshComplete(
                peopleICanWake = peopleICanWakeCount,
                peopleWhoCanWakeMe = peopleWhoCanWakeMeCount,
                pendingSent = pendingSentCount,
                pendingReceived = pendingReceivedCount
            )
        } catch (e: Exception) {
            DebugLogger.logError(e, "Failed to refresh contacts")
        }
    }
    
    suspend fun registerPushToken() {
        val token = FcmTokenManager.token
        if (token == null) {
            DebugLogger.log("push_token_register_failed", "No FCM token available")
            return
        }
        
        DebugLogger.logDeviceTokenRegisterStart(token)
        
        try {
            val result = SupabaseClient.registerCurrentAndroidDevice(token)
            result.onSuccess { deviceId ->
                fcmTokenRegistered = true
                backendDeviceId = deviceId.ifBlank { null }
                DebugLogger.logDeviceTokenRegisterSuccess(deviceId)
            }.onFailure { error ->
                throw error
            }
            refreshDevices()
        } catch (e: Exception) {
            DebugLogger.logDeviceTokenRegisterFailure(e.message ?: "Unknown error")
        }
    }

    suspend fun refreshDevices() {
        deviceError = null
        try {
            val session = SupabaseClient.getValidSession() ?: throw Exception("Not authenticated")

            val request = Request.Builder()
                .url("${SupabaseClient.SUPABASE_URL}/functions/v1/get-devices")
                .addHeader("Content-Type", "application/json")
                .addHeader("apikey", SupabaseClient.SUPABASE_ANON_KEY)
                .addHeader("Authorization", "Bearer ${session.accessToken}")
                .apply {
                    FcmTokenManager.currentDeviceId()?.let { addHeader("x-device-id", it) }
                }
                .get()
                .build()

            val response = withContext(Dispatchers.IO) { client.newCall(request).execute() }
            if (!response.isSuccessful) {
                val errorBody = response.body?.string() ?: "Unknown error"
                throw Exception("Failed to load devices: $errorBody")
            }

            val json = JSONObject(response.body?.string() ?: "{}")
            if (!json.optBoolean("success", false)) {
                throw Exception(json.optString("error", "Failed to load devices"))
            }

            val devicesJson = json.optJSONArray("devices")
            registeredDevices = buildList {
                if (devicesJson != null) {
                    for (index in 0 until devicesJson.length()) {
                        val item = devicesJson.optJSONObject(index) ?: continue
                        add(
                            RegisteredDevice(
                                id = item.optString("id"),
                                platform = item.optString("platform"),
                                deviceName = item.optString("deviceName"),
                                isCurrent = item.optBoolean("isCurrent", false),
                                isPrimary = item.optBoolean("isPrimary", false),
                                isActive = item.optBoolean("isActive", false),
                                lastActiveAt = item.optString("lastActiveAt").takeIf { it.isNotBlank() }
                            )
                        )
                    }
                }
            }
        } catch (e: Exception) {
            deviceError = e.message ?: "Unknown error"
        }
    }
    
    fun sendTestDebugEvent() {
        DebugLogger.log(
            eventType = "test_event",
            message = "Test debug event from Android app",
            metadata = mapOf("source" to "diagnostics_button")
        )
    }
    
    fun simulateIncomingWake() {
        DebugLogger.logFCMMessageReceived(
            payload = mapOf(
                "request_id" to UUID.randomUUID().toString(),
                "sender_name" to "Test User",
                "message" to "This is a simulated wake alert",
                "alarm_sound_id" to "classic"
            ),
            inForeground = true
        )
    }
    
    fun exportDiagnostics(): String {
        var export = DebugLogger.exportDiagnostics()
        
        export += "\n--- Device Info ---\n"
        export += "Platform: Android\n"
        export += "User ID: $userId\n"
        export += "Email: $userEmail\n"
        export += "Session Exists: $sessionExists\n"
        export += "FCM Token Registered: $fcmTokenRegistered\n"
        if (fcmTokenPrefix != null && fcmTokenSuffix != null) {
            export += "FCM Token: $fcmTokenPrefix...$fcmTokenSuffix\n"
        }
        if (backendDeviceId != null) {
            export += "Backend Device ID: $backendDeviceId\n"
        }
        export += "Registered Devices: ${registeredDevices.size}\n"
        registeredDevices.forEach { device ->
            export += "- ${device.deviceName} [${device.platform}] current=${device.isCurrent} active=${device.isActive}\n"
        }
        export += "Notification Permission: $notificationPermissionStatus\n"
        export += "People I Can Wake: $peopleICanWakeCount\n"
        export += "People Who Can Wake Me: $peopleWhoCanWakeMeCount\n"
        export += "Pending Sent: $pendingSentCount\n"
        export += "Pending Received: $pendingReceivedCount\n"
        
        return export
    }
    
    fun deviceSummary(device: RegisteredDevice): String {
        val base = when {
            device.isCurrent -> "This device"
            device.isActive && device.lastActiveAt != null -> "Active recently"
            device.lastActiveAt != null -> "Last active ${relativeTime(device.lastActiveAt)}"
            else -> device.platform.uppercase()
        }
        val suffix = buildList {
            if (device.isPrimary) add("Primary")
            add(if (device.isActive) "Active" else "Inactive")
        }.joinToString(" • ")
        return "$base • $suffix"
    }

    private fun relativeTime(raw: String?): String {
        val parsed = raw?.let {
            try {
                OffsetDateTime.parse(it)
            } catch (_: Exception) {
                null
            }
        } ?: return "unknown"

        val duration = Duration.between(parsed.toInstant(), java.time.Instant.now())
        val minutes = duration.toMinutes()
        return when {
            minutes < 60 -> "${minutes} min ago"
            minutes < 24 * 60 -> "${duration.toHours()} hr ago"
            else -> "${duration.toDays()} d ago"
        }
    }
}
