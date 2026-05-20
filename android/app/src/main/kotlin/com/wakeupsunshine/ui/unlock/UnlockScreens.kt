package com.wakeupsunshine.ui.unlock

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.wakeupsunshine.data.UnlockRepository
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter

// MARK: - Paywall Screen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PaywallScreen(
    onDismiss: () -> Unit,
    onPurchaseSuccess: () -> Unit
) {
    val viewModel: UnlockViewModel = viewModel()
    val isUnlocked by viewModel.isUnlocked.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val productPrice by viewModel.productPrice.collectAsState()
    val error by viewModel.error.collectAsState()
    
    val primaryOrange = Color(0xFFFF6B35)
    val lightOrange = Color(0xFFF7931E)
    
    LaunchedEffect(isUnlocked) {
        if (isUnlocked) {
            onPurchaseSuccess()
        }
    }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { },
                navigationIcon = {
                    TextButton(onClick = onDismiss) {
                        Text("Close", color = Color.White)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent
                )
            )
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.linearGradient(
                        colors = listOf(primaryOrange, lightOrange)
                    )
                )
                .padding(padding)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Spacer(modifier = Modifier.height(20.dp))
                
                // Hero
                Icon(
                    imageVector = Icons.Default.WbSunny,
                    contentDescription = null,
                    modifier = Modifier.size(80.dp),
                    tint = Color.White
                )
                
                Spacer(modifier = Modifier.height(16.dp))
                
                Text(
                    text = "Wake Me Up",
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                
                Text(
                    text = "Lifetime Access",
                    fontSize = 18.sp,
                    color = Color.White.copy(alpha = 0.9f)
                )
                
                Spacer(modifier = Modifier.height(32.dp))
                
                // Features
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(20.dp))
                        .background(Color.White.copy(alpha = 0.15f))
                        .padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    FeatureItem(
                        icon = Icons.Default.Notifications,
                        title = "Unlimited Wake Calls",
                        description = "Wake up your friends and family anytime"
                    )
                    FeatureItem(
                        icon = Icons.Default.People,
                        title = "Unlimited Contacts",
                        description = "Add as many contacts as you want"
                    )
                    FeatureItem(
                        icon = Icons.Default.CardGiftcard,
                        title = "2 Free Invites",
                        description = "Share full access with 2 friends for free"
                    )
                    FeatureItem(
                        icon = Icons.Default.AllInclusive,
                        title = "Lifetime Access",
                        description = "One-time purchase, forever yours"
                    )
                }
                
                Spacer(modifier = Modifier.height(32.dp))
                
                // Purchase Button
                Button(
                    onClick = { viewModel.purchase() },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                    shape = RoundedCornerShape(16.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color.White,
                        contentColor = primaryOrange
                    ),
                    enabled = !isLoading
                ) {
                    if (isLoading) {
                        CircularProgressIndicator(
                            color = primaryOrange,
                            modifier = Modifier.size(24.dp)
                        )
                    } else {
                        Text(
                            text = "Unlock Lifetime",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
                
                if (productPrice.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "One-time purchase • $productPrice",
                        fontSize = 14.sp,
                        color = Color.White.copy(alpha = 0.8f)
                    )
                }
                
                Spacer(modifier = Modifier.height(16.dp))
                
                TextButton(onClick = { viewModel.checkUnlockStatus() }) {
                    Text(
                        text = "Restore Purchase",
                        fontSize = 14.sp,
                        color = Color.White.copy(alpha = 0.8f)
                    )
                }
                
                Spacer(modifier = Modifier.height(40.dp))
            }
        }
    }
    
    // Error dialog
    error?.let { errorMessage ->
        LaunchedEffect(errorMessage) {
            // Show error - could use a Snackbar or AlertDialog
        }
    }
}

@Composable
private fun FeatureItem(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    description: String
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(28.dp),
            tint = Color.White
        )
        
        Column {
            Text(
                text = title,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )
            Text(
                text = description,
                fontSize = 13.sp,
                color = Color.White.copy(alpha = 0.8f)
            )
        }
    }
}

