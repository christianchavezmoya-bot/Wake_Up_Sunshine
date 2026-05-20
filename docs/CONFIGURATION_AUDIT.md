# Configuration Audit - Wake Up Sunshine

## Overview

This document summarizes all configuration values required across platforms.

---

## Supabase Configuration

### Project Details
| Value | Location | Status |
|-------|----------|--------|
| Project Ref | `jehouatjcfcxjjuowzbd` | ✅ Configured |
| Project URL | `https://jehouatjcfcxjjuowzbd.supabase.co` | ✅ In code |
| Anon Key | (public key in code) | ✅ In code |

### iOS Location
```
ios/WakeUpSunshine/Services/SupabaseManager.swift
```

```swift
private let supabaseURL = URL(string: "https://jehouatjcfcxjjuowzbd.supabase.co")!
private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

### Android Location
```
android/app/src/main/java/com/wakeupsunshine/SupabaseClient.kt
```
(Configure Supabase URL and anon key in this file)

### Edge Functions
| Function | Endpoint |
|----------|----------|
| Send Wake | `/functions/v1/send-wake` |
| Wake Response | `/functions/v1/wake-response` |
| Get Contacts | `/functions/v1/get-contacts` |
| Get History | `/functions/v1/get-history` |

---

## Firebase Configuration (Android Only)

### Required File
```
android/app/google-services.json
```

### Current Status: ⚠️ PLACEHOLDER

The file exists but contains placeholder values. Must be replaced with real Firebase config.

### How to Generate
1. Go to Firebase Console
2. Create project: `Wake Up Sunshine`
3. Add Android app with package: `com.wakeupsunshine.app`
4. Download `google-services.json`
5. Replace placeholder file

---

## Apple Push Notification Service (APNs) - iOS

### Required for Production
| Item | Where to Get |
|------|--------------|
| APNs Key (.p8) | Apple Developer > Keys |
| Key ID | Apple Developer Console |
| Team ID | Apple Developer Console |
| Critical Alerts | Apple Developer > Identifiers |

### Configuration
Configure in Supabase Dashboard:
- Go to Project Settings > Push Notifications
- Add APNs credentials

---

## Firebase Cloud Messaging (FCM) - Android

### Required for Production
| Item | Where to Get |
|------|--------------|
| Server Key | Firebase Console > Cloud Messaging |
| Sender ID | Firebase Console > Cloud Messaging |

### Configuration
Configure in Supabase Dashboard:
- Go to Project Settings > Push Notifications
- Add FCM credentials

---

## Bundle IDs / Package Names

| Platform | Identifier |
|----------|------------|
| iOS | `com.wakeupsunshine.app` |
| Android | `com.wakeupsunshine.app` |

---

## Required Secrets (Do NOT commit)

These values should be set via environment or secure storage:

| Secret | Description |
|--------|-------------|
| SUPABASE_ACCESS_TOKEN | For CLI access |
| APNS_KEY | .p8 key content |
| APNS_KEY_ID | Key identifier |
| APPLE_TEAM_ID | Apple Developer Team ID |
| FCM_SERVER_KEY | Firebase Cloud Messaging key |

---

## Environment Template

Create `.env.example` files as needed:

### iOS
No .env file needed - values are in code (Supabase URL and anon key are public).

### Android
No .env file needed - google-services.json handles config.

### Backend (Supabase Edge Functions)
May need environment secrets for:
- Push notification provider credentials
- Any third-party API keys

---

## Checklist

- [x] Supabase URL configured (iOS)
- [x] Supabase anon key configured (iOS)
- [ ] Supabase URL configured (Android) - verify in code
- [ ] Supabase anon key configured (Android) - verify in code
- [ ] Firebase project created
- [ ] google-services.json replaced with real config
- [ ] APNs key obtained
- [ ] APNs configured in Supabase
- [ ] FCM Server Key obtained
- [ ] FCM configured in Supabase
- [ ] Critical Alerts entitlement approved by Apple