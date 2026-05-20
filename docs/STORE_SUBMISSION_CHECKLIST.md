# Wake Up Sunshine — Store Submission Checklist

**Version:** 1.0.0 | **Date:** 2026-11-05

---

## 🔴 Blocking (Must Fix Before Submission)

- [ ] **Account Deletion** — Implement backend `delete-account` endpoint and wire up UI on both platforms
  - [ ] Create Supabase edge function `delete-account` that deletes user data and auth record
  - [ ] iOS: Make "Delete Account" button functional with confirmation dialog explaining what's deleted
  - [ ] Android: Add "Delete Account" button in Settings with same confirmation flow
  - [ ] Both: After deletion, clear local storage and return to logged-out state
  - [ ] Both: Revoke all sessions/tokens on deletion

- [ ] **iOS Critical Alerts Entitlement** — Enable critical alerts for core wake-up functionality
  - [ ] Uncomment critical alerts entitlement in `WakeUpSunshine.entitlements`
  - [ ] Request Apple approval for critical alerts entitlement (requires justification)
  - [ ] Update notification registration to request critical alert permission
  - [ ] Test alarm sounds in silent/DND mode on physical device

- [ ] **Privacy Policy URL** — Create and host a privacy policy
  - [ ] Write privacy policy document covering all collected data
  - [ ] Host at `https://wakeupsunshine.app/privacy` (or similar)
  - [ ] iOS: Make "Privacy Policy" text tappable and link to URL
  - [ ] Android: Make "Privacy Policy" text tappable and link to URL
  - [ ] iOS: Add privacy policy URL to App Store Connect metadata
  - [ ] Android: Add privacy policy URL to Google Play Console

- [ ] **Password Reset Flow** — Implement forgot password functionality
  - [ ] iOS: Add "Forgot Password?" link on login screen
  - [ ] Android: Add "Forgot Password?" link on login screen
  - [ ] Both: Call Supabase `resetPasswordForEmail()` and show confirmation
  - [ ] Both: Handle password reset deep link back into the app

---

## ⚠️ Needs Work (Should Fix Before Submission)

- [ ] **Email Verification UI** — Add resend verification and unverified state handling
  - [ ] iOS: Show "Verify your email" screen after signup
  - [ ] Android: Add "Resend verification email" button
  - [ ] Both: Prevent unverified users from sending wake requests

- [ ] **Debug Logging Cleanup** — Remove or gate debug output in production
  - [ ] Android: Gate `Log.d`/`Log.v` behind `BuildConfig.DEBUG`
  - [ ] iOS: Gate `print()` behind `#if DEBUG`
  - [ ] Both: Remove any verbose network logging

- [ ] **iOS Universal Links** — Enable for seamless invite experience
  - [ ] Uncomment `com.apple.developer.associated-domains` in entitlements
  - [ ] Host `apple-app-site-association` file at `https://wakeupsunshine.app`
  - [ ] Test universal link flow on physical device

- [ ] **Notification Permission Denied Handling** — Graceful fallback
  - [ ] Both: Detect when notifications are denied
  - [ ] Both: Show persistent banner explaining wake alerts require notifications
  - [ ] Both: Provide button to open Settings

- [ ] **User-Facing Limitations Explanation** — Set correct expectations
  - [ ] Add info in onboarding about silent mode / DND limitations
  - [ ] Add FAQ or help section explaining when alarms may not sound

- [ ] **Crash Reporting** — Integrate production crash monitoring
  - [ ] Add Firebase Crashlytics or Sentry to iOS
  - [ ] Add Firebase Crashlytics or Sentry to Android
  - [ ] Verify crash reports appear in dashboard

- [ ] **App Icon Verification** — Ensure all required sizes exist
  - [ ] iOS: Verify all sizes in Assets.xcassets (1024x1024 store, 60pt@2x/@3x, etc.)
  - [ ] Android: Verify adaptive icon (foreground + background layers) for all densities

- [ ] **Release Build Testing**
  - [ ] iOS: Archive and export for App Store distribution
  - [ ] Android: Build signed AAB with ProGuard/R8 enabled
  - [ ] Both: Test release builds on physical devices

---

## ✅ Already Passing

