package com.wakeupsunshine.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.wakeupsunshine.data.AlarmSound
import com.wakeupsunshine.data.ContactsRefreshSignal
import com.wakeupsunshine.data.ContactItem
import com.wakeupsunshine.data.DebugLogger
import com.wakeupsunshine.data.HistoryRefreshSignal
import com.wakeupsunshine.data.InviteItem
import com.wakeupsunshine.data.InviteRepository
import com.wakeupsunshine.data.SupabaseClient
import com.wakeupsunshine.data.WakeResponseSignal
import com.wakeupsunshine.ui.alarm.AlarmSoundPicker
import com.wakeupsunshine.ui.contacts.InviteContactDialog
import com.wakeupsunshine.ui.history.HistoryScreen
import com.wakeupsunshine.ui.settings.SettingsScreen
import com.wakeupsunshine.ui.theme.*
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import kotlinx.coroutines.delay
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

data class Contact(
    val id: String,
    val displayName: String,
    val email: String = "",
    val avatarColor: Color,
    val isOnline: Boolean = false
)

private fun avatarColorFromString(s: String): Color {
    val palette = listOf(
        Color(0xFF667eea), Color(0xFFf5576c), Color(0xFF4facfe),
        Color(0xFF43e97b), Color(0xFFfa709a), Color(0xFF30cfd0),
        Color(0xFFa18cd1), Color(0xFFffecd2)
    )
    return palette[Math.abs(s.hashCode()) % palette.size]
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onNavigateToSettings: () -> Unit = {},
    onSignOut: () -> Unit = {},
    currentTheme: AppTheme = AppTheme.LIGHT,
    onThemeChange: (AppTheme) -> Unit = {}
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val scope = rememberCoroutineScope()
    var selectedTab by remember { mutableStateOf(0) }
    var showAlarmPicker by remember { mutableStateOf(false) }
    var selectedContact by remember { mutableStateOf<Contact?>(null) }
    var showWakeConfirmation by remember { mutableStateOf(false) }
    var lastWakedContact by remember { mutableStateOf<Contact?>(null) }
    var showInviteDialog by remember { mutableStateOf(false) }
    var isSendingWake by remember { mutableStateOf(false) }
    var editingNicknameContact by remember { mutableStateOf<Contact?>(null) }
    var editNicknameText by remember { mutableStateOf("") }
    var wakeError by remember { mutableStateOf<String?>(null) }
    var wakeResponseEvent by remember { mutableStateOf<com.wakeupsunshine.data.WakeResponseEvent?>(null) }

    // Listen for confirmation pushes from the receiver
    LaunchedEffect(Unit) {
        WakeResponseSignal.signal.collect { event ->
            wakeResponseEvent = event
            HistoryRefreshSignal.emit()
        }
    }

    fun sendWakeRequest(contact: Contact, sound: AlarmSound) {
        scope.launch {
            isSendingWake = true
            wakeError = null
            val session = SupabaseClient.getValidSession()
            if (session == null) {
                isSendingWake = false
                onSignOut()
                return@launch
            }
            DebugLogger.debug("WAKE_DEBUG", "sendWakeRequest START contactId=${contact.id} name=${contact.displayName} sound=${sound.id}")
            DebugLogger.logWakeButtonTapped(contact.id, contact.displayName)
            try {
                val responseText = withContext(Dispatchers.IO) {
                    val url = URL("${SupabaseClient.SUPABASE_URL}/functions/v1/send-wake")
                    val conn = url.openConnection() as HttpURLConnection
                    conn.requestMethod = "POST"
                    conn.setRequestProperty("Content-Type", "application/json")
                    conn.setRequestProperty("apikey", SupabaseClient.SUPABASE_ANON_KEY)
                    conn.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
                    conn.connectTimeout = 15_000
                    conn.readTimeout = 15_000
                    conn.doOutput = true
                    val body = JSONObject()
                        .put("targetUserId", contact.id)
                        .put("alarmSoundId", sound.id)
                        .toString()
                    DebugLogger.debug("WAKE_DEBUG", "POST /send-wake body=$body")
                    conn.outputStream.use { it.write(body.toByteArray()) }
                    val code = conn.responseCode
                    val text = if (code in 200..299) conn.inputStream.bufferedReader().readText()
                               else conn.errorStream?.bufferedReader()?.readText() ?: "{}"
                    DebugLogger.debug("WAKE_DEBUG", "POST /send-wake code=$code response=$text")
                    conn.disconnect()
                    text
                }
                val json = JSONObject(responseText)
                val success = json.optBoolean("success", false)
                if (success) {
                    val traceId = json.optString("traceId", DebugLogger.generateTraceId())
                    val devicesNotified = json.optInt("devicesNotified", 0)
                    DebugLogger.logWakeRequestSent(traceId, contact.id, sound.id)
                    DebugLogger.logWakeResponse(mapOf(
                        "success" to true,
                        "requestId" to json.optString("requestId"),
                        "traceId" to traceId,
                        "devicesNotified" to devicesNotified
                    ))
                    DebugLogger.debug("WAKE_DEBUG", "sendWakeRequest SUCCESS devicesNotified=$devicesNotified")
                    lastWakedContact = contact
                    showWakeConfirmation = true
                    HistoryRefreshSignal.emit()
                } else {
                    val error = json.optString("error", "Failed to send wake request")
                    wakeError = error
                    android.util.Log.e("WAKE_DEBUG", "sendWakeRequest FAILED error=$error")
                }
            } catch (e: Exception) {
                wakeError = e.message ?: "Network error"
                android.util.Log.e("WAKE_DEBUG", "sendWakeRequest EXCEPTION", e)
            }
            isSendingWake = false
        }
    }

    // Real contacts data
    var peopleICanWake by remember { mutableStateOf<List<Contact>>(emptyList()) }
    var peopleWhoCanWakeMe by remember { mutableStateOf<List<Contact>>(emptyList()) }
    var receivedInvites by remember { mutableStateOf<List<InviteItem>>(emptyList()) }
    var sentInvites by remember { mutableStateOf<List<InviteItem>>(emptyList()) }
    var isLoadingContacts by remember { mutableStateOf(false) }
    var contactsError by remember { mutableStateOf<String?>(null) }
    var isBackgroundRefreshing by remember { mutableStateOf(false) }

    // Helper: check if lists actually changed before updating state (avoids UI flicker)
    fun <T> List<T>.contentDiffers(other: List<T>): Boolean {
        if (this.size != other.size) return true
        return this.zip(other).any { (a, b) -> a != b }
    }

    fun loadContacts(isBackgroundRefresh: Boolean = false) {
        // For background refreshes, use a separate flag; for initial loads, use isLoadingContacts
        if (isLoadingContacts || isBackgroundRefreshing) return
        scope.launch {
            if (isBackgroundRefresh) {
                isBackgroundRefreshing = true
            } else {
                isLoadingContacts = true
            }
            contactsError = null
            try {
                val result = InviteRepository.getContacts()
                if (result.success) {
                    val mapContact = { item: com.wakeupsunshine.data.ContactItem ->
                        val baseName = item.displayName.ifBlank { item.email.ifBlank { "Unknown" } }
                        Contact(
                            id = item.id,
                            displayName = com.wakeupsunshine.data.NicknameStore.get(context, item.email) ?: baseName,
                            email = item.email,
                            avatarColor = avatarColorFromString(item.email),
                            isOnline = false
                        )
                    }
                    val newCanWake = result.peopleICanWake.map(mapContact)
                    val newCanWakeMe = result.peopleWhoCanWakeMe.map(mapContact)
                    val newReceived = result.pendingInvitesReceived
                    val newSent = result.pendingInvitesSent

                    // Only update state if data actually changed — prevents UI flicker/reset
                    if (peopleICanWake.contentDiffers(newCanWake)) peopleICanWake = newCanWake
                    if (peopleWhoCanWakeMe.contentDiffers(newCanWakeMe)) peopleWhoCanWakeMe = newCanWakeMe
                    if (receivedInvites.contentDiffers(newReceived)) receivedInvites = newReceived
                    if (sentInvites.contentDiffers(newSent)) sentInvites = newSent

                    DebugLogger.debug("HomeScreen", "Loaded: canWake=${newCanWake.size} canWakeMe=${newCanWakeMe.size} received=${newReceived.size} sent=${newSent.size} background=$isBackgroundRefresh")
                } else {
                    // Only show errors on explicit loads, not background refreshes
                    if (!isBackgroundRefresh) {
                        contactsError = result.error ?: "Failed to load contacts"
                    }
                }
            } catch (e: Exception) {
                // Only show errors on explicit loads, not background refreshes
                if (!isBackgroundRefresh) {
                    contactsError = e.message ?: "Network error"
                }
                android.util.Log.e("HomeScreen", "Failed to load contacts (background=$isBackgroundRefresh)", e)
            }
            isLoadingContacts = false
            isBackgroundRefreshing = false
        }
    }

    LaunchedEffect(Unit) {
        loadContacts(isBackgroundRefresh = false)
    }

    LaunchedEffect(Unit) {
        ContactsRefreshSignal.signal.collect {
            loadContacts(isBackgroundRefresh = false)
        }
    }

    LaunchedEffect(Unit) {
        while (isActive) {
            delay(10_000)
            loadContacts(isBackgroundRefresh = true)
        }
    }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                loadContacts(isBackgroundRefresh = true)
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    // Reload every time the Contacts tab becomes active so stale pending rows disappear
    LaunchedEffect(selectedTab) {
        if (selectedTab == 1) loadContacts(isBackgroundRefresh = true)
    }

    Scaffold(
        bottomBar = {
            NavigationBar(
                containerColor = MaterialTheme.colorScheme.surface,
                tonalElevation = 8.dp
            ) {
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    icon = { Icon(Icons.Default.Notifications, contentDescription = null) },
                    label = { Text("Wake up") }
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = {
                        BadgedBox(
                            badge = {
                                if (receivedInvites.isNotEmpty()) Badge { Text(receivedInvites.size.toString()) }
                            }
                        ) {
                            Icon(Icons.Default.People, contentDescription = null)
                        }
                    },
                    label = { Text("Contacts") }
                )
                NavigationBarItem(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    icon = { Icon(Icons.Default.History, contentDescription = null) },
                    label = { Text("History") }
                )
                NavigationBarItem(
                    selected = selectedTab == 3,
                    onClick = { selectedTab = 3 },
                    icon = { Icon(Icons.Default.Settings, contentDescription = null) },
                    label = { Text("Settings") }
                )
            }
        }
    ) { padding ->
        when (selectedTab) {
            0 -> HomeContent(
                contacts = peopleICanWake,
                isLoading = isLoadingContacts && peopleICanWake.isEmpty(),
                onWakeContact = { contact ->
                    selectedContact = contact
                    showAlarmPicker = true
                },
                onAddContact = { showInviteDialog = true },
                modifier = Modifier.padding(padding)
            )
            2 -> HistoryScreen(modifier = Modifier.padding(padding))
            3 -> SettingsScreen(
                onSignOut = onSignOut,
                currentTheme = currentTheme,
                onThemeChange = onThemeChange,
                useScaffold = false,
                modifier = Modifier.padding(padding)
            )
            1 -> ContactsContent(
                contacts = peopleICanWake,
                peopleWhoCanWakeMe = peopleWhoCanWakeMe,
                receivedInvites = receivedInvites,
                sentInvites = sentInvites,
                isLoading = isLoadingContacts && peopleICanWake.isEmpty() && peopleWhoCanWakeMe.isEmpty() && receivedInvites.isEmpty() && sentInvites.isEmpty(),
                isBackgroundRefreshing = isBackgroundRefreshing,
                onRefresh = { loadContacts(isBackgroundRefresh = false) },
                onWakeContact = { contact ->
                    selectedContact = contact
                    showAlarmPicker = true
                },
                onEditNickname = { contact ->
                    editNicknameText = com.wakeupsunshine.data.NicknameStore.get(context, contact.email) ?: ""
                    editingNicknameContact = contact
                },
                onAddContact = { showInviteDialog = true },
                onAcceptInvite = { invite ->
                    scope.launch {
                        try {
                            DebugLogger.debug("HomeScreen", "Accepting invite id=${invite.id} token=${invite.inviteToken?.take(8)}")
                            val result = InviteRepository.acceptInvite(invite.id, invite.inviteToken)
                            if (result.success) {
                                loadContacts()
                            } else {
                                contactsError = result.error ?: "Failed to accept invite"
                                android.util.Log.w("HomeScreen", "Accept failed: ${result.error} code=${result.debugCode}")
                            }
                        } catch (e: Exception) {
                            contactsError = e.message ?: "Network error"
                        }
                    }
                },
                onDeclineInvite = { invite ->
                    scope.launch {
                        try {
                            val result = InviteRepository.declineInvite(invite.id, invite.inviteToken)
                            if (result.success) {
                                loadContacts()
                            } else {
                                contactsError = result.error ?: "Failed to decline invite"
                            }
                        } catch (e: Exception) {
                            contactsError = e.message ?: "Network error"
                        }
                    }
                },
                onDeleteContact = { contact, iAmGranter ->
                    scope.launch {
                        val myId = SupabaseClient.getCurrentUserId() ?: return@launch
                        val ok = InviteRepository.removeContact(myId, contact.id, iAmGranter)
                        if (ok) {
                            loadContacts()
                        } else {
                            contactsError = "Could not remove contact. Try again."
                        }
                    }
                },
                onBlockContact = { contact ->
                    scope.launch {
                        val myId = SupabaseClient.getCurrentUserId() ?: return@launch
                        val ok = InviteRepository.updateWakePermissionStatus(myId, contact.id, "blocked")
                        if (ok) {
                            loadContacts()
                        } else {
                            contactsError = "Could not block contact. Try again."
                        }
                    }
                },
                onCancelInvite = { invite ->
                    scope.launch {
                        val myId = SupabaseClient.getCurrentUserId() ?: return@launch
                        val ok = InviteRepository.cancelSentInvite(invite.id, myId)
                        if (ok) {
                            loadContacts()
                        } else {
                            contactsError = "Could not cancel invite. Try again."
                        }
                    }
                },
                modifier = Modifier.padding(padding)
            )
        }
    }

    // Alarm picker bottom sheet
    if (showAlarmPicker && selectedContact != null) {
        ModalBottomSheet(
            onDismissRequest = {
                showAlarmPicker = false
                selectedContact = null
            },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ) {
            AlarmSoundPicker(
                contactName = selectedContact!!.displayName,
                onSend = { sound ->
                    val contact = selectedContact
                    showAlarmPicker = false
                    selectedContact = null
                    if (contact != null) sendWakeRequest(contact, sound)
                },
                onDismiss = {
                    showAlarmPicker = false
                    selectedContact = null
                }
            )
        }
    }

    // Wake sent confirmation dialog
    if (showWakeConfirmation && lastWakedContact != null) {
        AlertDialog(
            onDismissRequest = { showWakeConfirmation = false },
            title = { Text("Wake Alert Sent!") },
            text = { Text("${lastWakedContact!!.displayName} received your wake alert. Waiting for their response…") },
            confirmButton = {
                TextButton(onClick = { showWakeConfirmation = false }) {
                    Text("OK")
                }
            }
        )
    }

    // Wake response received dialog (they're awake / snoozed / dismissed)
    wakeResponseEvent?.let { event ->
        val (title, message) = when (event.action) {
            "confirmed" -> "They're Awake! 🌅" to "${event.receiverName} confirmed they're awake."
            "snoozed"   -> "Snoozed 💤" to "${event.receiverName} snoozed the alarm."
            "dismissed" -> "Dismissed ❌" to "${event.receiverName} dismissed the alarm."
            else        -> "Response Received" to "${event.receiverName} responded."
        }
        AlertDialog(
            onDismissRequest = { wakeResponseEvent = null },
            title = { Text(title) },
            text = { Text(message) },
            confirmButton = {
                TextButton(onClick = { wakeResponseEvent = null }) { Text("OK") }
            }
        )
    }

    // Contacts error
    if (contactsError != null) {
        AlertDialog(
            onDismissRequest = { contactsError = null },
            title = { Text("Error") },
            text = { Text(contactsError!!) },
            confirmButton = {
                TextButton(onClick = { contactsError = null }) { Text("OK") }
            }
        )
    }

    // Wake send error
    if (wakeError != null) {
        AlertDialog(
            onDismissRequest = { wakeError = null },
            title = { Text("Wake Failed") },
            text = { Text(wakeError!!) },
            confirmButton = {
                TextButton(onClick = { wakeError = null }) { Text("OK") }
            }
        )
    }

    // Sending indicator
    if (isSendingWake) {
        AlertDialog(
            onDismissRequest = {},
            title = { Text("Sending…") },
            text = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp), color = Orange500, strokeWidth = 2.dp)
                    Spacer(Modifier.width(12.dp))
                    Text("Sending wake request…")
                }
            },
            confirmButton = {}
        )
    }

    // Invite contact dialog
    if (showInviteDialog) {
        InviteContactDialog(
            onDismiss = { showInviteDialog = false },
            onInviteSent = {
                showInviteDialog = false
                loadContacts()
            }
        )
    }

    // Nickname edit dialog
    editingNicknameContact?.let { contact ->
        AlertDialog(
            onDismissRequest = { editingNicknameContact = null },
            title = { Text("Edit Nickname") },
            text = {
                Column {
                    Text(
                        text = contact.email.ifBlank { contact.displayName },
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(
                        value = editNicknameText,
                        onValueChange = { editNicknameText = it },
                        label = { Text("Nickname (optional)") },
                        placeholder = { Text("Leave blank to use real name") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = "Shown on contact cards instead of their account name.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    com.wakeupsunshine.data.NicknameStore.set(context, contact.email, editNicknameText.trim().ifBlank { null })
                    editingNicknameContact = null
                    loadContacts()
                }) { Text("Save") }
            },
            dismissButton = {
                TextButton(onClick = { editingNicknameContact = null }) { Text("Cancel") }
            }
        )
    }
}

@Composable
private fun HomeContent(
    contacts: List<Contact>,
    isLoading: Boolean,
    onWakeContact: (Contact) -> Unit,
    onAddContact: () -> Unit,
    modifier: Modifier = Modifier
) {
    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Column {
                Text(
                    text = "Wake Up Sunshine",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = getGreeting(LocalContext.current),
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        item {
            Text(
                text = "People I Can Wake",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold
            )
        }

        if (isLoading) {
            item {
                Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = Orange500)
                }
            }
        } else {
            items(contacts.chunked(2)) { rowContacts ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    rowContacts.forEach { contact ->
                        ContactCard(
                            contact = contact,
                            onWakeClick = { onWakeContact(contact) },
                            modifier = Modifier.weight(1f)
                        )
                    }
                    if (rowContacts.size == 1) {
                        Spacer(Modifier.weight(1f))
                    }
                }
            }

            item {
                AddContactCard(modifier = Modifier.fillMaxWidth(), onClick = onAddContact)
            }

            if (contacts.isEmpty()) {
                item { EmptyContactsView() }
            }
        }
    }
}

