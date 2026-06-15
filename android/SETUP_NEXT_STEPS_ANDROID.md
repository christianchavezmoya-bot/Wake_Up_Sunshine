# Android Setup - Next Steps

## Current Status: ⚠️ READY FOR ANDROID STUDIO

The Android project structure is complete with Gradle configuration. The following steps are required to build and run.

---

## Prerequisites Missing

### 1. Android Studio (Required)

Android Studio is NOT installed on this Mac. Install it first:

**Download from:** https://developer.android.com/studio

**Installation Steps:**
1. Download the `.dmg` file
2. Open the DMG and drag Android Studio to Applications
3. Launch Android Studio from Applications
4. Complete the setup wizard (it will download SDK, emulator, etc.)

**After Installation:**
- Android SDK will be installed at: `~/Library/Android/sdk`
- Gradle wrapper will be auto-generated when you open the project

---

## Firebase Configuration Required

### 2. Create Firebase Project

The `google-services.json` file is currently a PLACEHOLDER. You must replace it with real Firebase config.

**Steps:**

1. Go to [Firebase Console](https://console.firebase.google.com/)

2. Create a new project:
   - Project name: `Wake Up Sunshine`
   - Enable Google Analytics (optional)

3. Add an Android app:
   - **Package name:** `com.wakeupsunshine.app`
   - **App nickname:** Wake Up Sunshine
   - **Debug signing certificate SHA-1:** (optional, required for Google Sign-In)

4. Download `google-services.json`

5. Replace the placeholder:
   ```bash
   cd android/app
   # Replace the file with your downloaded google-services.json
   ```

### 3. Enable Firebase Cloud Messaging (FCM)

In Firebase Console:

1. Go to your project > **Project Settings** > **Cloud Messaging**

2. Note your **Server Key** and **Sender ID**

3. Configure Supabase to use FCM:
   - Go to Supabase Dashboard > Project Settings > Push Notifications
   - Add your FCM Server Key

---

## Project Structure

```
android/
├── app/
│   ├── build.gradle          # App-level build config
│   ├── google-services.json  # Firebase config (PLACEHOLDER - REPLACE!)
│   └── src/main/
│       ├── AndroidManifest.xml
│       └── java/com/wakeupsunshine/
├── build.gradle              # Project-level build config
├── settings.gradle           # Project settings
├── gradle.properties         # Gradle properties
└── gradle/wrapper/
    └── gradle-wrapper.properties
```

---

## Build & Run Steps

### After Installing Android Studio:

1. **Open Project:**
   ```bash
   open -a "Android Studio" /Users/christianchavez/Documents/Codex/Wake\ up\ sunshine/android
   ```

2. **Let Gradle Sync:**
   - Android Studio will automatically sync Gradle
   - Wait for all dependencies to download

3. **Run on Emulator:**
   - Create an AVD (Android Virtual Device): Tools > Device Manager
   - Select a device (e.g., Pixel 7)
   - Click Run (green play button)

4. **Run on Physical Device:**
   - Enable Developer Options on your Android device
   - Enable USB Debugging
   - Connect via USB
   - Select device in Android Studio and click Run

---

## Configuration Summary

### Package Name
```
com.wakeupsunshine.app
```

### Minimum SDK
```
Android 8.0 (API 26)
```

### Target SDK
```
Android 14 (API 34)
```

### Key Dependencies
- Kotlin 1.9.22
- Jetpack Compose 1.5.8
- Supabase KT 2.1.0
- Firebase BOM 34.12.0
- Hilt 2.50

---

## Fixes Applied

The following fixes were applied during setup:

1. **Added Hilt Gradle Plugin** to `build.gradle`
2. **Added kapt plugin** to `app/build.gradle`
3. **Created `settings.gradle`** with proper plugin management
4. **Created `gradle-wrapper.properties`** for Gradle 8.5

---

## Troubleshooting

### Gradle Sync Failed
- Ensure you have internet connection for dependency download
- Try: File > Invalidate Caches / Restart
- Check Android SDK path in Android Studio > Preferences > Appearance & Behavior > System Settings > Android SDK

### google-services.json Error
- Replace the placeholder file with real Firebase config
- Ensure the package name matches exactly: `com.wakeupsunshine.app`

### Hilt/Kapt Issues
- Clean and rebuild: Build > Clean Project, then Build > Rebuild Project

---

## Quick Commands (After Android Studio Install)

```bash
# Open project in Android Studio
open -a "Android Studio" /Users/christianchavez/Documents/Codex/Wake\ up\ sunshine/android

# Build from command line (requires ANDROID_HOME)
./gradlew assembleDebug

# Run tests
./gradlew test

# Clean build
./gradlew clean