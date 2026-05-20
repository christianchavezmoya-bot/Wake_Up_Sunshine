# Alarm Sound Testing Guide

## Alarm Sound IDs (stable — must match iOS, Android, backend)

| ID        | Display Name   | Has File | File (iOS)      | File (Android)  |
|-----------|---------------|----------|-----------------|-----------------|
| `wake_up` | Wake Up        | ✅ Yes   | `wake_up.caf`   | `wake_up.mp3`   |
| `hey_you` | Hey You Wake   | ✅ Yes   | `hey_you.caf`   | `hey_you.mp3`   |
| `minions` | Minions        | ✅ Yes   | `minions.caf`   | `minions.mp3`   |
| `classic` | Classic Alarm  | ❌ None  | system fallback | system fallback |

`classic` intentionally has no file — it plays the device's system alarm.

---

## Asset Locations

### iOS
```
ios/WakeUpSunshine/Resources/Sounds/
├── wake_up.caf
├── hey_you.caf
└── minions.caf
```
All three are included in the Xcode project as **Copy Bundle Resources** (verified in `project.pbxproj`).

### Android
```
android/app/src/main/res/raw/
├── wake_up.mp3
├── hey_you.mp3
└── minions.mp3
```
Filenames must be lowercase with no spaces (Android resource naming rules).

---

## How to Test — iOS

### From Settings
1. Open the app and log in.
2. Tap the **Settings** tab (bottom nav).
3. Under **Notifications**, tap **Alarm Sound**.
4. The picker sheet opens — 4 buttons: Wake Up, Hey You Wake, Minions, Classic Alarm.
5. Tap each sound — tap the ▶ preview button inside each card to hear it.
6. Tap **Save Selection** to confirm.
7. Verify the **Alarm Sound** row subtitle updates to the selected name.
8. Tap **Test Alarm**.
9. Correct sound plays (or system alarm for `classic`). Row changes to "Stop Alarm".
10. Tap again to stop, or it auto-stops after 10 seconds.

### From Wake Flow
1. Go to **Home** tab.
2. Tap the bell icon on a contact card.
3. The alarm sound picker opens — select a sound and tap **Send Wake Request**.
4. The selected `alarmSoundId` is sent with the wake request.

### Simulate Wake (full alert screen)
1. On the Home screen, tap the orange bell icon in the top-right header.
2. The full `WakeAlertView` opens.
3. It plays whichever alarm was passed as `alarmSoundId` (defaults to `classic`).

---

## How to Test — Android

### From Settings
1. Install the APK on device or emulator.
2. Log in.
3. On the Home screen, tap **Settings** button.
4. Tap **Alarm Sound** — picker bottom sheet opens.
5. Select a sound and tap **Send Wake Request**.
6. Subtitle on the row updates to the selected sound name (persisted in SharedPreferences).
7. Tap **Test Alarm** — selected sound plays.
8. Tap again to stop (auto-stops after 10 seconds).

### Full Alarm Screen
AlarmActivity is launched by FCM push notification with `alarm_sound_id` in the data payload.
To test manually, use ADB:
```bash
adb shell am start -n com.wakeupsunshine/.ui.alarm.AlarmActivity \
  --es sender_name "Test" \
  --es message "Wake up!" \
  --es alarm_sound_id "minions"
```

---

## How to Replace Alarm Files

### iOS
1. Convert your audio file to CAF:
   ```bash
   afconvert -f caff -d LEI16@44100 your_file.mp3 wake_up.caf
   ```
2. Replace the file at `ios/WakeUpSunshine/Resources/Sounds/<id>.caf`.
3. Run `xcodegen generate` and rebuild.

### Android
1. Rename/copy your MP3 to `android/app/src/main/res/raw/<id>.mp3`.
2. Filename must be lowercase, no spaces.
3. Rebuild with `./gradlew assembleDebug`.

---

## Console Logs to Watch

All alarm-related logs are tagged `[AlarmSettings]` and `[AlarmPicker]`.

```
[AlarmSettings] Opening alarm picker
[AlarmSettings] Saved alarm: hey_you (Hey You Wake)
[AlarmSettings] Testing alarm id='hey_you'
[AlarmSettings] Resolved asset: hey_you.caf
[AlarmSettings] Playback started ✓
[AlarmSettings] Alarm stopped
```

Error example (file missing):
```
[AlarmSettings] WARNING: 'missing_id.caf' not found in bundle — falling back to system sound
```

---

## Known Limitations

- `classic` uses the device system alarm — volume follows system alarm volume, not media volume.
- The picker's "Send Wake Request" label appears in Settings (shows "Save Selection" via `confirmLabel`).
- Android Settings screen requires disk space to build (Gradle dependency resolution).
- Preview in the picker auto-stops after 2.5 seconds.
- Test Alarm in Settings auto-stops after 10 seconds.