// MARK: - Invite Screen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InviteScreen(
    onDismiss: () -> Unit
) {
    val viewModel: UnlockViewModel = viewModel()
    val context = LocalContext.current
    
    val inviteCredits by viewModel.inviteCredits.collectAsState()
    val isInvited by viewModel.isInvited.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val currentInvite by viewModel.currentInvite.collectAsState()
    val error by viewModel.error.collectAsState()
    
    val primaryOrange = Color(0xFFFF6B35)
    
    LaunchedEffect(Unit) {
        viewModel.checkUnlockStatus()
    }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Share Wake Me Up") },
                navigationIcon = {
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, contentDescription = "Close")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(20.dp))
            
            // Header
            Icon(
                imageVector = Icons.Default.CardGiftcard,
                contentDescription = null,
                modifier = Modifier.size(60.dp),
                tint = primaryOrange
            )
            
            Spacer(modifier = Modifier.height(12.dp))
            
            Text(
                text = "Share Wake Me Up",
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold
            )
            
            Text(
                text = "Give your friends free lifetime access",
                fontSize = 14.sp,
                color = Color.Gray
            )
            
            Spacer(modifier = Modifier.height(24.dp))
            
            // Credits info
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .padding(16.dp),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "$inviteCredits",
                        fontSize = 36.sp,
                        fontWeight = FontWeight.Bold,
                        color = primaryOrange
                    )
                    Text(
                        text = "Invites Left",
                        fontSize = 12.sp,
                        color = Color.Gray
                    )
                }
                
                Box(
                    modifier = Modifier
                        .width(1.dp)
                        .height(40.dp)
                        .background(Color.Gray.copy(alpha = 0.3f))
                )
                
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = if (isInvited) "Yes" else "No",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.Gray
                    )
                    Text(
                        text = "Invited User",
                        fontSize = 12.sp,
                        color = Color.Gray
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(24.dp))
            
            when {
                isInvited -> {
                    // Invited users cannot create invites
                    InvitedUserInfo(
                        primaryOrange = primaryOrange,
                        onDismiss = onDismiss
                    )
                }
                inviteCredits > 0 || currentInvite != null -> {
                    if (currentInvite != null) {
                        // Show invite with QR code
                        InviteWithQR(
                            invite = currentInvite!!,
                            primaryOrange = primaryOrange,
                            onCreateNew = { viewModel.createInvite() },
                            hasMoreCredits = inviteCredits > 0
                        )
                    } else {
                        // Show create invite button
                        CreateInviteButton(
                            isLoading = isLoading,
                            primaryOrange = primaryOrange,
                            onClick = { viewModel.createInvite() }
                        )
                    }
                }
                else -> {
                    // No credits
                    NoCreditsInfo()
                }
            }
            
            Spacer(modifier = Modifier.height(24.dp))
            
            // How it works
            HowItWorksSection(primaryOrange)
            
            Spacer(modifier = Modifier.height(40.dp))
        }
    }
    
    // Error snackbar
    error?.let { errorMessage ->
        LaunchedEffect(errorMessage) {
            // Could show a Snackbar
            viewModel.clearError()
        }
    }
}

@Composable
private fun InvitedUserInfo(
    primaryOrange: Color,
    onDismiss: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Color.Blue.copy(alpha = 0.1f))
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = Icons.Default.Info,
            contentDescription = null,
            modifier = Modifier.size(40.dp),
            tint = Color.Blue
        )
        
        Spacer(modifier = Modifier.height(12.dp))
        
        Text(
            text = "You were invited!",
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Text(
            text = "Invited users receive full access but cannot create new invites. Upgrade to a paid account to share with more friends.",
            fontSize = 13.sp,
            color = Color.Gray,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun NoCreditsInfo() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Color(0xFFFFA500).copy(alpha = 0.1f))
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = Icons.Default.Warning,
            contentDescription = null,
            modifier = Modifier.size(40.dp),
            tint = Color(0xFFFFA500)
        )
        
        Spacer(modifier = Modifier.height(12.dp))
        
        Text(
            text = "No Invites Remaining",
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Text(
            text = "You've used all your invite credits. Thank you for sharing Wake Me Up!",
            fontSize = 13.sp,
            color = Color.Gray,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun CreateInviteButton(
    isLoading: Boolean,
    primaryOrange: Color,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .height(120.dp),
        shape = RoundedCornerShape(16.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = primaryOrange
        ),
        enabled = !isLoading
    ) {
        if (isLoading) {
            CircularProgressIndicator(color = Color.White)
        } else {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Icon(
                    imageVector = Icons.Default.QrCode,
                    contentDescription = null,
                    modifier = Modifier.size(28.dp)
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "Create Invite Code",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = "Generate a unique code for your friend",
                    fontSize = 12.sp,
                    color = Color.White.copy(alpha = 0.8f)
                )
            }
        }
    }
}

