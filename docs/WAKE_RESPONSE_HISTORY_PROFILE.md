# Wake Response, History & Profile — Technical Specification

## Architecture Overview

### Wake Request Lifecycle
```
pending → sent → delivered → confirmed | snoozed | dismissed | timed_out
```

### Push Notification Types
| type | Direction | Trigger |
|---|---|---|
| `wake_alarm` | Backend → Android | `send-wake` fires FCM to receiver |
| `wake_response` | Backend → iOS | `wake-response` fires APNs to sender |

---

## Backend Edge Functions

### `send-wake`
**POST** `/functions/v1/send-wake`

Request body:
```json
{ "targetUserId": "uuid", "alarmSoundId": "classic", "urgency": "normal", "message": "optional" }
```

Anti-spam: returns `429` if an active request (status in `pending/sent/delivered/snoozed`) exists between the same pair within 2 minutes.

### `wake-response`
**POST** `/functions/v1/wake-response`

Request body:
```json
{ "wakeRequestId": "uuid", "action": "confirmed|snoozed|dismissed", "snoozeMinutes": 5 }
```

- Normalizes legacy action names: `confirm→confirmed`, `snooze→snoozed`, `dismiss→dismissed`
- Updates `status`, `response_action`, `responded_at`, `snooze_until` (for snoozed)
- Sends push to original sender with `type: "wake_response"`, `responseAction`, `receiverName`

### `get-wake-status`
**POST** `/functions/v1/get-wake-status`

Request body: `{ "wakeRequestId": "uuid" }`

Caller must be sender or receiver. Returns full wake request detail.

### `get-history`
**GET** `/functions/v1/get-history?page=1&limit=50`

Returns merged sent+received history sorted newest first.

Response item shape:
```json
{
  "id": "uuid",
  "direction": "sent|received",
  "otherUserName": "string",
  "otherUserEmail": "string",
  "avatarColor": "#hex",
  "status": "confirmed|snoozed|dismissed|...",
  "responseAction": "confirmed|snoozed|dismissed|null",
  "sentAt": "ISO8601",
  "createdAt": "ISO8601"
}
```

### `get-profile`
**GET** `/functions/v1/get-profile`

Auto-creates `public.users` row if missing. Returns profile with displayName, phoneNumber, avatarColor.

### `update-profile`
**POST** `/functions/v1/update-profile`

Accepts `displayName`, `phoneNumber`, `avatarColor`. Syncs displayName to `auth.users.user_metadata`.

---

## iOS Implementation

### Waiting State Flow (HomeViewModel)
1. User taps Wake → `sendWakeToBackend` called
2. On success: `isWaitingForResponse = true`, start 5-second polling task + elapsed timer
3. Poll `get-wake-status` every 5 seconds
4. When status is terminal (`confirmed|snoozed|dismissed|timed_out`): update UI, call `stopWaiting()`
5. `stopWaiting()` waits 3 seconds then dismisses the sheet
6. Also auto-dismisses after 300 seconds (5 min timeout)

### Push Response Handling (PushNotificationManager)
- `type: "wake_response"` triggers `handleWakeConfirmation`
- Sets `wakeResponseAction` (confirmed/snoozed/dismissed) and `showingWakeConfirmation = true`
- RootView shows alert: "They're Awake! 🌅" (or appropriate message based on action)

### Profile (SettingsView / ProfileViewModel)
- `ProfileViewModel.load()` calls `get-profile` on first appearance
- `ProfileRow` shows real name, contact info, avatar initial with correct color
- `ProfileEditView` is a NavigationLink destination for editing

---

## Android Implementation

### Alarm Response (AlarmActivity)
- `"I'm Awake"` button → `sendWakeResponse("confirmed")`
- `"Snooze (5 min)"` button → `sendWakeResponse("snoozed", snoozeMinutes=5)`
- Payload: `{ "wakeRequestId": "...", "action": "confirmed|snoozed|dismissed", "snoozeMinutes": 5 }`

### History (HistoryScreen / HistoryRepository)
- `HistoryRepository.getHistory()` → GET `get-history`
- `HistoryScreen` shows direction badge (orange arrow up = sent, green arrow down = received)
- Status chip colors: Awake=green, Snoozed=orange, Dismissed=grey, Timed Out=red, Delivered/Sent=orange

### Session Persistence
- `SupabaseClient.restoreSession(context)` called before any authenticated HTTP call in `AlarmActivity`
- Prevents null session when FCM wakes the app process cold

---

## Database Schema (`public.wake_requests`)

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `sender_id` | UUID | FK users |
| `receiver_id` | UUID | FK users |
| `status` | TEXT | pending→sent→delivered→confirmed\|snoozed\|dismissed\|timed_out |
| `response_action` | TEXT | confirmed\|snoozed\|dismissed |
| `response_message` | TEXT | Optional message with response |
| `responded_at` | TIMESTAMPTZ | When receiver responded |
| `snooze_until` | TIMESTAMPTZ | Set when action=snoozed |
| `alarm_sound_id` | TEXT | Sound to play |
| `message` | TEXT | Sender's message |
| `urgency` | TEXT | normal\|high |
| `sent_at` | TIMESTAMPTZ | When FCM/APNs confirmed delivery |
| `delivered_at` | TIMESTAMPTZ | When device acknowledged |
| `created_at` | TIMESTAMPTZ | Row creation |
| `updated_at` | TIMESTAMPTZ | Auto-updated by trigger |
