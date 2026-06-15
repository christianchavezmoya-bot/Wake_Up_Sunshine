# iOS Setup - Next Steps

## Current Status: ✅ BUILD SUCCEEDED

The iOS project builds successfully on Simulator. The following steps are required for device deployment and App Store submission.

---

## Required Manual Steps

### 1. Set Development Team (Required for Device Testing)

1. Open Xcode:
   ```bash
   open WakeUpSunshine.xcodeproj
   ```

2. In Xcode, select the project in the navigator (left sidebar)

3. Select "WakeUpSunshine" target

4. Go to **Signing & Capabilities** tab

5. Under "Team", select your Apple Developer Team
   - If no team exists, click "Add Account" and sign in with your Apple ID
   - For personal testing, a free Apple ID works
   - For App Store distribution, a paid Developer Program membership is required

6. Xcode will automatically generate provisioning profiles

---

### 2. Critical Alerts Entitlement (Required for Core Feature)

The app uses Critical Alerts to bypass Do Not Disturb/Silent mode for wake-up calls.

#### Current Configuration:
- ✅ Entitlement added to `.entitlements` file
- ✅ `com.apple.developer.usernotifications.critical-alerts: true`

#### Apple Approval Required:
Critical Alerts require explicit approval from Apple:

1. Sign in to [Apple Developer](https://developer.apple.com/account/)

2. Navigate to **Certificates, Identifiers & Profiles** > **Identifiers**

3. Select the Bundle ID: `com.wakeupsunshine.app`

4. Under **Capabilities**, enable **Critical Alerts**

5. Apple requires justification for this entitlement:
   > "This app is designed to help users wake up through urgent notifications from trusted contacts. Critical Alerts are essential to ensure wake-up calls are delivered even when the device is in silent or Do Not Disturb mode, which is the core functionality of the app."

6. Submit for review (may take 24-48 hours)

---

### 3. Push Notifications (APNs) Setup

#### Generate APNs Certificate or APNs Key (.p8):

**Option A: APNs Certificate (Traditional)**
1. Go to Apple Developer > Certificates
2. Create new certificate: Apple Push Notification service SSL (Sandbox & Production)
3. Follow the CSR generation steps
4. Download and install in Keychain

**Option B: APNs Key (Recommended)**
1. Go to Apple Developer > Certificates > Keys
2. Create new key with "Apple Push Notifications service (APNs)" enabled
3. Download the `.p8` key file
4. Note the Key ID and Team ID

#### Configure with Supabase:
1. Go to Supabase Dashboard > Project Settings > Push Notifications
2. Upload your APNs certificate or enter your APNs key details
3. Configure the push notification provider

---

### 4. Real Device Testing

1. Connect your iPhone via USB

2. In Xcode, select your device from the device dropdown (top toolbar)

3. Build and run (Cmd+R)

4. On first run, trust the developer:
   - Go to Settings > General > VPN & Device Management
   - Trust your developer certificate

5. Test push notifications:
   - Run the app
   - Accept notification permissions
   - Send test wake request from another device

---

## Project Configuration Reference

### Bundle Identifier
```
com.wakeupsunshine.app
```

### Minimum Deployment Target
```
iOS 17.0
```

### Entitlements File
```
WakeUpSunshine/Resources/WakeUpSunshine.entitlements
```

### Capabilities Required
- Push Notifications ✅
- Critical Alerts ⚠️ (requires Apple approval)
- Background Modes - Remote notifications ✅

---

## Troubleshooting

### Build Issues
```bash
cd ios
xcodegen generate
xcodebuild -project WakeUpSunshine.xcodeproj -scheme WakeUpSunshine clean build
```

### Signing Issues
- Ensure your Apple ID is added in Xcode > Preferences > Accounts
- Check that the correct team is selected
- Try: Xcode > Product > Clean Build Folder (Cmd+Shift+K)

### Push Notifications Not Working
- Verify APNs certificate/key is properly configured
- Check that the app has notification permissions in Settings
- Test on a real device (push notifications don't work well in Simulator)

---

## Files Modified (Setup Process)

The following files were modified to fix build errors:

1. `WakeUpSunshine/App/WakeUpSunshineApp.swift` - Added `senderName` to WakeRequest
2. `WakeUpSunshine/Services/SupabaseManager.swift` - Fixed URL type, removed duplicate WakeRequest
3. `WakeUpSunshine/Services/PushNotificationManager.swift` - Added UIKit import
4. `WakeUpSunshine/Shared/Extensions/Extensions.swift` - Fixed Color reference
5. `WakeUpSunshine/Features/Home/HomeView.swift` - Fixed Color.textSecondary reference

---

## Quick Commands

```bash
# Generate Xcode project
cd ios && xcodegen generate

# Build for Simulator
xcodebuild -project WakeUpSunshine.xcodeproj -scheme WakeUpSunshine -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Open in Xcode
open WakeUpSunshine.xcodeproj

# Clean build
xcodebuild clean