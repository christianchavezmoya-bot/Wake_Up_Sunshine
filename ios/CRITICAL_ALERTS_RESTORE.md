# Critical Alerts Restoration Guide

**Removed:** Fri Apr 24 08:35 AEST 2026  
**Reason:** Apple approval pending - provisioning profile doesn't include Critical Alerts capability

---

## What Was Removed

Critical Alerts capability was temporarily removed to enable device builds without Apple approval.

---

## How to Restore Critical Alerts

### Step 1: Get Apple Approval

1. Sign in to [Apple Developer](https://developer.apple.com/account/)

2. Navigate to **Certificates, Identifiers & Profiles** > **Identifiers**

3. Select the Bundle ID: `com.wakeupsunshine.app`

4. Under **Capabilities**, enable **Critical Alerts**

5. Submit justification:
   > "This app is designed to help users wake up through urgent notifications from trusted contacts. Critical Alerts are essential to ensure wake-up calls are delivered even when the device is in silent or Do Not Disturb mode, which is the core functionality of the app."

6. Wait for Apple approval (typically 24-48 hours)

### Step 2: Restore project.yml

**File:** `ios/project.yml`

**Find this section:**
```yaml
    entitlements:
      path: WakeUpSunshine/Resources/WakeUpSunshine.entitlements
      properties:
        aps-environment: development
        # Critical Alerts temporarily removed - awaiting Apple approval
        # com.apple.developer.usernotifications.critical-alerts: true
```

**Replace with:**
```yaml
    entitlements:
      path: WakeUpSunshine/Resources/WakeUpSunshine.entitlements
      properties:
        aps-environment: development
        com.apple.developer.usernotifications.critical-alerts: true
```

### Step 3: Restore Entitlements File

**File:** `ios/WakeUpSunshine/Resources/WakeUpSunshine.entitlements`

**Replace with:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string>
    <key>com.apple.developer.usernotifications.critical-alerts</key>
    <true/>
</dict>
</plist>
```

### Step 4: Regenerate Xcode Project

```bash
cd ios
xcodegen generate
```

### Step 5: Rebuild

```bash
xcodebuild -project WakeUpSunshine.xcodeproj -scheme WakeUpSunshine -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

---

## Current Status

- ✅ Critical Alerts removed
- ✅ Push notifications (aps-environment) retained
- ✅ App builds successfully
- ⏳ Awaiting Apple approval for Critical Alerts

## Impact

Without Critical Alerts:
- Wake-up notifications will still be delivered
- Notifications may be silenced by Do Not Disturb/Silent mode
- Users should disable Do Not Disturb for the app as a workaround

With Critical Alerts (after restoration):
- Wake-up notifications bypass Do Not Disturb/Silent mode
- Core app functionality fully operational