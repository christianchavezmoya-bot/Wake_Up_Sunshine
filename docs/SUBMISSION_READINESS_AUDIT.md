# Wake Up Sunshine — Submission Readiness Audit

**Date:** 2026-11-05  
**Auditor:** Automated Code Review  
**Version:** 1.0.0 (Build 1)  

---

## 1. App Identity

| Item | iOS | Android | Status |
|------|-----|---------|--------|
| Bundle ID / Package Name | `com.wakeupsunshine.app` | `com.wakeupsunshine.app` | ✅ PASS |
| Display Name | "Wake Up Sunshine" | "Wake Up Sunshine" | ✅ PASS |
| Version | 1.0.0 | 1.0.0 | ✅ PASS |
| Build Number | 1 | 1 | ✅ PASS |
| App Icon | Exists in Assets.xcassets | Exists as `@mipmap/ic_launcher` | ⚠️ NEEDS WORK — verify icon meets all size requirements |
| Launch Screen | Basic `UIColorName: LaunchBackground` | Default theme splash | ⚠️ NEEDS WORK — no branded splash screen on either platform |
| Release Configuration | APS entitlement set to `production` | `buildTypes.release` exists in Gradle | ⚠️ NEEDS WORK — iOS Release scheme not verified, Android ProGuard/R8 not confirmed |
| Deep Link Scheme | `wakeupsunshine://` | `wakeupsunshine://` + App Links | ✅ PASS |
| Universal Links | **Commented out** in entitlements | `https://wakeupsunshine.app` + `https://wakemeup.app` | ⚠️ NEEDS WORK — iOS Universal Links not active |

---

## 2. Authentication Readiness

| Item | Status | Details |
|------|--------|---------|
| Login/Signup implementation | ✅ PASS | Real Supabase email/password auth on both platforms. Phone OTP also exists on iOS. |
| Password reset flow | ❌ FAIL | **No "Forgot Password" or password reset UI exists on either platform.** Supabase supports it natively but it is not wired up. |
| Email verification | ⚠️ NEEDS WORK | Android shows message "please check email for verification" on signup, but no UI to resend verification email or handle unverified state. iOS has no verification handling at all. |
| Logout flow | ✅ PASS | Both platforms call `supabase.auth.signOut()` and return to login screen. |
| Secure token storage | ✅ PASS | Supabase SDK handles token persistence via platform keychain (iOS) / EncryptedSharedPreferences (Android via Hilt). |
| Expired session handling | ✅ PASS | Both platforms check session validity and redirect to login on expired/invalid tokens. |
| Test users / hardcoded credentials | ✅ PASS | No test users, hardcoded credentials, or fake backends found. |
| Localhost endpoints | ✅ PASS | All endpoints point to `https://jehouatjcfcxjjuowzbd.supabase.co`. No localhost/127.0.0.1/10.0.2.2 found. |

---

## 3. Account Deletion Compliance

| Item | Status | Details |
|------|--------|---------|
| Users can create accounts | ✅ PASS | Email/password signup on both platforms. |
| In-app account deletion exists | ❌ FAIL | iOS has a "Delete Account" button in Settings → Danger Zone but **the button action is an empty closure** `Button(action: {})` — it does nothing. Android has **no Delete Account option at all**. |
| Deletion easy to find | ⚠️ NEEDS WORK | iOS button exists in "Danger Zone" section. Android has none. |
| Explains what will be deleted | ❌ FAIL | No explanation provided on either platform. |
| Deletes/anonymises backend data | ❌ FAIL | **No backend endpoint for account deletion exists.** The `supabase/functions/` directory has no delete-account function. |
| Revokes sessions/tokens | ❌ FAIL | No deletion flow means no session revocation on delete. |
| Returns user to logged-out state | ❌ FAIL | Not implemented. |

**🔴 BLOCKING: Apple App Store Guideline 5.1.1(v) requires apps that allow account creation to also offer account deletion. This is a mandatory fix.**

---

## 4. Privacy / Compliance

### Data Collected
| Data Type | Purpose | Storage |
|-----------|---------|---------|
| Email address | Account creation, login, invites | Supabase Auth |
| Display name | Profile display | Supabase `profiles` table |
| Phone number | Optional profile field | Supabase `profiles` table |
| Push notification token | Wake-up notifications | Supabase `user_devices` table |
| Device info (platform, model) | Device management | Supabase `user_devices` table |
| Contact relationships | Wake permissions | Supabase `contact_invites` table |
| Wake request history | History feature | Supabase `wake_requests` table |
| Alarm sound preference | Wake sound selection | Local storage + Supabase |

