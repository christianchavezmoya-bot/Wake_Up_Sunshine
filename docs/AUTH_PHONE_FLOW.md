# Phone Authentication Flow Documentation

**Updated:** Fri Apr 24 08:51 AEST 2026

---

## Overview

Wake Up Sunshine uses phone number authentication via Supabase OTP (One-Time Password).

---

## Supported Country Codes

| Country | Code | Dial Code | Example Input | E.164 Output |
|---------|------|-----------|---------------|--------------|
| Australia | AU | +61 | 0412 345 678 | +61412345678 |
| Chile | CL | +56 | 9 1234 5678 | +56912345678 |
| United States | US | +1 | 5551234567 | +15551234567 |
| Canada | CA | +1 | 5551234567 | +15551234567 |

**Default Country:** Australia (+61)

---

## E.164 Formatting

Phone numbers are normalized to E.164 format before sending to Supabase:

1. Remove all non-digit characters (spaces, hyphens, brackets)
2. Remove leading `0` for AU/CL mobile numbers
3. Prepend country code

### Examples

| Input | Country | Output |
|-------|---------|--------|
| 0412 345 678 | AU (+61) | +61412345678 |
| 412345678 | AU (+61) | +61412345678 |
| 9 1234 5678 | CL (+56) | +56912345678 |
| 5551234567 | US (+1) | +15551234567 |

---

## Authentication Flow

```
┌─────────────────┐
│  Login Screen   │
│  - Country Code │
│  - Phone Number │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Validation    │
│  - Not empty    │
│  - Valid length │
│  - Digits only  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Format E.164  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Send OTP API   │
│  (Supabase)     │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
 Success    Error
    │         │
    ▼         ▼
┌─────────┐ ┌─────────┐
│ OTP     │ │ Stay on │
│ Screen  │ │ Login   │
└────┬────┘ │ Show    │
     │      │ Error   │
     ▼      └─────────┘
┌─────────┐
│ Verify  │
│ OTP     │
└────┬────┘
     │
┌────┴────┐
│         │
▼         ▼
Success  Error
│         │
▼         ▼
┌─────┐ ┌─────────┐
│Home │ │ Show    │
│     │ │ Error   │
└─────┘ └─────────┘
```

---

## Error Handling

### Validation Errors (shown inline)

- **Empty number:** "Enter a phone number"
- **Too short:** "Phone number looks too short"
- **Too long:** "Phone number is too long"
- **Invalid characters:** "Use numbers only"

### API Errors

- **OTP send failure:** Display error message, stay on login screen
- **OTP verify failure:** Display "Invalid code. Please try again."
- **Network error:** Display error message

**IMPORTANT:** Never silently navigate back to Welcome screen after an error.

---

## Platform Implementation

### iOS

- **File:** `ios/WakeUpSunshine/Features/Onboarding/LoginView.swift`
- **Service:** `ios/WakeUpSunshine/Services/AuthManager.swift`
- **Country Model:** Embedded in `LoginView.swift`

### Android

- **File:** `android/app/src/main/kotlin/com/wakeupsunshine/ui/auth/LoginScreen.kt`
- **OTP Screen:** `android/app/src/main/kotlin/com/wakeupsunshine/ui/auth/OTPVerificationScreen.kt`
- **ViewModel:** `android/app/src/main/kotlin/com/wakeupsunshine/ui/auth/AuthViewModel.kt`
- **Country Model:** `android/app/src/main/kotlin/com/wakeupsunshine/ui/auth/Country.kt`
- **Repository:** `android/app/src/main/kotlin/com/wakeupsunshine/data/AuthRepository.kt`

---

## Testing Checklist

### iOS

- [ ] Select Australia +61
- [ ] Enter 0412 345 678
- [ ] Confirm normalized number becomes +61412345678
- [ ] OTP screen opens
- [ ] App does NOT jump back to Welcome screen on error
- [ ] Try Chile +56 with 9 1234 5678
- [ ] Try US +1 with 10-digit number
- [ ] Try invalid short number - confirm inline error

### Android

- [ ] Select Australia +61
- [ ] Enter 0412 345 678
- [ ] Confirm normalized number becomes +61412345678
- [ ] OTP screen opens
- [ ] App does NOT jump back to Welcome screen on error
- [ ] Try Chile +56
- [ ] Try US +1
- [ ] Try invalid short number - confirm inline error

---

## Supabase Configuration

### Required Settings

1. **Phone Auth Enabled:** Dashboard → Authentication → Providers → Phone
2. **SMS Provider:** Twilio, MessageBird, or Vonage configured
3. **OTP Expiry:** Default 60 seconds (configurable)

### Twilio Setup (Recommended)

1. Create Twilio account
2. Purchase SMS-enabled phone number
3. Configure in Supabase Dashboard:
   - Account SID
   - Auth Token
   - From Number

---

## Security Notes

- OTP codes expire after 60 seconds by default
- Rate limiting is handled by Supabase
- Phone numbers are stored in E.164 format in the database
- Never log OTP codes in production