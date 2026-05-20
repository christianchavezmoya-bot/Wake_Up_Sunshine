package com.wakeupsunshine.ui.auth

/**
 * Represents a country with its dial code for phone authentication
 */
data class Country(
    val code: String,
    val dialCode: String,
    val name: String,
    val flag: String
) {
    companion object {
        /**
         * Supported countries for phone authentication
         */
        val supported: List<Country> = listOf(
            Country(code = "AU", dialCode = "+61", name = "Australia", flag = "🇦🇺"),
            Country(code = "CL", dialCode = "+56", name = "Chile", flag = "🇨🇱"),
            Country(code = "US", dialCode = "+1", name = "United States", flag = "🇺🇸"),
            Country(code = "CA", dialCode = "+1", name = "Canada", flag = "🇨🇦")
        )

        /**
         * Default country (Australia)
         */
        val default: Country = supported.first { it.code == "AU" }
    }
}

/**
 * Phone validation and E.164 formatting utility
 */
object PhoneFormatter {

    /**
     * Validate phone number for a given country
     * @param digits Phone number digits only
     * @param country Selected country
     * @return ValidationResult with error message if invalid
     */
    fun validate(digits: String, country: Country): ValidationResult {
        if (digits.isEmpty()) {
            return ValidationResult.Error("Enter a phone number")
        }

        val (minLength, maxLength) = when (country.code) {
            "AU" -> 8 to 9      // Australian mobile: 04XXXXXXXX or 4XXXXXXXX
            "CL" -> 8 to 9      // Chile mobile: 9XXXXXXXX
            "US", "CA" -> 10 to 10  // US/Canada: 10 digits
            else -> 8 to 15
        }

        if (digits.length < minLength) {
            return ValidationResult.Error("Phone number looks too short")
        }

        if (digits.length > maxLength) {
            return ValidationResult.Error("Phone number is too long")
        }

        return ValidationResult.Valid
    }

    /**
     * Format phone number to E.164 standard
     * @param digits Phone number digits only
     * @param country Selected country
     * @return E.164 formatted string (e.g., +61412345678)
     */
    fun formatToE164(digits: String, country: Country): String {
        val dialCode = country.dialCode.removePrefix("+")

        val nationalNumber = when (country.code) {
            "AU", "CL" -> {
                // Remove leading 0 if present
                if (digits.startsWith("0")) digits.drop(1) else digits
            }
            else -> digits
        }

        return "+$dialCode$nationalNumber"
    }

    sealed class ValidationResult {
        object Valid : ValidationResult()
        data class Error(val message: String) : ValidationResult()
    }
}