@Composable
private fun InviteWithQR(
    invite: UnlockRepository.UnlockInvite,
    primaryOrange: Color,
    onCreateNew: () -> Unit,
    hasMoreCredits: Boolean
) {
    val context = LocalContext.current
    
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // QR Code
        Column(
            modifier = Modifier
                .clip(RoundedCornerShape(16.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "Your Invite Code",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold
            )
            
            Spacer(modifier = Modifier.height(8.dp))
            
            Text(
                text = invite.code ?: "",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                color = primaryOrange
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // QR Code Image
            invite.inviteLink?.let { link ->
                val qrBitmap = remember(link) { generateQRCode(link) }
                qrBitmap?.let { bitmap ->
                    Image(
                        bitmap = bitmap.asImageBitmap(),
                        contentDescription = "QR Code",
                        modifier = Modifier
                            .size(200.dp)
                            .background(Color.White)
                            .padding(8.dp)
                    )
                }
            }
        }
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Invite link
        invite.inviteLink?.let { link ->
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .padding(12.dp)
            ) {
                Text(
                    text = "Invite Link",
                    fontSize = 12.sp,
                    color = Color.Gray
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = link,
                    fontSize = 12.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Action buttons
        Button(
            onClick = {
                val shareIntent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, "Join me on Wake Me Up! Use my invite code: ${invite.code}\n\n${invite.inviteLink}")
                }
                context.startActivity(Intent.createChooser(shareIntent, "Share Invite"))
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(50.dp),
            shape = RoundedCornerShape(12.dp),
            colors = ButtonDefaults.buttonColors(containerColor = primaryOrange)
        ) {
            Icon(Icons.Default.Share, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text("Share Invite")
        }
        
        Spacer(modifier = Modifier.height(12.dp))
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            OutlinedButton(
                onClick = {
                    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    val clip = ClipData.newPlainText("Invite Link", invite.inviteLink)
                    clipboard.setPrimaryClip(clip)
                },
                modifier = Modifier
                    .weight(1f)
                    .height(50.dp),
                shape = RoundedCornerShape(12.dp)
            ) {
                Icon(Icons.Default.ContentCopy, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("Copy Link")
            }
            
            OutlinedButton(
                onClick = onCreateNew,
                modifier = Modifier
                    .weight(1f)
                    .height(50.dp),
                shape = RoundedCornerShape(12.dp),
                enabled = hasMoreCredits
            ) {
                Icon(Icons.Default.Add, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("New Code")
            }
        }
    }
}

@Composable
private fun HowItWorksSection(primaryOrange: Color) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(20.dp)
    ) {
        Text(
            text = "How It Works",
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold
        )
        
        Spacer(modifier = Modifier.height(12.dp))
        
        HowItWorksStep(number = "1", text = "Share your unique invite code or link", primaryOrange)
        Spacer(modifier = Modifier.height(8.dp))
        HowItWorksStep(number = "2", text = "Your friend opens the link and downloads the app", primaryOrange)
        Spacer(modifier = Modifier.height(8.dp))
        HowItWorksStep(number = "3", text = "They get full lifetime access for free!", primaryOrange)
    }
}

@Composable
private fun HowItWorksStep(number: String, text: String, primaryOrange: Color) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text = "$number.",
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            color = primaryOrange
        )
        Text(
            text = text,
            fontSize = 13.sp,
            color = Color.Gray
        )
    }
}

