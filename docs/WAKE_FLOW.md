# Wake Flow Implementation

## Architecture Overview

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   User A    │─────▶│   Backend   │─────▶│   User B    │
│  (Sender)   │      │  (Supabase) │      │ (Receiver)  │
└─────────────┘      └─────────────┘      └─────────────┘
       │                    │                    │
       │                    │                    │
       ▼                    ▼                    ▼
  Tap "Wake"         Create Request        Push/Simulated
  Call API           Check Permission      Wake Alert UI
                     Rate Limits           Sound + Vibrate
                     Send Push
```

## Request Flow

### 1. Sender Initiates Wake
```
POST /functions/v1/send-wake
Headers: Authorization: Bearer <token>
Body: {
  "targetUserId": "user-b-id",
  "message": "Wake up!",
  "urgency": "normal"
}
```

### 2. Backend Processing
1. Validate authentication token
2. Check wake permission exists (granter_id=target, trustee_id=sender)
3. Check rate limits (max 10/day, 30min cooldown)
4. Get target user's registered devices
5. Create `wake_requests` record
6. Send push notifications to all devices
7. Return success with request ID

### 3. Push Payload (APNs)
```json
{
  "aps": {
    "alert": {
      "title": "Wake Up! 🌅",
      "body": "Someone is trying to wake you"
    },
    "sound": "criticalalarm.caf",
    "badge": 1,
    "interruption-level": "critical"
  },
  "requestId": "uuid",
  "senderId": "user-a-id",
  "senderName": "Alex",
  "message": "Wake up!",
  "urgency": "normal"
}
```

### 4. Receiver Response
```
POST /functions/v1/wake-response
Body: {
  "requestId": "uuid",
  "response": "confirmed" | "snoozed" | "dismissed"
}
```

## Database Schema

### wake_requests
```sql
CREATE TABLE wake_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID REFERENCES auth.users NOT NULL,
  receiver_id UUID REFERENCES auth.users NOT NULL,
  message TEXT,
  urgency TEXT DEFAULT 'normal',
  status TEXT DEFAULT 'pending', -- pending, delivered, confirmed, snoozed, dismissed
  created_at TIMESTAMPTZ DEFAULT NOW(),
  delivered_at TIMESTAMPTZ,
  confirmed_at TIMESTAMPTZ
);
```

### wake_permissions
```sql
CREATE TABLE wake_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  granter_id UUID REFERENCES auth.users NOT NULL, -- who can BE woken
  trustee_id UUID REFERENCES auth.users NOT NULL, -- who can WAKE
  status TEXT DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### user_devices
```sql
CREATE TABLE user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users NOT NULL,
  device_token TEXT NOT NULL,
  platform TEXT NOT NULL, -- 'ios' or 'android'
  is_primary BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_used_at TIMESTAMPTZ
);
```

### rate_limits
```sql
CREATE TABLE rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID REFERENCES auth.users NOT NULL,
  target_id UUID REFERENCES auth.users NOT NULL,
  requests_today INT DEFAULT 0,
  last_request_at TIMESTAMPTZ,
  is_blocked BOOLEAN DEFAULT false
);
```

## Testing Steps

### Test 1: Simulated Wake (No APNs Required)
1. Login to the app
2. On Home screen, tap the bell icon (top right)
3. **Expected**: WakeAlertView opens full-screen
4. **Expected**: Sound plays + vibration
5. Tap "I'm Awake"
6. **Expected**: Screen dismisses

### Test 2: Real Wake Flow (Requires Backend)
1. User A: Login, see contacts list
2. User A: Tap wake button on a contact
3. **Expected**: API call to `/send-wake`
4. **Expected**: "Wake Alert Sent" confirmation
5. User B: Receives push notification (if APNs configured)
   - OR check backend logs for "Push would be sent to device X"
6. User B: Tap notification → WakeAlertView opens

## Current Limitations

1. **No Real APNs Push** - APNs credentials not configured
   - Solution: Add APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY to Supabase secrets
   - Use simulation button for testing

2. **No Critical Alerts** - Critical alerts require Apple approval
   - Current: Uses standard push notifications
   - Future: Apply for critical alert entitlement

3. **No FCM for Android** - FCM credentials not configured
   - Solution: Add FCM_PROJECT_ID, FCM_SERVICE_ACCOUNT to Supabase secrets

## Files Modified

### iOS
- `ios/WakeUpSunshine/Features/Home/HomeView.swift` - Added simulate wake button
- `ios/WakeUpSunshine/Features/WakeAlert/WakeAlertView.swift` - Sound/vibration on appear

### Backend (Already Existed)
- `backend/supabase/functions/send-wake/index.ts` - Wake request handler
- `backend/supabase/functions/wake-response/index.ts` - Response handler

## Next Steps

1. **Configure APNs**
   - Generate APNs key from Apple Developer Portal
   - Add credentials to Supabase secrets
   - Test real push delivery

2. **Apply for Critical Alerts**
   - Submit request to Apple for critical alert entitlement
   - Update entitlements file
   - Re-enable critical alert functionality

3. **Add Real Contacts**
   - Implement contact search/add functionality
   - Connect to `get-contacts` API
   - Create real wake permissions

## Log File
See: `logs/wake_flow.log` for runtime logs