package com.wakeupsunshine.ui

import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.viewmodel.compose.viewModel
import com.wakeupsunshine.data.AndroidBiometricManager
import com.google.firebase.messaging.FirebaseMessaging
import com.wakeupsunshine.data.ContactsRefreshSignal
import com.wakeupsunshine.data.DebugLogger
import com.wakeupsunshine.data.FcmTokenManager
import com.wakeupsunshine.data.InviteRepository
import com.wakeupsunshine.data.SupabaseClient
import com.wakeupsunshine.ui.auth.*
import com.wakeupsunshine.ui.home.HomeScreen
import com.wakeupsunshine.ui.settings.DiagnosticsScreen
import com.wakeupsunshine.ui.settings.SettingsScreen
import com.wakeupsunshine.ui.theme.AppTheme
import com.wakeupsunshine.ui.theme.ThemeManager
import com.wakeupsunshine.ui.theme.WakeUpSunshineTheme
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    private val tag = "MainActivity"

    // Survives recomposition; updated by onNewIntent when app is already running
    private var pendingInviteToken by mutableStateOf<String?>(null)
    private var pendingAuthCallback by mutableStateOf<Pair<String, String>?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        fetchAndRegisterFcmToken()
        requestCriticalPermissions()
        pendingInviteToken = extractInviteToken(intent)
        pendingAuthCallback = extractAuthCallback(intent)

        setContent {
            val savedTheme = ThemeManager.getSavedTheme(this)
            var appTheme by remember { mutableStateOf(savedTheme) }

            WakeUpSunshineTheme(appTheme = appTheme) {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    val authViewModel: AuthViewModel = viewModel()
                    val authState by authViewModel.authState.collectAsState()

                    // Consume auth callback tokens (email verification / password reset)
                    LaunchedEffect(pendingAuthCallback) {
                        pendingAuthCallback?.let { (accessToken, refreshToken) ->
                            pendingAuthCallback = null
                            authViewModel.handleAuthCallback(accessToken, refreshToken)
                        }
                    }

                    WakeUpSunshineNavigation(
                        authState = authState,
                        authViewModel = authViewModel,
                        currentTheme = appTheme,
                        onThemeChange = { newTheme ->
                            appTheme = newTheme
                            ThemeManager.saveTheme(this, newTheme)
                        },
                        pendingInviteToken = pendingInviteToken,
                        onInviteTokenConsumed = { pendingInviteToken = null }
                    )
                }
            }
        }
    }

    // Called when the app is already running (singleTop) and a new deep link arrives
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingInviteToken = extractInviteToken(intent)
        pendingAuthCallback = extractAuthCallback(intent)
    }

    private fun extractInviteToken(intent: Intent?): String? {
        val data = intent?.data ?: return null
        return when {
            data.scheme == "wakeupsunshine" && data.host == "invite" ->
                data.pathSegments.firstOrNull()?.takeIf { it.isNotEmpty() }
            data.scheme == "https" &&
                (data.host == "wakemeup.app" || data.host == "wakeupsunshine.app") &&
                data.pathSegments.firstOrNull() == "invite" ->
                data.pathSegments.getOrNull(1)?.takeIf { it.isNotEmpty() }
            else -> null
        }
    }

    private fun extractAuthCallback(intent: Intent?): Pair<String, String>? {
        val uri = intent?.data ?: return null
        if (uri.scheme != "wakeupsunshine") return null
        val fragment = uri.fragment ?: return null
        val params = fragment.split("&").associate { part ->
            val kv = part.split("=", limit = 2)
            kv[0] to (kv.getOrElse(1) { "" })
        }
        val accessToken = params["access_token"]?.takeIf { it.isNotEmpty() } ?: return null
        val refreshToken = params["refresh_token"]?.takeIf { it.isNotEmpty() } ?: return null
        return Pair(accessToken, refreshToken)
    }
    
    private fun requestCriticalPermissions() {
        // POST_NOTIFICATIONS runtime permission (Android 13+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 100)
            }
        }

        // USE_FULL_SCREEN_INTENT special permission (Android 14+)
        // Without this, full-screen alarm intent silently degrades to a banner notification.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val nm = getSystemService(NotificationManager::class.java)
            if (!nm.canUseFullScreenIntent()) {
                Log.w(tag, "USE_FULL_SCREEN_INTENT not granted — sending user to settings")
                startActivity(
                    Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                           Uri.parse("package:$packageName"))
                )
            }
        }

        // Battery optimization exemption — prevents Samsung from killing the app
        // and dropping data-only FCM messages while backgrounded.
        val pm = getSystemService(PowerManager::class.java)
        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
            startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                       Uri.parse("package:$packageName"))
            )
        }
    }

    private fun fetchAndRegisterFcmToken() {
        DebugLogger.debug(tag, "fetchAndRegisterFcmToken: Starting FCM token fetch")
        
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            if (!task.isSuccessful) {
                Log.e(tag, "Failed to get FCM token", task.exception)
                DebugLogger.log("fcm_token_failed", "Failed to get FCM token: ${task.exception?.message}")
                return@addOnCompleteListener
            }
            
            val token = task.result
            if (token != null) {
                DebugLogger.debug(tag, "FCM token received: ${token.take(8)}...${token.takeLast(6)}")
                
                // Store in FcmTokenManager
                FcmTokenManager.token = token
                
                // Log token received
                DebugLogger.logFCMTokenReceived(token)
                
                // Register with backend if session exists
                registerTokenWithBackend(token)
            } else {
                Log.e(tag, "FCM token is null")
            }
        }
    }
    
    private fun registerTokenWithBackend(token: String) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val session = SupabaseClient.getValidSession()
                if (session == null) {
                    DebugLogger.debug(tag, "No session, caching token for later registration")
                    FcmTokenManager.pendingRegistration = true
                    return@launch
                }
                
                DebugLogger.logDeviceTokenRegisterStart(token)
                val result = SupabaseClient.registerCurrentAndroidDevice(token)
                result.onSuccess { deviceId ->
                    DebugLogger.debug(tag, "Token registered successfully: deviceId=$deviceId")
                    DebugLogger.logDeviceTokenRegisterSuccess(deviceId)
                }.onFailure { error ->
                    Log.e(tag, "Failed to register token: ${error.message}")
                    DebugLogger.logDeviceTokenRegisterFailure(error.message ?: "Unknown error")
                }
            } catch (e: Exception) {
                Log.e(tag, "Error registering token", e)
                DebugLogger.logDeviceTokenRegisterFailure(e.message ?: "Unknown error")
            }
        }
    }
}

