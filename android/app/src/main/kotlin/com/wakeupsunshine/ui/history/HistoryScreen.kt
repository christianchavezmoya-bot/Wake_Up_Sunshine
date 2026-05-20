package com.wakeupsunshine.ui.history

import androidx.compose.foundation.background
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.wakeupsunshine.data.HistoryItem
import com.wakeupsunshine.data.HistoryRefreshSignal
import com.wakeupsunshine.data.HistoryRepository
import com.wakeupsunshine.ui.theme.Orange500
import kotlinx.coroutines.launch
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HistoryScreen(modifier: Modifier = Modifier) {
    val scope = rememberCoroutineScope()
    var items by remember { mutableStateOf<List<HistoryItem>>(emptyList()) }
    var isLoading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var showDeleteAllConfirm by remember { mutableStateOf(false) }

    fun load() {
        scope.launch {
            isLoading = true
            error = null
            try {
                val result = HistoryRepository.getHistory()
                if (result.success) items = result.history
                else error = result.error ?: "Failed to load history"
            } catch (e: Exception) {
                error = e.message ?: "Network error"
            }
            isLoading = false
        }
    }

    LaunchedEffect(Unit) { load() }

    LaunchedEffect(Unit) {
        HistoryRefreshSignal.signal.collect { load() }
    }

    Column(modifier = modifier.fillMaxSize()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = "History",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
            if (isLoading) {
                CircularProgressIndicator(modifier = Modifier.size(24.dp), color = Orange500, strokeWidth = 2.dp)
            } else {
                Row {
                    if (items.isNotEmpty()) {
                        IconButton(onClick = { showDeleteAllConfirm = true }) {
                            Icon(Icons.Default.Delete, contentDescription = "Delete All", tint = MaterialTheme.colorScheme.error)
                        }
                    }
                    IconButton(onClick = ::load) {
                        Icon(Icons.Default.Refresh, contentDescription = "Refresh", tint = Orange500)
                    }
                }
            }

        }

        if (showDeleteAllConfirm) {
            androidx.compose.material3.AlertDialog(
                onDismissRequest = { showDeleteAllConfirm = false },
                title = { Text("Delete All History?") },
                text = { Text("This will remove all history items from view.") },
                confirmButton = {
                    androidx.compose.material3.TextButton(onClick = { items = emptyList(); showDeleteAllConfirm = false }) {
                        Text("Delete All", color = MaterialTheme.colorScheme.error)
                    }
                },
                dismissButton = {
                    androidx.compose.material3.TextButton(onClick = { showDeleteAllConfirm = false }) {
                        Text("Cancel")
                    }
                }
            )
        }

        if (error != null) {
            Text(
                text = error!!,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
        }

        if (!isLoading && items.isEmpty() && error == null) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        Icons.Default.History,
                        contentDescription = null,
                        tint = Orange500.copy(alpha = 0.4f),
                        modifier = Modifier.size(64.dp)
                    )
                    Spacer(Modifier.height(12.dp))
                    Text("No wake history yet", style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        } else {
            LazyColumn(
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(items, key = { it.id }) { item ->
                    val dismissState = rememberSwipeToDismissBoxState(
                        confirmValueChange = { value ->
                            if (value == SwipeToDismissBoxValue.EndToStart) {
                                items = items.filter { it.id != item.id }
                                true
                            } else false
                        }
                    )
                    SwipeToDismissBox(
                        state = dismissState,
                        enableDismissFromStartToEnd = false,
                        backgroundContent = {
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .padding(vertical = 0.dp)
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(MaterialTheme.colorScheme.errorContainer),
                                contentAlignment = Alignment.CenterEnd
                            ) {
                                Row(
                                    modifier = Modifier.padding(end = 20.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(
                                        Icons.Default.Delete,
                                        contentDescription = "Delete",
                                        tint = MaterialTheme.colorScheme.onErrorContainer
                                    )
                                    Spacer(Modifier.width(4.dp))
                                    Text(
                                        "Delete",
                                        color = MaterialTheme.colorScheme.onErrorContainer,
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.Medium
                                    )
                                }
                            }
                        }
                    ) {
                        HistoryRow(item = item)
                    }
                }
            }
        }
    }
}

@Composable
private fun HistoryRow(item: HistoryItem) {
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
            // Direction badge + avatar
            Box {
                val initials = item.otherUserName.take(1).uppercase().ifBlank { "?" }
                val bg = parseHexColor(item.avatarColor)
                Box(
                    modifier = Modifier.size(48.dp).clip(CircleShape).background(bg),
                    contentAlignment = Alignment.Center
                ) {
                    Text(initials, style = MaterialTheme.typography.titleMedium, color = Color.White, fontWeight = FontWeight.Bold)
                }
                // Direction arrow
                Box(
                    modifier = Modifier
                        .size(18.dp)
                        .align(Alignment.BottomEnd)
                        .clip(CircleShape)
                        .background(if (item.direction == "sent") Orange500 else Color(0xFF4CAF50)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = if (item.direction == "sent") Icons.Default.ArrowUpward else Icons.Default.ArrowDownward,
                        contentDescription = item.direction,
                        tint = Color.White,
                        modifier = Modifier.size(12.dp)
                    )
                }
            }

            Spacer(Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = item.otherUserName.ifBlank { item.otherUserEmail.ifBlank { "Unknown" } },
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                val dirLabel = if (item.direction == "sent") "You woke" else "Woke you"
                Text(
                    text = "$dirLabel • ${formatTimestamp(item.createdAt)}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                if (!item.message.isNullOrBlank()) {
                    Text(
                        text = "“${item.message}”",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }

            Spacer(Modifier.width(8.dp))

            StatusChip(status = item.status, responseAction = item.responseAction)
        }
    }
}

@Composable
private fun StatusChip(status: String, responseAction: String?) {
    val (label, color) = when (responseAction ?: status) {
        "confirmed"  -> "Awake" to Color(0xFF4CAF50)
        "snoozed"    -> "Snoozed" to Color(0xFFFF9800)
        "dismissed"  -> "Dismissed" to Color(0xFF9E9E9E)
        "timed_out"  -> "Timed Out" to Color(0xFFF44336)
        "delivered"  -> "Delivered" to Orange500
        "sent"       -> "Sent" to Orange500.copy(alpha = 0.7f)
        else         -> "Pending" to MaterialTheme.colorScheme.onSurfaceVariant
    }
    Surface(shape = RoundedCornerShape(8.dp), color = color.copy(alpha = 0.15f)) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = color,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
        )
    }
}

private fun parseHexColor(hex: String): Color = try {
    Color(android.graphics.Color.parseColor(hex))
} catch (_: Exception) {
    Color(0xFFFF6B35)
}

private fun formatTimestamp(iso: String): String = try {
    val zdt = ZonedDateTime.parse(iso)
    zdt.format(DateTimeFormatter.ofLocalizedDateTime(FormatStyle.SHORT))
} catch (_: Exception) {
    iso.take(10)
}
