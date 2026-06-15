package com.wakeupsunshine.ui.contacts

import android.content.Context
import android.content.Intent
import android.widget.Toast
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
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
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.wakeupsunshine.data.InviteRepository
import com.wakeupsunshine.data.CreateInviteResponse
import kotlinx.coroutines.launch
import android.graphics.Bitmap
import com.google.zxing.BarcodeFormat
import com.google.zxing.MultiFormatWriter
import com.google.zxing.WriterException
import com.google.zxing.common.BitMatrix

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InviteContactDialog(
    onDismiss: () -> Unit,
    onInviteSent: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    
    var selectedTab by remember { mutableStateOf(0) }
    var email by remember { mutableStateOf("") }
    var nickname by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var createdInvite by remember { mutableStateOf<CreateInviteResponse?>(null) }
    var qrBitmap by remember { mutableStateOf<Bitmap?>(null) }
    
    val tabs = listOf("Email", "Share Link", "QR Code")
    
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth(0.95f)
                .wrapContentHeight(),
            shape = RoundedCornerShape(24.dp),
            color = MaterialTheme.colorScheme.surface
        ) {
            Column(
                modifier = Modifier.padding(24.dp)
            ) {
                // Header
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Add Contact",
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold
                    )
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, contentDescription = "Close")
                    }
                }
                
                Spacer(Modifier.height(16.dp))
                
                // Tab Row
                TabRow(selectedTabIndex = selectedTab) {
                    tabs.forEachIndexed { index, title ->
                        Tab(
                            selected = selectedTab == index,
                            onClick = { 
                                selectedTab = index
                                errorMessage = null
                            },
                            text = { Text(title) }
                        )
                    }
                }
                
                Spacer(Modifier.height(16.dp))
                
                // Content
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 200.dp, max = 400.dp)
                ) {
                    when (selectedTab) {
                        0 -> EmailInviteContent(
                            email = email,
                            nickname = nickname,
                            message = message,
                            isLoading = isLoading,
                            onEmailChange = { email = it },
                            onNicknameChange = { nickname = it },
                            onMessageChange = { message = it },
                            onSend = {
                                if (email.isNotBlank()) {
                                    scope.launch {
                                        isLoading = true
                                        errorMessage = null
                                        try {
                                            val trimmedNickname = nickname.trim().ifBlank { null }
                                            val response = InviteRepository.createInvite(
                                                email = email,
                                                inviteeLabel = trimmedNickname,
                                                message = message.takeIf { it.isNotBlank() }
                                            )
                                            if (response.success) {
                                                com.wakeupsunshine.data.NicknameStore.set(context, email, trimmedNickname)
                                                Toast.makeText(context, "Invite created. The person will see it when they log in with this email.", Toast.LENGTH_LONG).show()
                                                onInviteSent()
                                            } else {
                                                errorMessage = response.error ?: "Failed to send invite"
                                            }
                                        } catch (e: Exception) {
                                            errorMessage = e.message ?: "Network error"
                                        }
                                        isLoading = false
                                    }
                                }
                            }
                        )
                        1 -> ShareLinkContent(
                            createdInvite = createdInvite,
                            nickname = nickname,
                            isLoading = isLoading,
                            onNicknameChange = { nickname = it },
                            onCreateLink = {
                                scope.launch {
                                    isLoading = true
                                    errorMessage = null
                                    try {
                                        val response = InviteRepository.createInvite(
                                            email = "pending@share.link",
                                            inviteeLabel = nickname.trim()
                                        )
                                        if (response.success && (response.httpsLink != null || response.inviteLink != null)) {
                                            createdInvite = response
                                        } else {
                                            errorMessage = response.error ?: "Failed to create link"
                                        }
                                    } catch (e: Exception) {
                                        errorMessage = e.message ?: "Network error"
                                    }
                                    isLoading = false
                                }
                            },
                            onShare = {
                                (createdInvite?.httpsLink ?: createdInvite?.inviteLink)?.let { link ->
                                    val sendIntent = Intent().apply {
                                        action = Intent.ACTION_SEND
                                        putExtra(Intent.EXTRA_TEXT, 
                                            "Join me on Wake Up Sunshine! I want to be able to wake you up when it matters. $link")
                                        type = "text/plain"
                                    }
                                    context.startActivity(Intent.createChooser(sendIntent, "Share Invite Link"))
                                }
                            },
                            onCopy = {
                                (createdInvite?.httpsLink ?: createdInvite?.inviteLink)?.let { link ->
                                    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                                    val clip = android.content.ClipData.newPlainText("Invite Link", link)
                                    clipboard.setPrimaryClip(clip)
                                    Toast.makeText(context, "Link copied!", Toast.LENGTH_SHORT).show()
                                }
                            }
                        )
                        2 -> QRCodeContent(
                            qrBitmap = qrBitmap,
                            nickname = nickname,
                            isLoading = isLoading,
                            onNicknameChange = { nickname = it },
                            onGenerate = {
                                scope.launch {
                                    isLoading = true
                                    errorMessage = null
                                    try {
                                        val response = InviteRepository.createInvite(
                                            email = "pending@qr.code",
                                            inviteeLabel = nickname.trim()
                                        )
                                        val qrValue = response.qrPayload ?: response.httpsLink ?: response.inviteLink
                                        if (response.success && qrValue != null) {
                                            createdInvite = response
                                            // Generate QR code using zxing directly
                                            try {
                                                val bitMatrix = MultiFormatWriter().encode(
                                                    qrValue,
                                                    BarcodeFormat.QR_CODE,
                                                    512,
                                                    512
                                                )
                                                val width = bitMatrix.width
                                                val height = bitMatrix.height
                                                val pixels = IntArray(width * height)
                                                for (y in 0 until height) {
                                                    for (x in 0 until width) {
                                                        pixels[y * width + x] = if (bitMatrix[x, y]) {
                                                            android.graphics.Color.BLACK
                                                        } else {
                                                            android.graphics.Color.WHITE
                                                        }
                                                    }
                                                }
                                                qrBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                                                qrBitmap?.setPixels(pixels, 0, width, 0, 0, width, height)
                                            } catch (e: WriterException) {
                                                errorMessage = "Failed to generate QR code"
                                            }
                                        } else {
                                            errorMessage = response.error ?: "Failed to create QR code"
                                        }
                                    } catch (e: Exception) {
                                        errorMessage = e.message ?: "Network error"
                                    }
                                    isLoading = false
                                }
                            },
                            onCopy = {
                                (createdInvite?.httpsLink ?: createdInvite?.inviteLink)?.let { link ->
                                    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                                    val clip = android.content.ClipData.newPlainText("Invite Link", link)
                                    clipboard.setPrimaryClip(clip)
                                    Toast.makeText(context, "Link copied!", Toast.LENGTH_SHORT).show()
                                }
                            }
                        )
                    }
                }
                
                // Error Message
                if (errorMessage != null) {
                    Spacer(Modifier.height(8.dp))
                    Text(
                        text = errorMessage!!,
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodySmall,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        }
    }
}