@Composable
private fun ContactsContent(
    contacts: List<Contact>,
    peopleWhoCanWakeMe: List<Contact>,
    receivedInvites: List<InviteItem>,
    sentInvites: List<InviteItem>,
    isLoading: Boolean,
    isBackgroundRefreshing: Boolean = false,
    onRefresh: () -> Unit,
    onWakeContact: (Contact) -> Unit,
    onEditNickname: (Contact) -> Unit,
    onAddContact: () -> Unit,
    onAcceptInvite: (InviteItem) -> Unit,
    onDeclineInvite: (InviteItem) -> Unit,
    onDeleteContact: (Contact, Boolean) -> Unit,
    onBlockContact: (Contact) -> Unit,
    onCancelInvite: (InviteItem) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Manage Contacts",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold
                )
                // Always show refresh button; subtle spinner when background refreshing
                if (isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp),
                        color = Orange500,
                        strokeWidth = 2.dp
                    )
                } else if (isBackgroundRefreshing) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        color = Orange500.copy(alpha = 0.4f),
                        strokeWidth = 1.5.dp
                    )
                } else {
                    IconButton(onClick = onRefresh) {
                        Icon(
                            Icons.Default.Refresh,
                            contentDescription = "Refresh contacts",
                            tint = Orange500
                        )
                    }
                }
            }
        }

        // Pending invites received
        if (receivedInvites.isNotEmpty()) {
            item {
                Text(
                    text = "Pending Invites",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = Orange500
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = "People who want to wake you",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            items(receivedInvites) { invite ->
                ReceivedInviteRow(
                    invite = invite,
                    onAccept = { onAcceptInvite(invite) },
                    onDecline = { onDeclineInvite(invite) }
                )
            }
            item { Spacer(Modifier.height(4.dp)) }
        }

        // People I can wake (accepted contacts)
        if (contacts.isNotEmpty()) {
            item {
                Text(
                    text = "People I Can Wake",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
            }
            items(contacts) { contact ->
                ContactListRow(
                    contact = contact,
                    onWakeClick = { onWakeContact(contact) },
                    onEditNickname = { onEditNickname(contact) },
                    onDelete = { onDeleteContact(contact, false) }
                )
            }
            item { Spacer(Modifier.height(4.dp)) }
        }

        // People who can wake me
        if (peopleWhoCanWakeMe.isNotEmpty()) {
            item {
                Text(
                    text = "People Who Can Wake Me",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = "They can send you wake alerts",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            items(peopleWhoCanWakeMe) { contact ->
                ContactListRow(
                    contact = contact,
                    onWakeClick = {},
                    onEditNickname = { onEditNickname(contact) },
                    onDelete = { onDeleteContact(contact, true) },
                    onBlock = { onBlockContact(contact) },
                    showWakeButton = false,
                    statusLabel = "Can wake me"
                )
            }
            item { Spacer(Modifier.height(4.dp)) }
        }

        // Sent invites awaiting acceptance
        if (sentInvites.isNotEmpty()) {
            item {
                Text(
                    text = "Invites You Sent",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = "Waiting for them to accept in the app",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            items(sentInvites) { invite ->
                SentInviteRow(invite = invite, onCancel = { onCancelInvite(invite) })
            }
            item { Spacer(Modifier.height(4.dp)) }
        }

        item {
            AddContactCard(modifier = Modifier.fillMaxWidth(), onClick = onAddContact)
        }

        if (!isLoading && contacts.isEmpty() && peopleWhoCanWakeMe.isEmpty() && receivedInvites.isEmpty() && sentInvites.isEmpty()) {
            item { EmptyContactsView() }
        }
    }
}

@Composable
private fun SentInviteRow(invite: InviteItem, onCancel: () -> Unit) {
    val primaryText = run {
        val label = invite.inviteeLabel?.trim().orEmpty()
        if (label.isNotEmpty()) {
            label
        } else {
            val email = invite.inviteeEmail
            when {
                email.isNullOrBlank() -> "Share Link Invite"
                email.endsWith("@share.link") || email.endsWith("@qr.code") -> "Share Link Invite"
                else -> email
            }
        }
    }
    val secondaryText = run {
        val email = invite.inviteeEmail
        when {
            email.isNullOrBlank() -> "Waiting for them to accept"
            email.endsWith("@share.link") || email.endsWith("@qr.code") -> "Waiting for them to accept via shared link"
            !invite.inviteeLabel.isNullOrBlank() -> "$email - Waiting for them to accept"
            else -> "Waiting for them to accept"
        }
    }
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = primaryText,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = secondaryText,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            FilledIconButton(
                onClick = onCancel,
                modifier = Modifier.size(36.dp),
                colors = IconButtonDefaults.filledIconButtonColors(containerColor = MaterialTheme.colorScheme.errorContainer)
            ) {
                Icon(
                    Icons.Default.Close,
                    contentDescription = "Cancel invite",
                    tint = MaterialTheme.colorScheme.onErrorContainer,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    }
}

@Composable
private fun ReceivedInviteRow(
    invite: InviteItem,
    onAccept: () -> Unit,
    onDecline: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        colors = CardDefaults.cardColors(containerColor = Orange500.copy(alpha = 0.05f))
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Avatar
            val name = invite.inviterName ?: invite.inviterEmail ?: "?"
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(Orange500.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = name.take(1).uppercase(),
                    style = MaterialTheme.typography.titleMedium,
                    color = Orange500,
                    fontWeight = FontWeight.Bold
                )
            }

            Spacer(Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = name,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = "Wants to wake you",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            // Decline
            FilledIconButton(
                onClick = onDecline,
                modifier = Modifier.size(40.dp),
                colors = IconButtonDefaults.filledIconButtonColors(containerColor = MaterialTheme.colorScheme.errorContainer)
            ) {
                Icon(
                    Icons.Default.Close,
                    contentDescription = "Decline",
                    tint = MaterialTheme.colorScheme.onErrorContainer,
                    modifier = Modifier.size(18.dp)
                )
            }

            Spacer(Modifier.width(8.dp))

            // Accept
            FilledIconButton(
                onClick = onAccept,
                modifier = Modifier.size(40.dp),
                colors = IconButtonDefaults.filledIconButtonColors(containerColor = Green500)
            ) {
                Icon(
                    Icons.Default.Check,
                    contentDescription = "Accept",
                    tint = Color.White,
                    modifier = Modifier.size(18.dp)
                )
            }
        }
    }
}

@Composable
private fun ContactCard(
    contact: Contact,
    onWakeClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(16.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Bell button at top
            FilledIconButton(
                onClick = onWakeClick,
                modifier = Modifier.size(48.dp),
                colors = IconButtonDefaults.filledIconButtonColors(containerColor = Orange500)
            ) {
                Icon(
                    Icons.Default.Notifications,
                    contentDescription = "Wake",
                    modifier = Modifier.size(24.dp)
                )
            }

            Spacer(Modifier.height(8.dp))

            Text(
                text = contact.displayName,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center
            )

            Spacer(Modifier.height(4.dp))

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                Box(
                    modifier = Modifier
                        .size(6.dp)
                        .clip(CircleShape)
                        .background(Green500)
                )
                Spacer(Modifier.width(4.dp))
                Text(
                    text = "Ready",
                    style = MaterialTheme.typography.labelSmall,
                    color = Green500
                )
            }
        }
    }
}

@Composable
private fun ContactListRow(
    contact: Contact,
    onWakeClick: () -> Unit,
    onEditNickname: (() -> Unit)? = null,
    onDelete: (() -> Unit)? = null,
    onBlock: (() -> Unit)? = null,
    showWakeButton: Boolean = true,
    statusLabel: String = "Ready"
) {
    var showDeleteConfirm by remember { mutableStateOf(false) }
    var showBlockConfirm by remember { mutableStateOf(false) }

    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text("Remove Contact") },
            text = { Text("Remove ${contact.displayName}? They won't be able to wake you and you won't see each other in contacts.") },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteConfirm = false
                    onDelete?.invoke()
                }) { Text("Remove", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) { Text("Cancel") }
            }
        )
    }

    if (showBlockConfirm) {
        AlertDialog(
            onDismissRequest = { showBlockConfirm = false },
            title = { Text("Block Contact") },
            text = { Text("Block ${contact.displayName}? They will no longer be able to wake you until you unblock them in Settings.") },
            confirmButton = {
                TextButton(onClick = {
                    showBlockConfirm = false
                    onBlock?.invoke()
                }) { Text("Block", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { showBlockConfirm = false }) { Text("Cancel") }
            }
        )
    }

    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = contact.displayName,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(6.dp)
                            .clip(CircleShape)
                            .background(Green500)
                    )
                    Spacer(Modifier.width(4.dp))
                    Text(
                        text = statusLabel,
                        style = MaterialTheme.typography.bodySmall,
                        color = Green500
                    )
                }
            }

            if (onEditNickname != null) {
                IconButton(onClick = onEditNickname, modifier = Modifier.size(40.dp)) {
                    Icon(
                        Icons.Default.Edit,
                        contentDescription = "Edit nickname",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }

            if (onDelete != null) {
                IconButton(onClick = { showDeleteConfirm = true }, modifier = Modifier.size(40.dp)) {
                    Icon(
                        Icons.Default.Delete,
                        contentDescription = "Remove contact",
                        tint = MaterialTheme.colorScheme.error,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }

            if (onBlock != null) {
                IconButton(onClick = { showBlockConfirm = true }, modifier = Modifier.size(40.dp)) {
                    Icon(
                        Icons.Default.Block,
                        contentDescription = "Block contact",
                        tint = MaterialTheme.colorScheme.error,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }

            if (showWakeButton) {
                FilledIconButton(
                    onClick = onWakeClick,
                    modifier = Modifier.size(44.dp),
                    colors = IconButtonDefaults.filledIconButtonColors(containerColor = Orange500)
                ) {
                    Icon(
                        Icons.Default.Notifications,
                        contentDescription = "Wake",
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun AddContactCard(
    modifier: Modifier = Modifier,
    onClick: () -> Unit = {}
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val elevation by animateDpAsState(
        targetValue = if (isPressed) 8.dp else 1.dp,
        label = "addCardElevation"
    )
    Card(
        modifier = modifier.clickable(onClick = onClick, interactionSource = interactionSource, indication = null),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        elevation = CardDefaults.cardElevation(defaultElevation = elevation)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(Orange500.copy(alpha = 0.1f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Default.Add, contentDescription = null, tint = Orange500, modifier = Modifier.size(24.dp))
            }
            Spacer(Modifier.width(12.dp))
            Column {
                Text(text = "Add Contact", style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
                Text(
                    text = "Invite friends & family",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun EmptyContactsView() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(80.dp)
                .clip(CircleShape)
                .background(Orange500.copy(alpha = 0.1f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(Icons.Default.WbSunny, contentDescription = null, tint = Orange500, modifier = Modifier.size(40.dp))
        }
        Spacer(Modifier.height(16.dp))
        Text(text = "No Trusted Contacts Yet", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(8.dp))
        Text(
            text = "Add people who can wake you up when it matters most.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

private fun getGreeting(context: android.content.Context): String {
    val hour = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
    // Try to get user's display name from stored preferences
    val prefs = context.getSharedPreferences("user_profile", android.content.Context.MODE_PRIVATE)
    val displayName = prefs.getString("display_name", "")?.trim() ?: ""
    val firstName = displayName.split(" ").firstOrNull()?.trim() ?: ""
    val namePart = if (firstName.isNotEmpty()) " $firstName" else ""
    return when {
        hour < 12 -> "Good morning$namePart"
        hour < 17 -> "Good afternoon$namePart"
        else -> "Good evening$namePart"
    }
}
