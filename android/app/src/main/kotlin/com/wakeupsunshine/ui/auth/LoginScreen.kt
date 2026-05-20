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
import androidx.compose.ui.graphics.Brush
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
import kotlinx.coroutines.launch

private fun isOffline(context: Context): Boolean {
    val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    val network = cm.activeNetwork ?: return true
    val caps = cm.getNetworkCapabilities(network) ?: return true
    return !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
}

/**
 * Login Screen with phone number entry and country selector
 */
@Composable
fun LoginScreen(
    onOTPRequested: (String, Country) -> Unit,
    viewModel: AuthViewModel = hiltViewModel()
) {
    var phoneNumber by remember { mutableStateOf("") }
    var selectedCountry by remember { mutableStateOf(Country.default) }
    var showCountryPicker by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var isLoading by remember { mutableStateOf(false) }

    val context = androidx.compose.ui.platform.LocalContext.current
    val primaryOrange = Color(0xFFFF6B35)
    val primaryOrangeLight = Color(0xFFFF9F7F)
    val backgroundColor = Color(0xFFFFF8F5)
    val surfaceColor = Color(0xFFFFFFFF)

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
            Spacer(modifier = Modifier.weight(1f))

            // Logo
            Box(
                modifier = Modifier
                    .size(100.dp)
                    .background(
                        Brush.linearGradient(
                            colors = listOf(primaryOrange, primaryOrangeLight)
                        ),
                        RoundedCornerShape(50.dp)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "☀️",
                    fontSize = 50.sp
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            Text(
                text = "Wake Up Sunshine",
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold
            )

            Spacer(modifier = Modifier.height(32.dp))

            // Welcome text
            Text(
                text = "Welcome Back",
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold
            )

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = "Enter your phone number to sign in",
                fontSize = 14.sp,
                color = Color.Gray
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Phone input row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Country selector button
                Box(
                    modifier = Modifier
                        .clickable { showCountryPicker = true }
                        .background(surfaceColor, RoundedCornerShape(12.dp))
                        .padding(horizontal = 12.dp, vertical = 14.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = selectedCountry.flag,
                            fontSize = 20.sp
                        )
                        Text(
                            text = selectedCountry.dialCode,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium
                        )
                        Text(
                            text = "▼",
                            fontSize = 10.sp,
                            color = Color.Gray
                        )
                    }
                }

                // Phone number input
                OutlinedTextField(
                    value = phoneNumber,
                    onValueChange = { newValue ->
                        // Only allow digits
                        phoneNumber = newValue.filter { it.isDigit() }
                        errorMessage = null
                    },
                    placeholder = { Text("Phone number") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                    colors = OutlinedTextFieldDefaults.colors(
                        unfocusedContainerColor = surfaceColor,
                        focusedContainerColor = surfaceColor
                    ),
                    shape = RoundedCornerShape(12.dp)
                )
            }

            // Error message
            errorMessage?.let { error ->
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = error,
                    color = Color.Red,
                    fontSize = 12.sp,
                    modifier = Modifier.fillMaxWidth()
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Continue button
            Button(
                onClick = {
                    if (isOffline(context)) {
                        errorMessage = "Make sure your phone is connected to the internet before you sign in"
                        return@Button
                    }
                    val validation = PhoneFormatter.validate(phoneNumber, selectedCountry)
                    when (validation) {
                        is PhoneFormatter.ValidationResult.Error -> {
                            errorMessage = validation.message
                        }
                        is PhoneFormatter.ValidationResult.Valid -> {
                            val formattedPhone = PhoneFormatter.formatToE164(
                                phoneNumber,
                                selectedCountry
                            )
                            onOTPRequested(formattedPhone, selectedCountry)
                        }
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp),
                enabled = phoneNumber.isNotEmpty() && !isLoading,
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (phoneNumber.isEmpty()) Color.Gray else primaryOrange
                ),
                shape = RoundedCornerShape(16.dp)
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp),
                        color = Color.White
                    )
                } else {
                    Text("Continue", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            // Terms text
            LegalDisclaimer(
                modifier = Modifier.padding(bottom = 16.dp)
            )
        }

        // Country picker bottom sheet
        if (showCountryPicker) {
            CountryPickerSheet(
                selectedCountry = selectedCountry,
                onCountrySelected = { country ->
                    selectedCountry = country
                    showCountryPicker = false
                },
                onDismiss = { showCountryPicker = false }
            )
        }
    }
}

/**
 * Country picker bottom sheet
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CountryPickerSheet(
    selectedCountry: Country,
    onCountrySelected: (Country) -> Unit,
    onDismiss: () -> Unit
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss
    ) {
        Column(
            modifier = Modifier.padding(vertical = 16.dp)
        ) {
            Text(
                text = "Select Country",
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp)
            )

            Country.supported.forEach { country ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onCountrySelected(country) }
                        .padding(horizontal = 24.dp, vertical = 16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = country.flag,
                        fontSize = 24.sp
                    )
                    Spacer(modifier = Modifier.width(16.dp))
                    Text(
                        text = country.name,
                        fontSize = 16.sp,
                        modifier = Modifier.weight(1f)
                    )
                    Text(
                        text = country.dialCode,
                        fontSize = 16.sp,
                        color = Color.Gray
                    )
                    if (country.code == selectedCountry.code) {
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "✓",
                            fontSize = 16.sp,
                            color = Color(0xFFFF6B35)
                        )
                    }
                }
            }
        }
    }
}
