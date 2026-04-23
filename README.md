# Wake Up Sunshine

A **cross-platform trusted-person alarm system** that allows one user to trigger a guaranteed wake-up alarm on another user's phone, even when the phone is on silent or Do Not Disturb is enabled.

## Features

- **Guaranteed Wake-Up** - Critical Alerts (iOS) / Full-Screen Intent (Android) override silent mode
- **Permission-Based** - Only trusted contacts can wake you
- **Real-Time Status** - See when your wake alert is delivered and confirmed
- **Cross-Platform** - Works on iOS and Android
- **Privacy Focused** - No data sharing, all permissions are explicit

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SYSTEM OVERVIEW                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  SENDER                    BACKEND                 RECEIVER  │
│  ┌─────────┐              ┌─────────┐            ┌────────┐ │
│  │  App    │──POST /wake──▶│ Supabase│────────────▶│  App   │ │
│  │  (iOS/  │◀─status──────│ + Edge  │◀──ack──────│(iOS/   │ │
│  │ Android)│              │ Functions│            │Android)│ │
│  └─────────┘              └─────────┘            └────────┘ │
│                                                             │
│  PUSH DELIVERY:                                            │
│  • iOS → APNs (Apple Push Notification Service)            │
│  • Android → FCM (Firebase Cloud Messaging)                │
│                                                             │
│  KEY COMPONENTS:                                            │
│  • Supabase (Auth, Database, Realtime)                      │
│  • APNs for iOS / FCM for Android                          │
│  • Critical Alerts Entitlement (iOS)                       │
│  • Full-Screen Intent (Android)                            │
│  • Row Level Security (RLS)                                 │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
Wake_Up_Sunshine/
├── ios/                          # iOS App (SwiftUI)
│   ├── WakeUpSunshine/
│   │   ├── App/                  # App entry point
│   │   ├── Features/             # Screen modules
│   │   │   ├── Onboarding/       # Sign-up flow
│   │   │   ├── Home/             # Main screen
│   │   │   ├── Contacts/         # Permission management
│   │   │   ├── History/          # Wake history
│   │   │   ├── Settings/         # User settings
│   │   │   └── WakeAlert/        # Alarm screen
│   │   ├── Services/             # API & Push managers
│   │   └── Shared/               # Extensions & utilities
│   └── project.yml               # XcodeGen configuration
│
├── android/                      # Android App (Kotlin + Jetpack Compose)
│   ├── app/
│   │   └── src/main/
│   │       ├── kotlin/com/wakeupsunshine/
│   │       │   ├── data/         # Supabase client
│   │       │   ├── service/     # FCM messaging service
│   │       │   ├── receiver/    # Boot & alarm receivers
│   │       │   └── ui/          # Compose screens
│   │       ├── res/             # Resources
│   │       └── AndroidManifest.xml
│   └── build.gradle
│
├── backend/                      # Supabase Backend
│   ├── supabase/
│   │   ├── migrations/           # Database schema
│   │   └── functions/            # Edge functions
│   │       ├── send-wake/        # Trigger wake alert
│   │       ├── wake-response/    # Handle response
│   │       ├── get-contacts/     # Fetch contacts
│   │       └── get-history/       # Fetch history
│   └── README.md                 # Backend setup
│
├── docs/                         # Documentation
│   ├── API.md                    # API documentation
│   ├── SPEC.md                   # Design specification
│   └── CROSS_PLATFORM_SYNC.md    # iOS/Android sync guide
│
└── README.md                     # This file
```

## Getting Started

### Prerequisites

| Platform | Requirements |
|----------|--------------|
| **iOS** | Xcode 15+, Apple Developer Account (for Critical Alerts), APNs Certificate |
| **Android** | Android Studio Hedgehog+, Firebase Project, google-services.json |
| **Backend** | Node.js 18+, Supabase CLI, Supabase Account |

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/christianchavezmoya-bot/Wake_Up_Sunshine.git
   cd Wake_Up_Sunshine
   ```

