# Auth Implementation

## Overview

Wake Up Sunshine uses **Supabase Auth** for all authentication flows. Both iOS and Android share the same Supabase backend and support identical auth methods.

## Auth Methods

### 1. Email + Password (Primary)
- **Sign Up**: Email, password, and display name required. Email verification may be required.
- **Sign In**: Email + password against Supabase Auth API.
- **Password Reset**: "Forgot Password?" link on sign-in screen sends a reset email via Supabase `recover` endpoint.

### 2. Phone + OTP (Secondary)
- **Send OTP**: E.164 formatted phone number receives a 6-digit code.
- **Verify OTP**: Code verified against Supabase Auth `verify` endpoint.

## Account Deletion

Users can permanently delete their account from **Settings → Danger Zone → Delete Account**.

### Deletion Flow
1. User taps "Delete Account" → confirmation dialog shown
2. Client calls `DELETE /functions/v1/delete-account` with Bearer token
3. Backend edge function deletes all user data in order:
   - `wake_permissions` (sent & received)
   - `contact_invites` (sent & received)
   - `wake_requests` (sent & received)
   - `user_devices`
   - `unlock_purchases`
   - `users` (public profile)
   - Auth user via `supabase.auth.admin.deleteUser()`
4. Client clears local session and returns to onboarding

### Files Modified
| Platform | File | Change |
|----------|------|--------|
| iOS | `AuthManager.swift` | Added `resetPassword()`, `deleteAccount()` |
| iOS | `EmailAuthView.swift` | Added "Forgot Password?" link + sheet |
| iOS | `SettingsView.swift` | Wired up Delete Account with confirmation alert |
| Android | `SupabaseClient.kt` | Added `resetPassword()`, `deleteAccount()` |
| Android | `AuthViewModel.kt` | Added `resetPassword()`, `deleteAccount()` |
| Android | `EmailAuthScreen.kt` | Added "Forgot Password?" link + dialog |
| Android | `SettingsScreen.kt` | Added Delete Account card + confirmation dialog |
| Backend | `delete-account/index.ts` | New edge function for cascading delete |

## Session Management

### iOS
- Session stored in Keychain via Supabase Swift SDK
- Auto-refresh handled by SDK

### Android
- Session persisted in SharedPreferences (`supabase_session`)
- Token refresh via Supabase `token?grant_type=refresh_token` endpoint
- `getValidSession()` transparently refreshes expired tokens (5 min buffer)
- Session restored on cold start in `AuthViewModel.init`

## Security Considerations

- All API calls require valid Bearer token
- Delete account endpoint validates token server-side before deletion
- Password reset email sent only to the registered email address
- Account deletion is irreversible — confirmation dialog required on both platforms