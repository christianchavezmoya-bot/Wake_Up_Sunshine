package com.wakeupsunshine.ui.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities

/**
 * Email Authentication Screen
 * Primary login method for the app
 */
private fun isOffline(context: Context): Boolean {
    val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    val network = cm.activeNetwork ?: return true
    val caps = cm.getNetworkCapabilities(network) ?: return true
    return !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
}

@Composable
fun EmailAuthScreen(
    onSuccess: () -> Unit,
    onBack: () -> Unit,
    viewModel: AuthViewModel = hiltViewModel()
) {
    var email by remember { mutableStateOf("") }
    var displayName by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var isSignUp by remember { mutableStateOf(false) }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var showPassword by remember { mutableStateOf(false) }
    var showForgotPasswordDialog by remember { mutableStateOf(false) }
    var forgotPasswordEmail by remember { mutableStateOf("") }
    var isResettingPassword by remember { mutableStateOf(false) }
    var passwordResetSent by remember { mutableStateOf(false) }
    var isResendingVerification by remember { mutableStateOf(false) }
    var verificationResent by remember { mutableStateOf(false) }
    var showConfirmPassword by remember { mutableStateOf(false) }
    var signupPendingVerification by remember { mutableStateOf(false) }

    val context = androidx.compose.ui.platform.LocalContext.current
    val primaryOrange = Color(0xFFFF6B35)
    val backgroundColor = Color(0xFFFFF8F5)
    val surfaceColor = Color(0xFFFFFFFF)

    // Verification pending screen
    if (signupPendingVerification) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(backgroundColor)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Text("📧", fontSize = 64.sp)
                Spacer(modifier = Modifier.height(24.dp))
                Text(
                    text = "Check Your Email",
                    fontSize = 26.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center
                )
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = "We sent a confirmation link to",
                    fontSize = 14.sp,
                    color = Color.Gray,
                    textAlign = TextAlign.Center
                )
                Text(
                    text = email,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.Center
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "Click the link in the email to verify your account, then come back here to sign in.",
                    fontSize = 13.sp,
                    color = Color.Gray,
                    textAlign = TextAlign.Center
                )
                errorMessage?.let {
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(text = it, color = Color.Red, fontSize = 12.sp, textAlign = TextAlign.Center)
                }
                Spacer(modifier = Modifier.height(32.dp))
                Button(
                    onClick = {
                        if (email.isBlank() || !email.contains("@")) return@Button
                        isResendingVerification = true
                        viewModel.resendVerification(email.trim()) { success, err ->
                            isResendingVerification = false
                            if (success) verificationResent = true
                            else errorMessage = "Failed to resend: ${err ?: "Unknown error"}"
                        }
                    },
                    enabled = !isResendingVerification && !verificationResent,
                    modifier = Modifier.fillMaxWidth().height(50.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = primaryOrange),
                    shape = RoundedCornerShape(16.dp)
                ) {
                    if (isResendingVerification) {
                        CircularProgressIndicator(modifier = Modifier.size(24.dp), color = Color.White)
                    } else {
                        Text(
                            text = if (verificationResent) "Email Sent!" else "Resend Verification Email",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))
                TextButton(onClick = {
                    signupPendingVerification = false
                    isSignUp = false
                    errorMessage = null
                    verificationResent = false
                    confirmPassword = ""
                    displayName = ""
                }) {
                    Text("Back to Sign In", color = primaryOrange, fontWeight = FontWeight.SemiBold)
                }
            }
            TextButton(
                onClick = onBack,
                modifier = Modifier.align(Alignment.TopStart).padding(16.dp)
            ) {
                Text("Back", color = Color.Gray)
            }
        }
        return
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
                text = if (isSignUp) "Create Account" else "Welcome Back",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold
            )

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = if (isSignUp) "Sign up with your email to get started" else "Sign in with your email",
                fontSize = 14.sp,
                color = Color.Gray,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(32.dp))

            if (isSignUp) {
                OutlinedTextField(
                    value = displayName,
                    onValueChange = {
                        displayName = it
                        errorMessage = null
                    },
                    label = { Text("Name or Nickname") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(
                        unfocusedContainerColor = surfaceColor,
                        focusedContainerColor = surfaceColor
                    ),
                    shape = RoundedCornerShape(12.dp)
                )

                Spacer(modifier = Modifier.height(16.dp))
            }

            // Email field
            OutlinedTextField(
                value = email,
                onValueChange = { 
                    email = it
                    errorMessage = null
                },
                label = { Text("Email") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    unfocusedContainerColor = surfaceColor,
                    focusedContainerColor = surfaceColor
                ),
                shape = RoundedCornerShape(12.dp)
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Password field
            OutlinedTextField(
                value = password,
                onValueChange = { 
                    password = it
                    errorMessage = null
                },
                label = { Text("Password") },
                visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                singleLine = true,
                trailingIcon = {
                    TextButton(onClick = { showPassword = !showPassword }) {
                        Text(
                            text = if (showPassword) "Hide" else "Show",
                            color = Color.Gray,
                            fontSize = 12.sp
                        )
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    unfocusedContainerColor = surfaceColor,
                    focusedContainerColor = surfaceColor
                ),
                shape = RoundedCornerShape(12.dp)
            )

            // Forgot Password (sign in only)
            if (!isSignUp) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    Text(
                        text = "Forgot Password?",
                        color = primaryOrange,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        modifier = Modifier.clickable {
                            forgotPasswordEmail = email
                            passwordResetSent = false
                            errorMessage = null
                            showForgotPasswordDialog = true
                        }
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
            }

            // Confirm password (sign up only)
            if (isSignUp) {
                Spacer(modifier = Modifier.height(16.dp))

                OutlinedTextField(
                    value = confirmPassword,
                    onValueChange = { 
                        confirmPassword = it
                        errorMessage = null
                    },
                    label = { Text("Confirm Password") },
                    visualTransformation = if (showConfirmPassword) VisualTransformation.None else PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    singleLine = true,
                    trailingIcon = {
                        TextButton(onClick = { showConfirmPassword = !showConfirmPassword }) {
                            Text(
                                text = if (showConfirmPassword) "Hide" else "Show",
                                color = Color.Gray,
                                fontSize = 12.sp
                            )
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(
                        unfocusedContainerColor = surfaceColor,
                        focusedContainerColor = surfaceColor
                    ),
                    shape = RoundedCornerShape(12.dp)
                )
            }

            // Error message
            errorMessage?.let { error ->
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = error,
                    color = Color.Red,
                    fontSize = 12.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )

                // "Account already exists" → Switch to sign in + forgot password
                if (isSignUp && (error.contains("already registered", ignoreCase = true) || error.contains("already exists", ignoreCase = true) || error.contains("User already", ignoreCase = true))) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        horizontalArrangement = Arrangement.Center,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Already have an account? ", color = Color.Gray, fontSize = 13.sp)
                        Text(
                            text = "Sign In",
                            color = primaryOrange,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.clickable {
                                isSignUp = false
                                errorMessage = null
                                confirmPassword = ""
                                displayName = ""
                            }
                        )
                    }
                }

                // Wrong password on sign in → Forgot password link
                if (!isSignUp && (error.contains("Invalid login credentials", ignoreCase = true) || error.contains("invalid credentials", ignoreCase = true) || error.contains("wrong password", ignoreCase = true) || error.contains("incorrect", ignoreCase = true))) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Forgot your password?",
                        color = primaryOrange,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.clickable {
                            forgotPasswordEmail = email
                            passwordResetSent = false
                            errorMessage = null
                            showForgotPasswordDialog = true
                        }
                    )
                }

                // Resend verification button (shown after signup or sign-in when email needs confirmation)
                if (error.contains("verification", ignoreCase = true) || error.contains("confirm", ignoreCase = true) || error.contains("verify", ignoreCase = true)) {
                    Spacer(modifier = Modifier.height(8.dp))
                    TextButton(
                        onClick = {
                            if (email.isBlank() || !email.contains("@")) return@TextButton
                            isResendingVerification = true
                            viewModel.resendVerification(email.trim()) { success, err ->
                                isResendingVerification = false
                                if (success) {
                                    verificationResent = true
                                } else {
                                    errorMessage = "Failed to resend verification: ${err ?: "Unknown error"}"
                                }
                            }
                        },
                        enabled = !isResendingVerification && !verificationResent
                    ) {
                        if (isResendingVerification) {
                            CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                            Spacer(modifier = Modifier.width(4.dp))
                        }
                        Text(
                            text = if (verificationResent) "Verification email sent!" else "Resend Verification Email",
                            color = primaryOrange,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Primary button
            Button(
                onClick = {
                    if (isOffline(context)) {
                        errorMessage = "Make sure your phone is connected to the internet before you login or sign up"
                        return@Button
                    }

                    val error = validate(email, displayName, password, confirmPassword, isSignUp)
                    if (error != null) {
                        errorMessage = error
                        return@Button
                    }

                    isLoading = true
                    errorMessage = null

                    // Call auth
                    if (isSignUp) {
                        viewModel.signUp(email.trim(), password, displayName.trim()) { success, err ->
                            isLoading = false
                            if (success) {
                                onSuccess()
                            } else if (err?.contains("check email", ignoreCase = true) == true ||
                                       err?.contains("verification", ignoreCase = true) == true) {
                                signupPendingVerification = true
                            } else {
                                errorMessage = err ?: "Sign up failed"
                            }
                        }
                    } else {
                        viewModel.signIn(email.trim(), password) { success, err ->
                            isLoading = false
                            if (success) {
                                onSuccess()
                            } else {
                                errorMessage = err ?: "Sign in failed"
                            }
                        }
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp),
                enabled = !isLoading && email.isNotEmpty() && password.isNotEmpty() &&
                    if (isSignUp) confirmPassword.isNotEmpty() && displayName.trim().isNotEmpty() else true,
                colors = ButtonDefaults.buttonColors(containerColor = primaryOrange),
                shape = RoundedCornerShape(16.dp)
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp),
                        color = Color.White
                    )
                } else {
                    Text(
                        text = if (isSignUp) "Create Account" else "Sign In",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Toggle sign up / sign in
            Row(
                horizontalArrangement = Arrangement.Center
            ) {
                Text(
                    text = if (isSignUp) "Already have an account? " else "Don't have an account? ",
                    color = Color.Gray,
                    fontSize = 14.sp
                )
                Text(
                    text = if (isSignUp) "Sign In" else "Sign Up",
                    color = primaryOrange,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 14.sp,
                    modifier = Modifier.clickable {
                        isSignUp = !isSignUp
                        errorMessage = null
                        confirmPassword = ""
                        displayName = ""
                    }
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Divider
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth()
            ) {
                Divider(
                    modifier = Modifier.weight(1f),
                    color = Color.Gray.copy(alpha = 0.3f)
                )
                Text(
                    text = "  or  ",
                    color = Color.Gray,
                    fontSize = 12.sp
                )
                Divider(
                    modifier = Modifier.weight(1f),
                    color = Color.Gray.copy(alpha = 0.3f)
                )
            }

            Spacer(modifier = Modifier.weight(1f))
        }

        // Back button
        TextButton(
            onClick = onBack,
            modifier = Modifier.align(Alignment.TopStart).padding(16.dp)
        ) {
            Text("Back", color = Color.Gray)
        }
    }

    // Forgot Password Dialog
    if (showForgotPasswordDialog) {
        AlertDialog(
            onDismissRequest = {
                if (!isResettingPassword) {
                    showForgotPasswordDialog = false
                    passwordResetSent = false
                }
            },
            title = { Text("Reset Password") },
            text = {
                Column {
                    if (passwordResetSent) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Text("✓", color = Color(0xFF4CAF50), fontSize = 18.sp, fontWeight = FontWeight.Bold)
                            Text(
                                "Password reset email sent! Check your inbox.",
                                fontSize = 14.sp,
                                color = Color(0xFF4CAF50)
                            )
                        }
                    } else {
                        Text(
                            "Enter your email and we'll send you a link to reset your password.",
                            fontSize = 14.sp,
                            color = Color.Gray
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        OutlinedTextField(
                            value = forgotPasswordEmail,
                            onValueChange = { forgotPasswordEmail = it },
                            label = { Text("Email") },
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                            colors = OutlinedTextFieldDefaults.colors(
                                unfocusedContainerColor = surfaceColor,
                                focusedContainerColor = surfaceColor
                            ),
                            shape = RoundedCornerShape(12.dp)
                        )
                    }
                }
            },
            confirmButton = {
                if (passwordResetSent) {
                    TextButton(onClick = {
                        showForgotPasswordDialog = false
                        passwordResetSent = false
                    }) {
                        Text("Done", color = primaryOrange, fontWeight = FontWeight.Bold)
                    }
                } else {
                    TextButton(
                        onClick = {
                            if (forgotPasswordEmail.isBlank() || !forgotPasswordEmail.contains("@")) {
                                errorMessage = "Please enter a valid email address"
                                return@TextButton
                            }
                            isResettingPassword = true
                            errorMessage = null
                            viewModel.resetPassword(forgotPasswordEmail.trim()) { success, err ->
                                isResettingPassword = false
                                if (success) {
                                    passwordResetSent = true
                                } else {
                                    errorMessage = err ?: "Failed to send reset email"
                                }
                            }
                        },
                        enabled = !isResettingPassword && forgotPasswordEmail.isNotEmpty()
                    ) {
                        if (isResettingPassword) {
                            CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                        } else {
                            Text("Send Reset Link", color = primaryOrange, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            },
            dismissButton = {
                if (!passwordResetSent) {
                    TextButton(
                        onClick = { showForgotPasswordDialog = false },
                        enabled = !isResettingPassword
                    ) {
                        Text("Cancel", color = Color.Gray)
                    }
                }
            }
        )
    }
}

private fun validate(email: String, displayName: String, password: String, confirmPassword: String, isSignUp: Boolean): String? {
    // Email validation
    if (email.isEmpty()) {
        return "Email is required"
    }

    if (!email.contains("@") || !email.contains(".")) {
        return "Please enter a valid email address"
    }

    if (isSignUp && displayName.trim().isEmpty()) {
        return "Name or nickname is required"
    }

    // Password validation
    if (password.isEmpty()) {
        return "Password is required"
    }

    if (password.length < 6) {
        return "Password must be at least 6 characters"
    }

    // Confirm password (sign up only)
    if (isSignUp && password != confirmPassword) {
        return "Passwords do not match"
    }

    return null
}
