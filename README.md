# Wake Up Sunshine

A trusted-person alarm system that allows one user to trigger a guaranteed wake-up alarm on another user's phone, even when the phone is on silent or Do Not Disturb is enabled.

## Features

- **Guaranteed Wake-Up** - Critical Alerts ensure the alarm plays even on silent mode
- **Permission-Based** - Only trusted contacts can wake you
- **Real-Time Status** - See when your wake alert is delivered and confirmed
- **Multi-Device Support** - Works across iPhone, iPad, and Apple Watch
- **Privacy Focused** - No data sharing, all permissions are explicit

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SYSTEM OVERVIEW                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  SENDER                    BACKEND                 RECEIVER  │
│  ┌─────────┐              ┌─────────┐            ┌────────┐ │
│  │  App    │──POST /wake──▶│ Supabase│───APNs────▶│  App   │ │
│  │  UI     │◀─status──────│ + Edge  │◀──ack─────│  Alarm │ │
│  └─────────┘              │ Functions│            └────────┘ │
│                            └─────────┘                       │
│                                                             │
│  KEY COMPONENTS:                                            │
│  • Supabase (Auth, Database, Realtime)                       │
│  • Apple Push Notification Service (APNs)                   │
│  • Critical Alerts Entitlement                              │
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
│   └── SPEC.md                   # Design specification
│
└── README.md                     # This file
```

## Getting Started

### Prerequisites

- Xcode 15+
- XcodeGen (`brew install xcodegen`)
- Node.js 18+ (for Supabase CLI)
- Supabase account
- Apple Developer Account (for Critical Alerts)

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

3. **Setup Supabase backend**
   ```bash
   cd backend
   supabase login
   supabase link --project-ref YOUR_PROJECT_REF
   supabase db push
   ```

4. **Configure environment variables**
   - Copy `.env.example` to `.env`
   - Fill in your Supabase and Apple credentials

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

- **Onboarding Flow** - 6-step sign-up with permissions
- **Home Screen** - Grid of trusted contacts with wake buttons
- **Wake Alert** - Full-screen alarm with confirm/snooze
- **History** - Timeline of past wake alerts
- **Settings** - Profile, devices, notification preferences

### Critical Alerts Setup

1. Request Critical Alerts entitlement from Apple
2. Configure in Xcode Capabilities
3. Use `UNNotificationAuthorizationOptions.criticalAlert`

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