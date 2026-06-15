# Alarm Sound Selection Feature

## Overview

The alarm sound selection feature allows users to choose from a variety of alarm sounds when sending a wake request. This feature is implemented across iOS, Android, and the backend (Supabase Edge Functions).

## Feature Flow

1. **Sender selects a contact** in the app
2. **Alarm Sound Picker modal** appears with available sound options
3. **Sender selects a sound** and taps "Send Wake Request"
4. **Backend receives the request** with `alarm_sound_id`
5. **Receiver's device** plays the selected alarm sound when the wake alert is triggered

## Available Alarm Sounds

| ID | Display Name | Description | Icon |
|---|---|---|---|
| `default_alarm` | Classic Alarm | Traditional alarm clock sound | 🔔 |
| `rooster` | Rooster | Wake up with nature | 🌅 |
| `bell` | Bell | Clear and resonant | 🔔 |
| `siren` | Siren | Hard to ignore | 📢 |
| `gentle_chime` | Gentle Chime | Soft and peaceful | 🎵 |
| `urgent_beep` | Urgent Beep | Quick beeping pattern | ⚠️ |

## Implementation Details

### Backend (Supabase)

#### Database Migration
- File: `backend/supabase/migrations/002_add_alarm_sound.sql`
- Adds `alarm_sound_id` column to `wake_requests` table
- Default value: `default_alarm`
- Validated against allowed sound IDs

#### Edge Function
- File: `backend/supabase/functions/send-wake/index.ts`
- Accepts `alarm_sound_id` in request body
- Validates against allowed sound IDs
- Includes `alarm_sound_id` in push notification payload

### iOS Implementation

#### Model
- File: `ios/WakeUpSunshine/Models/AlarmSound.swift`
- Swift enum with all sound cases
- Helper methods for finding sounds by ID
- Properties for display name, description, icon, and color

#### Picker UI
- File: `ios/WakeUpSunshine/Features/Wake/AlarmSoundPicker.swift`
- SwiftUI modal sheet with grid layout
- Sound cards with selection state
- Preview capability (plays system sound as placeholder)
- Haptic feedback on selection

#### Integration
- File: `ios/WakeUpSunshine/Features/Home/HomeView.swift`
- Shows picker when wake button is tapped
- Passes selected sound to `sendWakeRequest`

#### Alert Screen
- File: `ios/WakeUpSunshine/Features/WakeAlert/WakeAlertView.swift`
- Accepts `alarmSoundId` parameter
- Attempts to play custom `.caf` sound file
- Falls back to system sound if custom file not found

### Android Implementation

#### Model
- File: `android/app/src/main/kotlin/com/wakeupsunshine/data/AlarmSound.kt`
- Kotlin enum with all sound cases
- Helper methods for finding sounds by ID
- Properties for display name, description, icon, and color

#### Picker UI
- File: `android/app/src/main/kotlin/com/wakeupsunshine/ui/alarm/AlarmSoundPicker.kt`
- Jetpack Compose bottom sheet
- Grid layout with sound cards
- Material 3 design

#### Alarm Activity
- File: `android/app/src/main/kotlin/com/wakeupsunshine/ui/alarm/AlarmActivity.kt`
- Plays selected sound from `res/raw/` directory
- Falls back to system alarm ringtone
- Includes vibration pattern

#### Messaging Service
- File: `android/app/src/main/kotlin/com/wakeupsunshine/service/WakeMessagingService.kt`
- Extracts `alarm_sound_id` from FCM data payload
- Passes to AlarmActivity via intent extras

## Adding New Alarm Sounds

### Step 1: Add Sound Files

**iOS:**
- Add `.caf` files to `ios/WakeUpSunshine/Resources/Sounds/`
- File name should match the enum raw value (e.g., `rooster.caf`)

**Android:**
- Add `.mp3` or `.ogg` files to `android/app/src/main/res/raw/`
- File name should match the sound ID (e.g., `rooster.mp3`)

### Step 2: Update Model

Add new case to the enum in both platforms:

**iOS (AlarmSound.swift):**
```swift
case newSound = "new_sound"

// Then add to allSounds array
```

**Android (AlarmSound.kt):**
```kotlin
NEW_SOUND(
    id = "new_sound",
    displayName = "New Sound",
    description = "Description here",
    iconName = "icon_name",
    iconColor = Color
)
```

### Step 3: Update Backend

Add the new ID to the allowed set in `send-wake/index.ts`:
```typescript
const ALLOWED_ALARM_SOUNDS = [
  'default_alarm',
  'rooster',
  'bell',
  'siren',
  'gentle_chime',
  'urgent_beep',
  'new_sound'  // Add here
];
```

## Testing

### iOS
1. Build and run the app in simulator
2. Navigate to Home screen
3. Tap a contact's wake button
4. Verify Alarm Sound Picker appears
5. Select different sounds and verify selection state changes
6. Send wake request and verify sound ID is logged

### Android
1. Build and run the app
2. Navigate to Home screen
3. Tap a contact's wake button
4. Verify Alarm Sound Picker appears
5. Select different sounds and verify selection state changes
6. Send wake request and verify sound ID is passed

## Future Enhancements

1. **Sound Preview:** Add ability to preview actual alarm sounds in picker
2. **Custom Sounds:** Allow users to upload custom alarm sounds
3. **Sound Categories:** Group sounds by category (nature, classic, gentle, urgent)
4. **Per-Contact Defaults:** Remember preferred sound for each contact
5. **Volume Control:** Allow setting volume level for different sounds