# Cross-Platform Sync Guide

## Overview

This document outlines how to keep iOS and Android apps synchronized in development and features.

##同步原则 (Sync Principles)

1. **Backend is the source of truth** - All business logic goes in Supabase Edge Functions
2. **API contracts are shared** - Both apps use the same endpoints
3. **Database schema is unified** - Same tables, same RLS policies
4. **Feature parity is mandatory** - New features must be implemented on both platforms

## Development Process

### When Adding a New Feature

1. **Design Phase**
   - Define API contract (Edge Function)
   - Update database schema if needed
   - Document payload structures

2. **Backend First**
   ```bash
   # Deploy edge function
   supabase functions deploy function-name

   # Apply migrations
   supabase db push
   ```

3. **iOS Implementation**
   - Create/update SwiftUI view
   - Add SupabaseManager API call
   - Test with iOS Simulator

4. **Android Implementation**
   - Create/update Compose screen
   - Add SupabaseClient API call
   - Test with Android Emulator

5. **Cross-Platform Verification**
   - iOS can send → Android receives ✓
   - Android can send → iOS receives ✓

## Shared Components

### 1. SupabaseManager (iOS) / SupabaseClient (Android)
Both provide the same functions:
- `getContacts(userId)` → Get trusted contacts
- `sendWakeRequest(targetUserId, message)` → Trigger wake
- `respondToWake(wakeRequestId, status)` → Acknowledge wake
- `getWakeHistory(userId)` → Get wake history

### 2. Push Notification Payload

Both apps expect:
```json
{
  "sender_id": "uuid",
  "sender_name": "John",
  "message": "Wake up!",
  "wake_request_id": "uuid",
  "timestamp": "ISO8601"
}
```

### 3. Database Tables

| Table | Purpose |
|-------|---------|
| users | User profiles |
| user_devices | Device registration (platform field) |
| wake_permissions | Trust relationships |
| wake_requests | Wake event records |
| wake_events | Status tracking |

## Version Compatibility

| iOS Version | Android Version | Backend Version |
|-------------|-----------------|-----------------|
| 1.0.0       | 1.0.0           | 1.0.0           |

When updating:
1. Test backward compatibility
2. Both apps should work with current backend
3. Old apps should work with new backend

## Troubleshooting

### iOS Push Not Working
- Check APNs certificate in Apple Developer Console
- Verify device token registration
- Check Critical Alerts entitlement

### Android Push Not Working
- Verify google-services.json is valid
- Check FCM server key in Firebase Console
- Ensure AndroidManifest.xml has correct permissions

### Cross-Platform Issues
- Verify both apps use same Supabase project
- Check Edge Function URLs match
- Test with same Edge Function version

## CI/CD (Future)

Automate builds with:
- GitHub Actions for iOS (requires Mac runner)
- GitHub Actions for Android (Linux runner)
- Shared test suite for API compatibility