# Diagnostics and Debugging Guide

This guide explains how to use the debug instrumentation added to Wake Up Sunshine for troubleshooting issues across iOS, Android, and Supabase backend.

---

## Table of Contents

1. [Overview](#overview)
2. [Accessing Diagnostics](#accessing-diagnostics)
3. [Trace IDs](#trace-ids)
4. [Debug Events Table](#debug-events-table)
5. [iOS Debugging](#ios-debugging)
6. [Android Debugging](#android-debugging)
7. [Backend Debugging](#backend-debugging)
8. [Common Issues](#common-issues)
9. [SQL Queries](#sql-queries)

---

## Overview

The Wake Up Sunshine app now includes comprehensive debugging tools:

- **Trace IDs** - Every wake request has a unique ID that flows through the entire system
- **Debug Events Table** - Backend stores debug events for analysis
- **Diagnostics Screens** - Both iOS and Android have developer screens showing system state
- **Local Debug Logs** - Apps store last 100 events locally for inspection

---

## Accessing Diagnostics

### iOS

1. Open Settings tab
2. Scroll to "Diagnostics" section
3. Tap "Diagnostics" to open the diagnostics screen

### Android

1. Open Settings screen
2. Tap "Diagnostics" button
3. View diagnostics information

---

## Trace IDs

Every wake request generates a unique `traceId` (UUID) that is logged at each step:

### Flow

```
┌─────────────────┐
│  Wake Button    │ ── traceId generated
│  Tapped         │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  send-wake      │ ── Logged to debug_events
│  Edge Function  │    (send_wake_start)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Permission     │ ── Logged to debug_events
│  Check          │    (send_wake_permission_check)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Device Lookup  │ ── Logged to debug_events
│                 │    (send_wake_device_lookup)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Push Sent      │ ── Logged to debug_events
│  (APNs/FCM)     │    (send_wake_apns_result / send_wake_fcm_result)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Notification   │ ── Logged to mobile app
│  Received       │    (notification_received)
└─────────────────┘
```

### Using Trace IDs

1. When a wake is sent, note the `traceId` from the Diagnostics screen
2. Query Supabase: `SELECT * FROM debug_events WHERE trace_id = 'YOUR_TRACE_ID'`
3. Review all events in order to see where the request went

---

## Debug Events Table

### Schema

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Unique event ID |
| `trace_id` | TEXT | Links events from same request |
| `user_id` | UUID | User who triggered the event |
| `platform` | TEXT | 'ios', 'android', or 'backend' |
| `event_type` | TEXT | Type of event (see below) |
| `message` | TEXT | Human-readable message |
| `metadata` | JSONB | Additional structured data |
| `created_at` | TIMESTAMPTZ | When event occurred |

### Event Types

| Event Type | Platform | Description |
|------------|----------|-------------|
| `register_device_start` | Backend | Device registration started |
| `register_device_success` | Backend | Device token stored |
| `send_wake_start` | Backend | Wake request started |
| `send_wake_permission_check` | Backend | Permission lookup result |
| `send_wake_device_lookup` | Backend | Device token lookup result |
| `send_wake_request_created` | Backend | Wake request row created |
| `send_wake_apns_result` | Backend | APNs push attempt result |
| `send_wake_fcm_result` | Backend | FCM push attempt result |
| `send_wake_complete` | Backend | Wake request completed |
| `wake_button_tapped` | iOS/Android | User tapped wake button |
| `wake_request_sent` | iOS/Android | Request sent to backend |
| `wake_response` | iOS/Android | Backend response received |
| `notification_received` | iOS/Android | Push notification received |
| `wake_alert_presented` | iOS/Android | Wake alert shown to user |

---

## iOS Debugging

### DebugLogger

The `DebugLogger.swift` service provides centralized logging:

```swift
// Log an event
DebugLogger.shared.log(
    eventType: "custom_event",
    message: "Something happened",
    metadata: ["key": "value"]
)

// Convenience methods
DebugLogger.shared.logAppLaunch()
DebugLogger.shared.logContactsRefreshComplete(
    peopleICanWake: 5,
    peopleWhoCanWakeMe: 3,
    pendingSent: 1,
    pendingReceived: 0
)
```

### Push Notification Manager

Check token registration:

```swift
// Token status
if let token = PushNotificationManager.shared.deviceToken {
    print("APNs token: \(token.prefix(8))...\(token.suffix(6))")
}

// Manually register token with backend
await PushNotificationManager.shared.registerExistingToken()
```

### Console Logs

All debug logs are printed to console with `[DebugLogger]` prefix:

```
[DebugLogger] [wake_button_tapped] Wake button tapped | ["targetUserId": "abc123", "targetName": "John"]
[DebugLogger] [wake_request_sent] Wake request sent to backend | ["targetUserId": "abc123", "alarmSoundId": "classic"]
[DebugLogger] [wake_response] Wake response received | ["success": "true", "requestId": "xyz789"]
```

---

## Android Debugging

### DebugLogger

The `DebugLogger.kt` object provides centralized logging:

```kotlin
// Log an event
DebugLogger.log(
    eventType = "custom_event",
    message = "Something happened",
    metadata = mapOf("key" to "value")
)

// Convenience methods
DebugLogger.logAppLaunch()
DebugLogger.logContactsRefreshComplete(
    peopleICanWake = 5,
    peopleWhoCanWakeMe = 3,
    pendingSent = 1,
    pendingReceived = 0
)
```

### Logcat

All debug logs appear in Logcat with tag `WakeUpSunshine`:

```
D/WakeUpSunshine: [wake_button_tapped] Wake button tapped | {targetUserId=abc123, targetName=John}
D/WakeUpSunshine: [wake_request_sent] Wake request sent to backend | {targetUserId=abc123, alarmSoundId=classic}
D/WakeUpSunshine: [wake_response] Wake response received | {success=true, requestId=xyz789}
```

Filter Logcat:
```bash
adb logcat -s WakeUpSunshine
```

---

## Backend Debugging

### Edge Function Logs

View logs in Supabase Dashboard:
1. Go to Edge Functions
2. Select a function (e.g., `send-wake`)
3. Click "Logs" tab

### Console Output

Edge functions log to console:

```
[send-wake] traceId=abc123 START senderId=xyz789 senderEmail=user@example.com
[send-wake] traceId=abc123 targetUserId=def456 urgency=normal alarmSoundId=classic
[send-wake] traceId=abc123 devicesFound=2 ios=1 android=1
[send-wake] traceId=abc123 Sending APNs to device 12345
[send-wake] traceId=abc123 Sending FCM to device 67890
[send-wake] traceId=abc123 COMPLETE duration=234ms devicesNotified=2
```

---

## Common Issues

### 1. Notification Not Received

**Check:**
1. Is device token registered? (Diagnostics screen → Push Notifications section)
2. Is notification permission granted? (Diagnostics screen → Push Notifications section)
3. Any devices found in send-wake? (Check debug_events for `send_wake_device_lookup`)

**Solution:**
- Tap "Register Push Token Again" in Diagnostics
- Check APNs/FCM credentials in Supabase environment

### 2. Contacts Not Showing

**Check:**
1. Check Diagnostics screen → Contacts section
2. If counts are 0, check backend response
3. Look for `contacts_refresh_complete` event in debug log

**Solution:**
- Tap "Refresh Contacts" in Diagnostics
- Check if invites were actually accepted

### 3. Permission Denied

**Check:**
1. Look for `send_wake_permission_check` event in debug_events
2. Check if `permissionFound: false`

**Solution:**
- Ensure invite was accepted by target user
- Check `wake_permissions` table in database

---

## SQL Queries

### Recent Debug Events

```sql
SELECT 
  created_at,
  platform,
  event_type,
  message,
  metadata
FROM debug_events
ORDER BY created_at DESC
LIMIT 50;
```

### Events for Specific Trace

```sql
SELECT * FROM debug_events
WHERE trace_id = 'YOUR_TRACE_ID'
ORDER BY created_at;
```

### Device Registration Status

```sql
SELECT 
  ud.id,
  ud.user_id,
  u.email,
  ud.platform,
  ud.device_type,
  ud.device_token IS NOT NULL as has_token,
  ud.is_active,
  ud.updated_at
FROM user_devices ud
LEFT JOIN auth.users u ON u.id = ud.user_id
ORDER BY ud.updated_at DESC
LIMIT 20;
```

### Wake Requests

```sql
SELECT 
  wr.id,
  wr.sender_id,
  sender.email as sender_email,
  wr.receiver_id,
  receiver.email as receiver_email,
  wr.status,
  wr.alarm_sound_id,
  wr.created_at
FROM wake_requests wr
LEFT JOIN auth.users sender ON sender.id = wr.sender_id
LEFT JOIN auth.users receiver ON receiver.id = wr.receiver_id
ORDER BY wr.created_at DESC
LIMIT 20;
```

### Permission Status

```sql
SELECT 
  wp.id,
  wp.granter_id,
  granter.email as granter_email,
  wp.trustee_id,
  trustee.email as trustee_email,
  wp.status,
  wp.created_at
FROM wake_permissions wp
LEFT JOIN auth.users granter ON granter.id = wp.granter_id
LEFT JOIN auth.users trustee ON trustee.id = wp.trustee_id
WHERE wp.status = 'active'
ORDER BY wp.created_at DESC;
```

---

## Exporting Diagnostics

Both platforms allow copying diagnostics to clipboard:

1. Open Diagnostics screen
2. Tap "Copy Diagnostics to Clipboard"
3. Paste into notes, email, or chat

This includes:
- All debug log entries
- Last wake response
- Last notification payload
- Device info (user ID, email, token status, etc.)