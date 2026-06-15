# Email Authentication Setup Guide

**Updated:** Fri Apr 24 09:12 AEST 2026

---

## Overview

Email authentication is now the **primary login method** for Wake Up Sunshine. Phone authentication remains available as an optional secondary method.

---

## Supabase Dashboard Setup

### 1. Enable Email Provider

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Navigate to **Authentication → Providers**
4. Find **Email** provider
5. Enable it (should be enabled by default)

### 2. Configure Email Settings

| Setting | Recommended Value |
|---------|-------------------|
| Enable Email Confirmations | ON (production) / OFF (testing) |
| Secure Email Change | ON |
| Secure Password Change | ON |

### 3. Email Confirmation (Testing)

**For development/testing**, you may want to disable email confirmation:

1. Go to **Authentication → Providers → Email**
2. Toggle OFF "Confirm email"
3. Users can sign in immediately without email verification

**⚠️ Important:** Re-enable email confirmation for production!

### 4. Email Templates (Optional)

Customize email templates in **Authentication → Email Templates**:
- Confirmation email
- Magic link email
- Reset password email

---

## User Flow

```
┌─────────────────┐
│  Welcome Screen │
│  - Email (Primary)
│  - Phone (Optional)
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
 Email      Phone
    │         │
    ▼         ▼
┌─────────┐ ┌─────────┐
│EmailAuth│ │PhoneAuth│
│ Screen  │ │ Screen  │
└────┬────┘ └────┬────┘
     │           │
     ▼           ▼
┌─────────────────┐
│   Supabase Auth │
│   - Sign Up     │
│   - Sign In     │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
 Success    Error
    │         │
    ▼         ▼
┌─────────┐ ┌─────────┐
│ Home    │ │ Stay on │
│ Screen  │ │ Screen  │
│         │ │ Show    │
│         │ │ Error   │
└─────────┘ └─────────┘
```

---

## Validation Rules

### Email
- Required field
- Must contain `@` and `.`
- Valid email format

### Password
- Required field
- Minimum 6 characters
- Maximum 72 characters (Supabase limit)

### Confirm Password (Sign Up only)
- Must match password field

---

## Error Handling

| Error | User Message |
|-------|--------------|
| Empty email | "Email is required" |
| Invalid email format | "Please enter a valid email address" |
| Empty password | "Password is required" |
| Password too short | "Password must be at least 6 characters" |
| Passwords don't match | "Passwords do not match" |
| Email already exists | "An account with this email already exists" |
| Invalid credentials | "Invalid email or password" |
| Email not confirmed | "Please check your email to confirm your account" |

**Important:** 
- Never silently navigate away on error
- Stay on login screen and show clear error message
- Do not fake successful authentication

---

## Session Persistence

### iOS
Session is automatically persisted by Supabase Swift SDK.

```swift
// Check session on app launch
await authManager.checkSession()

// User stays logged in across app restarts
```

### Android
Session is automatically persisted by Supabase Kotlin SDK.

```kotlin
// Check session on app launch
viewModel.checkAuthState()

// User stays logged in across app restarts
```

---

## Sign Out Flow

1. User taps "Sign Out" in settings/profile
2. Call `authManager.signOut()` (iOS) or `viewModel.signOut()` (Android)
3. Clear local session
4. Navigate to Welcome screen

---

## Test Users

### Creating Test Users

1. **Via App:**
   - Use "Sign Up" with test email
   - Use password: `test123456` (6+ chars)

2. **Via Supabase Dashboard:**
   - Go to Authentication → Users
   - Click "Add User"
   - Enter email and password

### Test Checklist

#### iOS
- [ ] Sign up with new email
- [ ] Check email confirmation (if enabled)
- [ ] Sign in with existing email
- [ ] Sign out
- [ ] Sign in again
- [ ] Close app, reopen - session persists
- [ ] Try invalid email format - shows error
- [ ] Try short password - shows error
- [ ] Try wrong password - shows error
- [ ] Phone auth still accessible

#### Android
- [ ] Sign up with new email
- [ ] Check email confirmation (if enabled)
- [ ] Sign in with existing email
- [ ] Sign out
- [ ] Sign in again
- [ ] Close app, reopen - session persists
- [ ] Try invalid email format - shows error
- [ ] Try short password - shows error
- [ ] Try wrong password - shows error
- [ ] Phone auth still accessible

---

## Known Limitations

1. **Email Confirmation:** If enabled, users must click the link in their email before signing in
2. **Password Reset:** Not yet implemented (requires separate screen)
3. **Magic Link:** Not implemented (email-only passwordless login)
4. **Social Login:** Not implemented (Google, Apple, etc.)

---

## Implementation Files

### iOS
| File | Purpose |
|------|---------|
| `ios/WakeUpSunshine/Features/Onboarding/EmailAuthView.swift` | Email login UI |
| `ios/WakeUpSunshine/Features/Onboarding/OnboardingFlowView.swift` | Auth flow navigation |
| `ios/WakeUpSunshine/Services/AuthManager.swift` | Supabase auth integration |

### Android
| File | Purpose |
|------|---------|
| `android/app/src/main/kotlin/com/wakeupsunshine/ui/auth/EmailAuthScreen.kt` | Email login UI |
| `android/app/src/main/kotlin/com/wakeupsunshine/ui/auth/AuthViewModel.kt` | Auth state management |
| `android/app/src/main/kotlin/com/wakeupsunshine/data/AuthRepository.kt` | Supabase auth integration |

---

## Security Notes

- Passwords are never logged or stored locally
- All auth requests use HTTPS
- Session tokens are securely stored by Supabase SDK
- Email addresses are validated before submission