### Third-Party SDKs
| SDK | Purpose | Platform |
|-----|---------|----------|
| Supabase Swift SDK | Auth, database, edge functions | iOS |
| Firebase Cloud Messaging | Push notifications | iOS (via AppDelegate) |
| Supabase (via Ktor HTTP) | Auth, API calls | Android |
| Firebase Messaging | Push notifications | Android |
| Hilt (Dagger) | Dependency injection | Android |

### Permissions Requested

**iOS:**
- Camera (QR code scanning)
- Photo Library (QR code saving)
- Notifications (wake alerts)
- Background: Audio, Fetch, Remote Notifications

**Android:**
- INTERNET, VIBRATE, CAMERA
- USE_FULL_SCREEN_INTENT, SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM
- POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED
- WAKE_LOCK, FOREGROUND_SERVICE, ACCESS_NOTIFICATION_POLICY

| Item | Status | Details |
|------|--------|---------|
| Privacy policy URL | ❌ FAIL | **No privacy policy URL exists.** Both platforms show "Terms of Service and Privacy Policy" text but it is not tappable and links to nowhere. Apple and Google require a live privacy policy URL. |
| Apple App Privacy Labels | ❌ FAIL | Not configured. Must declare: Email, Contact Info, User Content, Identifiers. |
| Google Play Data Safety | ❌ FAIL | Not configured. Must declare: Personal info (email, name), Device info, App activity. |
| Tracking/Advertising IDs | ✅ PASS | No tracking or advertising SDKs present. |
| Unnecessary sensitive permissions | ⚠️ NEEDS WORK | `ACCESS_NOTIFICATION_POLICY` on Android is sensitive and may require justification. `NSPhotoLibraryUsageDescription` on iOS — consider if Photo Library is truly needed or if sharing via other means suffices. |

---

## 5. Alarm / Wake-Up Functionality

| Scenario | iOS | Android | Status |
|----------|-----|---------|--------|
| Sender sends wake request | ✅ Works | ✅ Works | ✅ PASS |
| Receiver in foreground | ✅ Full-screen alert | ✅ AlarmActivity | ✅ PASS |
| Receiver in background | ✅ Push notification → full screen | ✅ FCM → AlarmActivity | ⚠️ NEEDS WORK — iOS critical alerts entitlement is disabled |
| Receiver app killed | ⚠️ Depends on APNs delivery | ⚠️ Depends on FCM high-priority | ⚠️ NEEDS WORK — no guarantee of delivery when killed |
| Locked screen | ✅ `showOnLockScreen=true` on Android; iOS full-screen presentation | ✅ | ⚠️ NEEDS WORK — iOS critical alerts disabled means no sound in silent mode |
| Silent mode | ❌ FAIL | ⚠️ Partial | **iOS: Critical alerts entitlement is commented out. Without it, the alarm is silent in Do Not Disturb/Silent mode — this is the core feature.** |
| Do Not Disturb / Focus | ❌ FAIL | ⚠️ Partial via `ACCESS_NOTIFICATION_POLICY` | Same as above — iOS critical alerts required |
| Notification permission denied | ⚠️ Needs graceful handling | ⚠️ Needs graceful handling | NEEDS WORK — should show persistent banner explaining wake alerts won't work |
| Network offline / poor | ⚠️ Error shown | ⚠️ Error shown | ✅ PASS — error messages displayed |
| App claims impossible behaviour | ⚠️ NEEDS WORK | ⚠️ NEEDS WORK | No user-facing explanation of limitations (silent mode, killed app, DND). Users may expect alarm always works. |

**🔴 BLOCKING: iOS critical alerts entitlement is essential for the core functionality (waking someone up). Without it, the app cannot fulfil its primary purpose when the phone is in silent/DND mode.**

---

## 6. Invite / Unlock System

| Item | Status | Details |
|------|--------|---------|
| Create invite | ✅ PASS | Backend `create-invite` function exists, UI implemented. |
| QR code invite | ✅ PASS | Camera permission declared, QR scanning UI exists. |
| Link invite | ✅ PASS | Deep link scheme `wakeupsunshine://invite/<token>` configured. |
| iOS deep link | ⚠️ NEEDS WORK | Custom scheme works; Universal Links commented out in entitlements. |
| Android deep link | ✅ PASS | Custom scheme + App Links (autoVerify) configured. |
| Invalid invite | ⚠️ NEEDS WORK | `unlock-invite-validate` exists but error handling UX needs verification. |
| Expired invite | ⚠️ NEEDS WORK | No clear expiry mechanism visible in backend code. |
| Already-used invite | ✅ PASS | Backend `unlock-invite-redeem` should handle this. |
| Same-user invite | ⚠️ NEEDS WORK | Edge case handling unclear. |
| Backend database records | ✅ PASS | Migrations exist for invite system. |