- [x] Bundle ID / Package Name consistent across platforms
- [x] App display name configured
- [x] Version and build numbers set (1.0.0 / 1)
- [x] Deep link scheme configured (`wakeupsunshine://`)
- [x] Android App Links with auto-verify
- [x] Real Supabase authentication (email/password + phone OTP)
- [x] Secure session/token handling via Supabase SDK
- [x] Expired session handling with redirect to login
- [x] No test users, hardcoded credentials, or localhost endpoints
- [x] Logout flow works on both platforms
- [x] Camera permission justified (QR code scanning)
- [x] No tracking/advertising SDKs
- [x] Production API endpoints (no localhost)
- [x] Android FCM push notifications configured
- [x] iOS push notifications with production APS entitlement
- [x] `ITSAppUsesNonExemptEncryption = false` declared
- [x] HTTPS-only network policy (`NSAllowsArbitraryLoads = false`)
- [x] Background modes properly declared (audio, fetch, remote-notification)
- [x] Android full-screen intent for alarm activity
- [x] Android lock screen display (`showOnLockScreen`, `turnScreenOn`)

---

## 📋 Apple App Store Connect — Metadata Checklist

- [ ] App name: "Wake Up Sunshine"
- [ ] Bundle ID: `com.wakeupsunshine.app`
- [ ] Primary category: Lifestyle / Utilities
- [ ] Secondary category: Social Networking
- [ ] App description written
- [ ] Keywords optimized
- [ ] Screenshots for all required device sizes (6.7", 6.5", 5.5")
- [ ] App preview video (recommended for alarm features)
- [ ] Privacy Policy URL (🔴 missing)
- [ ] App Privacy Labels filled in (🔴 not done)
- [ ] Age rating selected
- [ ] Support URL provided
- [ ] Marketing URL (optional)
- [ ] Review notes explaining alarm/notification behavior

## 📋 Google Play Console — Metadata Checklist

- [ ] App name: "Wake Up Sunshine"
- [ ] Package name: `com.wakeupsunshine.app`
- [ ] App description (short + full)
- [ ] Screenshots for all required form factors
- [ ] Feature graphic (1024x500)
- [ ] Privacy Policy URL (🔴 missing)
- [ ] Data Safety form filled in (🔴 not done)
- [ ] Content rating questionnaire completed
- [ ] Target API level compliance (API 34+)
- [ ] Data deletion policy (🔴 account deletion not implemented)

---

## 🧪 QA Test Matrix

| # | Test Case | iPhone | Android | Status |
|---|-----------|--------|---------|--------|
| 1 | Fresh install → signup with email | | | ❓ |
| 2 | Fresh install → login with email | | | ❓ |
| 3 | Password reset flow | | | ❌ Not implemented |
| 4 | Send wake request to contact | | ✅ | |
| 5 | Receive wake (app foreground) | | | ❓ |
| 6 | Receive wake (app backgrounded) | | | ❓ |
| 7 | Receive wake (app killed) | | | ❓ |
| 8 | Receive wake (phone locked) | | | ❓ |
| 9 | Receive wake (silent mode) | | | ❌ iOS critical alerts disabled |
| 10 | Receive wake (DND/Focus mode) | | | ❌ iOS critical alerts disabled |
| 11 | Notification permission denied | | | ❓ |
| 12 | Poor network / offline | | ⚠️ | |
| 13 | Deep link invite (wakeupsunshine://) | | | ❓ |
| 14 | QR code invite scan | | | ❓ |
| 15 | Invalid/expired invite | | | ❓ |
| 16 | Account deletion flow | ❌ | ❌ | ❌ Not implemented |
| 17 | Logout and re-login | | ✅ | |
| 18 | Theme switching | | ✅ | |
| 19 | Profile edit (name, phone) | | | ❓ |
| 20 | Blocked contacts management | | | ❓ |
| 21 | Alarm sound selection + preview | | | ❓ |
| 22 | Wake response (confirmed/snoozed/dismissed) | | | ❓ |
| 23 | History view | | | ❓ |
| 24 | Upgrade install (if applicable) | | | N/A |
| 25 | Clean install → cold start performance | | | ❓ |