sealed class Screen {
    object Welcome : Screen()
    object EmailAuth : Screen()
    object Home : Screen()
    object Settings : Screen()
    object Diagnostics : Screen()
}

@Composable
private fun BiometricLockScreen(
    activity: FragmentActivity,
    onUnlocked: () -> Unit,
    onSignOut: () -> Unit
) {
    var authenticating by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    fun startAuth() {
        if (authenticating) return
        authenticating = true
        error = null
        scope.launch {
            val ok = AndroidBiometricManager.authenticate(
                activity = activity,
                title = "Unlock Wake Up Sunshine",
                subtitle = "Use your biometric to continue"
            )
            authenticating = false
            if (ok) {
                onUnlocked()
            } else {
                error = "Biometric authentication failed."
            }
        }
    }

    LaunchedEffect(Unit) {
        startAuth()
    }

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Box(
                modifier = Modifier
                    .size(120.dp)
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f), shape = MaterialTheme.shapes.extraLarge),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "🔒",
                    fontSize = 40.sp
                )
            }
            Spacer(Modifier.height(24.dp))
            Text(
                text = "Wake Up Sunshine",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = "Unlock with ${AndroidBiometricManager.biometricTypeName(activity)}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center
            )
            if (error != null) {
                Spacer(Modifier.height(16.dp))
                Text(
                    text = error!!,
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall,
                    textAlign = TextAlign.Center
                )
            }
            Spacer(Modifier.height(24.dp))
            Button(
                onClick = { startAuth() },
                enabled = !authenticating
            ) {
                if (authenticating) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        strokeWidth = 2.dp,
                        color = Color.White
                    )
                } else {
                    Text("Unlock")
                }
            }
            Spacer(Modifier.height(12.dp))
            TextButton(onClick = onSignOut) {
                Text("Sign Out")
            }
        }
    }
}