@Composable
private fun EmailInviteContent(
    email: String,
    nickname: String,
    message: String,
    isLoading: Boolean,
    onEmailChange: (String) -> Unit,
    onNicknameChange: (String) -> Unit,
    onMessageChange: (String) -> Unit,
    onSend: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        OutlinedTextField(
            value = email,
            onValueChange = onEmailChange,
            label = { Text("Email Address") },
            singleLine = true,
            keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = KeyboardType.Email),
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(12.dp))

        OutlinedTextField(
            value = nickname,
            onValueChange = onNicknameChange,
            label = { Text("Nickname (Optional)") },
            placeholder = { Text("e.g. Mom, Best Friend…") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        androidx.compose.material3.Text(
            text = "Shown on contact cards instead of their account name.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.fillMaxWidth().padding(top = 4.dp)
        )

        Spacer(Modifier.height(12.dp))

        OutlinedTextField(
            value = message,
            onValueChange = onMessageChange,
            label = { Text("Message (Optional)") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        
        Spacer(Modifier.height(16.dp))
        
        Button(
            onClick = onSend,
            enabled = email.isNotBlank() && !isLoading,
            modifier = Modifier.fillMaxWidth()
        ) {
            if (isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    color = MaterialTheme.colorScheme.onPrimary,
                    strokeWidth = 2.dp
                )
            } else {
                Icon(Icons.Default.PersonAdd, contentDescription = null, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(8.dp))
                Text("Create Invite")
            }
        }
        
        Spacer(Modifier.height(12.dp))
        
        Text(
            text = "The recipient will need to accept your invitation before you can wake them.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun ShareLinkContent(
    createdInvite: CreateInviteResponse?,
    nickname: String,
    isLoading: Boolean,
    onNicknameChange: (String) -> Unit,
    onCreateLink: () -> Unit,
    onShare: () -> Unit,
    onCopy: () -> Unit
) {
    val shareableLink = createdInvite?.httpsLink ?: createdInvite?.inviteLink
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        OutlinedTextField(
            value = nickname,
            onValueChange = onNicknameChange,
            label = { Text("Nickname") },
            placeholder = { Text("e.g. Mom, Best Friend...") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(6.dp))

        Text(
            text = "Required so you can recognize this share-link invite later.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )

        Spacer(Modifier.height(12.dp))

        if (isLoading) {
            CircularProgressIndicator()
            Spacer(Modifier.height(8.dp))
            Text("Creating invite link...")
        } else if (shareableLink != null) {
            // Show link
            OutlinedTextField(
                value = shareableLink,
                onValueChange = {},
                readOnly = true,
                label = { Text("Your Invite Link") },
                modifier = Modifier.fillMaxWidth(),
                trailingIcon = {
                    IconButton(onClick = onCopy) {
                        Icon(Icons.Default.ContentCopy, contentDescription = "Copy")
                    }
                }
            )
            
            Spacer(Modifier.height(16.dp))
            
            Button(
                onClick = onShare,
                modifier = Modifier.fillMaxWidth()
            ) {
                Icon(Icons.Default.Share, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text("Share Link")
            }
        } else {
            Button(
                onClick = onCreateLink,
                enabled = nickname.isNotBlank(),
                modifier = Modifier.fillMaxWidth()
            ) {
                Icon(Icons.Default.Link, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text("Create Invite Link")
            }
        }
        
        Spacer(Modifier.height(12.dp))
        
        Text(
            text = "Share this link with your contact. They'll need to install Wake Up Sunshine and accept your invitation.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun QRCodeContent(
    qrBitmap: Bitmap?,
    nickname: String,
    isLoading: Boolean,
    onNicknameChange: (String) -> Unit,
    onGenerate: () -> Unit,
    onCopy: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        OutlinedTextField(
            value = nickname,
            onValueChange = onNicknameChange,
            label = { Text("Nickname") },
            placeholder = { Text("e.g. Mom, Best Friend...") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(6.dp))

        Text(
            text = "Required so you can recognize this QR invite later.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )

        Spacer(Modifier.height(12.dp))

        if (isLoading) {
            CircularProgressIndicator()
            Spacer(Modifier.height(8.dp))
            Text("Generating QR Code...")
        } else if (qrBitmap != null) {
            // Show QR
            Image(
                bitmap = qrBitmap.asImageBitmap(),
                contentDescription = "QR Code",
                modifier = Modifier
                    .size(200.dp)
                    .background(Color.White, RoundedCornerShape(8.dp))
                    .padding(8.dp)
            )
            
            Spacer(Modifier.height(12.dp))
            
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedButton(onClick = onCopy) {
                    Icon(Icons.Default.ContentCopy, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("Copy Link")
                }
                
                OutlinedButton(onClick = onGenerate) {
                    Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("New QR")
                }
            }
        } else {
            Button(
                onClick = onGenerate,
                enabled = nickname.isNotBlank(),
                modifier = Modifier.fillMaxWidth()
            ) {
                Icon(Icons.Default.QrCode, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text("Generate QR Code")
            }
        }
        
        Spacer(Modifier.height(12.dp))
        
        Text(
            text = "Let your contact scan this QR code with their phone to accept your invitation.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
    }
}