2. **Setup iOS app**
   ```bash
   cd ios
   xcodegen generate
   open WakeUpSunshine.xcodeproj
   ```

3. **Setup Android app**
   ```bash
   cd android
   # Add your google-services.json from Firebase Console first!
   ./gradlew assembleDebug
   ```

4. **Setup Supabase backend**
   ```bash
   cd backend
   supabase login
   supabase link --project-ref jehouatjcfcxjjuowzbd
   supabase db push
   ```

### Platform-Specific Setup

#### iOS Critical Alerts
1. Request Critical Alerts entitlement from Apple Developer
2. Configure in Xcode: Capabilities → Push Notifications → Critical Alerts
3. Use `UNNotificationAuthorizationOptions.criticalAlert` when requesting permission

#### Android Firebase
1. Create Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add Android app with package name: `com.wakeupsunshine.app`
3. Download `google-services.json` and place in `android/app/`
4. Enable FCM in Firebase Console

### Supabase Configuration

**Project URL:** `https://jehouatjcfcxjjuowzbd.supabase.co`

**Edge Functions Deployed:**
| Function | URL |
|----------|-----|
| send-wake | `https://jehouatjcfcxjjuowzbd.supabase.co/functions/v1/send-wake` |
| wake-response | `https://jehouatjcfcxjjuowzbd.supabase.co/functions/v1/wake-response` |
| get-contacts | `https://jehouatjcfcxjjuowzbd.supabase.co/functions/v1/get-contacts` |
| get-history | `https://jehouatjcfcxjjuowzbd.supabase.co/functions/v1/get-history` |

**Database Tables:**
- `users` - User accounts with phone numbers
- `user_devices` - Registered devices with push tokens
- `wake_permissions` - Trust relationships between users
- `wake_requests` - Wake alert records
- `rate_limits` - Anti-abuse protection

**RLS Policies:** All tables have Row Level Security enabled with proper access control.

## Backend

### Database Schema

- `users` - User accounts with phone numbers
- `user_devices` - Registered devices with push tokens
- `wake_permissions` - Trust relationships between users
- `wake_requests` - Wake alert records
- `rate_limits` - Anti-abuse protection

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/wake` | POST | Send a wake alert |
| `/wake/:id/confirm` | POST | Confirm you're awake |
| `/wake/:id/snooze` | POST | Snooze the alarm |
| `/contacts` | GET | List trusted contacts |
| `/history` | GET | Wake history |

## iOS App

### Features

- **Onboarding Flow** - 5-step sign-up with permissions
- **Home Screen** - Grid of trusted contacts with wake buttons
- **Wake Alert** - Full-screen alarm with confirm/snooze
- **History** - Timeline of past wake alerts
- **Settings** - Profile, devices, notification preferences

### Critical Alerts Setup

1. Request Critical Alerts entitlement from Apple
2. Configure in Xcode Capabilities
3. Use `UNNotificationAuthorizationOptions.criticalAlert`

## Android App

### Features

- **Wake Alarm Screen** - Full-screen alarm with dismiss/snooze
- **FCM Messaging** - Firebase Cloud Messaging integration
- **Notification Channels** - High-priority channel for wake alarms
- **Boot Receiver** - Reschedules alarms after reboot

### Key Components

| Component | Purpose |
|-----------|---------|
| `WakeMessagingService` | Handles FCM push notifications |
| `AlarmActivity` | Full-screen alarm display |
| `BootReceiver` | Reschedules after device boot |
| `NotificationChannel` | Bypasses Do Not Disturb |

### Android Permissions

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

## Security

- Row Level Security (RLS) on all tables
- Token-based authentication via Supabase Auth
- Rate limiting (10 requests/day, 30 min cooldown)
- Permission-based access control

## License

MIT License - See LICENSE file for details

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Support

For issues and questions, please open a GitHub issue.