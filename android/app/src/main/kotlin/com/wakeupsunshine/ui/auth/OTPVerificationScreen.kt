package com.wakeupsunshine.ui.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities

private fun isOffline(context: Context): Boolean {
    val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    val network = cm.activeNetwork ?: return true
    val caps = cm.getNetworkCapabilities(network) ?: return true
    return !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
}

/**
 * OTP Verification Screen
 */
@Composable
fun OTPVerificationScreen(
    phoneNumber: String,
    country: Country,
    onVerified: () -> Unit,
    onBack: () -> Unit,
    viewModel: AuthViewModel = hiltViewModel()
) {
    var otpDigits by remember { mutableStateOf(List(6) { "" }) }
    var isLoading by remember { mutableStateOf(false) }
    var isVerified by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var countdown by remember { mutableStateOf(60) }

    val context = androidx.compose.ui.platform.LocalContext.current
    val primaryOrange = Color(0xFFFF6B35)
    val backgroundColor = Color(0xFFFFF8F5)

    // Countdown timer
    LaunchedEffect(Unit) {
        while (countdown > 0) {
            kotlinx.coroutines.delay(1000)
            countdown--
        }
    }

    // Navigate on verified
    LaunchedEffect(isVerified) {
        if (isVerified) {
            kotlinx.coroutines.delay(500)
            onVerified()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(backgroundColor)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(40.dp))

            // Title
            Text(
                text = "Verify Your Phone",
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold
            )

            Spacer(modifier = Modifier.height(12.dp))

            Text(
                text = "Enter the 6-digit code sent to\n$phoneNumber",
                fontSize = 14.sp,
                color = Color.Gray,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(32.dp))

            // OTP digit inputs
            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                otpDigits.forEachIndexed { index, digit ->
                    OutlinedTextField(
                        value = digit,
                        onValueChange = { newValue ->
                            // Only allow single digit
                            if (newValue.length <= 1 && newValue.all { it.isDigit() }) {
                                otpDigits = otpDigits.toMutableList().apply {
                                    this[index] = newValue
                                }
                                errorMessage = null
                            }
                        },
                        modifier = Modifier
                            .width(48.dp)
                            .height(56.dp),
                        textStyle = androidx.compose.ui.text.TextStyle(
                            textAlign = TextAlign.Center,
                            fontSize = 20.sp,
                            fontWeight = FontWeight.SemiBold
                        ),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = if (digit.isEmpty()) Color.Gray.copy(alpha = 0.3f) else primaryOrange,
                            unfocusedBorderColor = if (digit.isEmpty()) Color.Gray.copy(alpha = 0.3f) else primaryOrange
                        ),
                        shape = RoundedCornerShape(12.dp)
                    )
                }
            }

            // Error message
            errorMessage?.let { error ->
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = error,
                    color = Color.Red,
                    fontSize = 12.sp,
                    textAlign = TextAlign.Center
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Resend countdown
            Row {
                Text(
                    text = "Resend code in ",
                    color = Color.Gray,
                    fontSize = 14.sp
                )
                Text(
                    text = "${countdown}s",
                    color = primaryOrange,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 14.sp
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Verify button
            Button(
                onClick = {
                    if (isOffline(context)) {
                        errorMessage = "No internet connection. Please check your network and try again."
                        return@Button
                    }
                    val otp = otpDigits.joinToString("")
                    if (otp.length != 6) {
                        errorMessage = "Enter all 6 digits"
                        return@Button
                    }

                    isLoading = true
                    errorMessage = null

                    // Call verify OTP
                    // viewModel.verifyOTP(phoneNumber, otp) { success, error ->
                    //     isLoading = false
                    //     if (success) {
                    //         isVerified = true
                    //     } else {
                    //         errorMessage = error ?: "Invalid code. Please try again."
                    //     }
                    // }

                    // For now, simulate success
                    isVerified = true
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp),
                enabled = !isLoading && !isVerified,
                colors = ButtonDefaults.buttonColors(containerColor = primaryOrange),
                shape = RoundedCornerShape(16.dp)
            ) {
                when {
                    isLoading -> {
                        CircularProgressIndicator(
                            modifier = Modifier.size(24.dp),
                            color = Color.White
                        )
                    }
                    isVerified -> {
                        Text("✓", fontSize = 20.sp)
                    }
                    else -> {
                        Text("Verify", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }

            Spacer(modifier = Modifier.weight(1f))
        }

        // Back/Cancel button
        TextButton(
            onClick = onBack,
            modifier = Modifier.align(Alignment.TopStart).padding(16.dp)
        ) {
            Text("Cancel", color = Color.Gray)
        }
    }
}