// MARK: - QR Code Generator

private fun generateQRCode(content: String): Bitmap? {
    return try {
        val hints = mapOf(EncodeHintType.MARGIN to 1)
        val writer = QRCodeWriter()
        val bitMatrix = writer.encode(content, BarcodeFormat.QR_CODE, 512, 512, hints)
        
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
        
        Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).apply {
            setPixels(pixels, 0, width, 0, 0, width, height)
        }
    } catch (e: Exception) {
        null
    }
}

// MARK: - Redemption Screen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RedemptionScreen(
    inviteCode: String,
    onDismiss: () -> Unit
) {
    val viewModel: UnlockViewModel = viewModel()
    val isLoading by viewModel.isLoading.collectAsState()
    val redeemResult by viewModel.redeemResult.collectAsState()
    
    val primaryOrange = Color(0xFFFF6B35)
    
    LaunchedEffect(inviteCode) {
        viewModel.redeemInvite(inviteCode)
    }
    
    Scaffold { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(24.dp)
            ) {
                when {
                    isLoading -> {
                        CircularProgressIndicator(
                            color = primaryOrange,
                            modifier = Modifier.size(64.dp)
                        )
                        Text(
                            text = "Redeeming your invite...",
                            fontSize = 16.sp,
                            color = Color.Gray
                        )
                    }
                    redeemResult != null -> {
                        if (redeemResult!!.success) {
                            Icon(
                                imageVector = Icons.Default.CheckCircle,
                                contentDescription = null,
                                modifier = Modifier.size(80.dp),
                                tint = Color.Green
                            )
                            
                            Text(
                                text = "Welcome!",
                                fontSize = 24.sp,
                                fontWeight = FontWeight.Bold
                            )
                            
                            Text(
                                text = "You now have full lifetime access to Wake Me Up. Enjoy waking up your friends!",
                                fontSize = 14.sp,
                                color = Color.Gray,
                                textAlign = TextAlign.Center,
                                modifier = Modifier.padding(horizontal = 40.dp)
                            )
                            
                            Spacer(modifier = Modifier.height(16.dp))
                            
                            Button(
                                onClick = onDismiss,
                                modifier = Modifier
                                    .fillMaxWidth(0.7f)
                                    .height(50.dp),
                                shape = RoundedCornerShape(12.dp),
                                colors = ButtonDefaults.buttonColors(containerColor = primaryOrange)
                            ) {
                                Text("Get Started")
                            }
                        } else {
                            Icon(
                                imageVector = Icons.Default.Cancel,
                                contentDescription = null,
                                modifier = Modifier.size(80.dp),
                                tint = Color.Red
                            )
                            
                            Text(
                                text = "Oops!",
                                fontSize = 24.sp,
                                fontWeight = FontWeight.Bold
                            )
                            
                            Text(
                                text = redeemResult!!.error ?: "Something went wrong. Please try again.",
                                fontSize = 14.sp,
                                color = Color.Gray,
                                textAlign = TextAlign.Center,
                                modifier = Modifier.padding(horizontal = 40.dp)
                            )
                            
                            Spacer(modifier = Modifier.height(16.dp))
                            
                            Row(
                                modifier = Modifier.fillMaxWidth(0.9f),
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                Button(
                                    onClick = { viewModel.redeemInvite(inviteCode) },
                                    modifier = Modifier
                                        .weight(1f)
                                        .height(50.dp),
                                    shape = RoundedCornerShape(12.dp),
                                    colors = ButtonDefaults.buttonColors(containerColor = primaryOrange)
                                ) {
                                    Text("Try Again")
                                }
                                
                                OutlinedButton(
                                    onClick = onDismiss,
                                    modifier = Modifier
                                        .weight(1f)
                                        .height(50.dp),
                                    shape = RoundedCornerShape(12.dp)
                                ) {
                                    Text("Close")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}