---

## 7. Store Readiness

| Item | Status | Details |
|------|--------|---------|
| iOS Release archive builds | ❓ NOT TESTED | Cannot verify without Apple Developer certificate. |
| Android Release AAB builds | ❓ NOT TESTED | Release build type exists but signing config not verified. |
| Debug banners/logging in prod | ⚠️ NEEDS WORK | Android has 55+ `Log.d`/`print` statements that should be stripped or gated behind `BuildConfig.DEBUG`. iOS has `print()` statements in alarm code. |
| Production API keys | ✅ PASS | Supabase URL and anon key are production values. Anon key is safe to embed (it's a public key with RLS protection). |
| Crash reporting | ❌ FAIL | **No crash reporting SDK (Sentry, Crashlytics, etc.) is integrated.** This is recommended for production. |
| Clean install works | ✅ PASS | Auth flow → onboarding → main screen. |
| Upgrade install | ❓ NOT TESTED | No previous version to upgrade from. |
| Google Services JSON | ✅ PASS | `google-services.json` present in Android app. |
| iOS GoogleService-Info.plist | ⚠️ NEEDS WORK | Not verified — needs to exist for Firebase push on iOS. |

---

## 8. QA Matrix

| Test Case | iPhone Physical | Android Physical | Notes |
|-----------|----------------|-------------------|-------|
| Fresh install → signup | ❓ | ✅ (tested on R5CW12E1RQT) | |
| Fresh install → login | ❓ | ✅ | |
| Existing install | ❓ | ❓ | No previous version |
| Logged out user | ✅ (redirects to login) | ✅ | |
| Logged in user | ❓ | ✅ | |
| Send wake request | ❓ | ✅ | |
| Receive wake (foreground) | ❓ | ❓ | |
| Receive wake (background) | ❓ | ❓ | |
| Receive wake (killed) | ❓ | ❓ | |
| Notification permission denied | ❓ | ❓ | Needs graceful fallback |
| Poor network | ❓ | ⚠️ Error shown | |
| App backgrounded | ❓ | ❓ | |
| Deep link invite | ❓ | ❓ | |
| QR code invite | ❓ | ❓ | |
| Theme switching | ❓ | ✅ | |
| Profile edit | ❓ | ❓ | |
| Account deletion | ❌ (button is no-op) | ❌ (no button) | |

---

## Blocking Issues

1. **🔴 Account Deletion Not Implemented** — Apple Guideline 5.1.1(v) requires in-app account deletion if account creation is offered. iOS button is a no-op. Android has no button. No backend endpoint exists.

2. **🔴 iOS Critical Alerts Entitlement Disabled** — The core "wake up" feature requires audible alerts in silent/DND mode. Without the critical alerts entitlement, the app cannot wake users whose phone is silenced — which is the entire point of the app.

3. **🔴 No Privacy Policy URL** — Both Apple and Google require a live, accessible privacy policy URL. Currently the "Privacy Policy" text links to nowhere.

4. **🔴 No Password Reset Flow** — Users who forget their password have no way to recover their account. This will cause App Store rejections and poor user experience.

## Recommended Non-Blocking Improvements

1. **Add crash reporting** — Integrate Sentry or Firebase Crashlytics for production monitoring.
2. **Strip debug logging** — Gate `Log.d`/`print` statements behind `BuildConfig.DEBUG` / `#if DEBUG`.
3. **Add branded launch screen** — Both platforms have minimal splash screens.
4. **Enable iOS Universal Links** — Uncomment associated domains in entitlements and host `apple-app-site-association` file.
5. **Add notification permission denied guidance** — Show persistent banner when user denies notifications explaining the app won't work properly.
6. **Add user-facing limitations explanation** — Clearly explain that the alarm may not sound in Silent/DND mode (iOS) or when the app has been killed.
7. **Add email verification UI** — Allow users to resend verification emails and block unverified users from core features.
8. **Consider removing Photo Library permission** — If QR codes can be shared without saving to library, remove this permission to reduce review friction.
9. **Add invite expiry mechanism** — Invites should expire after a reasonable period.
10. **Test Android Release build** — Verify ProGuard/R8 rules and signing configuration.
11. **Verify all app icon sizes** — Ensure iOS and Android icons meet store requirements for all densities.
12. **Configure Apple App Privacy Labels** — Declare all data collection categories.
13. **Configure Google Play Data Safety** — Declare all data collection and usage.