@Composable
fun WakeUpSunshineNavigation(
    authState: AuthState,
    authViewModel: AuthViewModel,
    currentTheme: AppTheme = AppTheme.LIGHT,
    onThemeChange: (AppTheme) -> Unit = {},
    pendingInviteToken: String? = null,
    onInviteTokenConsumed: () -> Unit = {}
) {
    val context = LocalContext.current
    val activity = context as? FragmentActivity
    var currentScreen by remember { mutableStateOf<Screen>(Screen.Welcome) }
    var requiresBiometricUnlock by remember { mutableStateOf(false) }

    // Invite acceptance state
    var inviteDialogTitle by remember { mutableStateOf("") }
    var inviteDialogMessage by remember { mutableStateOf("") }
    var showInviteDialog by remember { mutableStateOf(false) }
    var acceptingInvite by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    // If authenticated, go to Home
    LaunchedEffect(authState) {
        if (authState is AuthState.Authenticated) {
            requiresBiometricUnlock =
                AndroidBiometricManager.isEnabled(context) &&
                AndroidBiometricManager.canAuthenticate(context)
            if (!requiresBiometricUnlock) {
                currentScreen = Screen.Home
            }
        } else {
            requiresBiometricUnlock = false
        }
    }

    // Process pending invite token once user is authenticated
    LaunchedEffect(pendingInviteToken, authState) {
        if (pendingInviteToken != null && authState is AuthState.Authenticated) {
            val token = pendingInviteToken
            onInviteTokenConsumed()
            acceptingInvite = true
            inviteDialogTitle = "Accepting Invite…"
            inviteDialogMessage = ""
            showInviteDialog = true
            scope.launch(Dispatchers.IO) {
                val result = InviteRepository.acceptInviteByToken(token)
                kotlinx.coroutines.withContext(Dispatchers.Main) {
                    acceptingInvite = false
                    if (result.success) {
                        ContactsRefreshSignal.emit()
                        inviteDialogTitle = "Invite Accepted!"
                        inviteDialogMessage = "You are now connected. You'll see each other in your contacts."
                    } else {
                        inviteDialogTitle = "Invite Failed"
                        inviteDialogMessage = result.error
                            ?: "The invite may have expired or already been used."
                    }
                }
            }
        }
    }

    if (showInviteDialog) {
        AlertDialog(
            onDismissRequest = { if (!acceptingInvite) showInviteDialog = false },
            title = { Text(inviteDialogTitle) },
            text = {
                if (acceptingInvite) {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            strokeWidth = 2.dp
                        )
                        Text("Please wait…")
                    }
                } else {
                    Text(inviteDialogMessage, textAlign = TextAlign.Start)
                }
            },
            confirmButton = {
                if (!acceptingInvite) {
                    TextButton(onClick = { showInviteDialog = false }) {
                        Text("OK")
                    }
                }
            }
        )
    }

    if (authState is AuthState.Authenticated && requiresBiometricUnlock && activity != null) {
        BiometricLockScreen(
            activity = activity,
            onUnlocked = {
                requiresBiometricUnlock = false
                currentScreen = Screen.Home
            },
            onSignOut = { authViewModel.signOut() }
        )
        return
    }

    when (currentScreen) {
        Screen.Welcome -> {
            WelcomeScreen(
                onEmailClick = { currentScreen = Screen.EmailAuth }
            )
        }
        Screen.EmailAuth -> {
            EmailAuthScreen(
                onSuccess = { currentScreen = Screen.Home },
                onBack = { currentScreen = Screen.Welcome }
            )
        }
        Screen.Home -> {
            HomeScreen(
                onNavigateToSettings = { currentScreen = Screen.Settings },
                onSignOut = {
                    authViewModel.signOut()
                    currentScreen = Screen.Welcome
                },
                currentTheme = currentTheme,
                onThemeChange = onThemeChange
            )
        }
        Screen.Settings -> {
            SettingsScreen(
                onBack = { currentScreen = Screen.Home },
                onNavigateToDiagnostics = { currentScreen = Screen.Diagnostics },
                onSignOut = {
                    authViewModel.signOut()
                    currentScreen = Screen.Welcome
                },
                currentTheme = currentTheme,
                onThemeChange = onThemeChange
            )
        }
        Screen.Diagnostics -> {
            DiagnosticsScreen(onNavigateBack = { currentScreen = Screen.Settings })
        }
    }
}
