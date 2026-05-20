# Privacy & Data Map

## Data Collected

| Data Type | Purpose | Storage | Retention |
|-----------|---------|---------|-----------|
| Email | Account authentication | Supabase Auth | Until account deletion |
| Password (hashed) | Authentication | Supabase Auth (bcrypt) | Until account deletion |
| Display Name | User identity / greeting | `users` table | Until account deletion |
| Phone Number | Optional contact method | `users` table | Until account deletion |
| Device Token (FCP/APNs) | Push notifications | `user_devices` table | Until device unregistered or account deletion |
| Device Info | Device management | `user_devices` table | Until device unregistered or account deletion |
| Contact Relationships | Wake permission grants | `wake_permissions` table | Until contact removed or account deletion |
| Wake History | Wake request/response records | `wake_requests` table | Until account deletion |
| Purchase Records | Unlock feature verification | `unlock_purchases` table | Until account deletion |

## Data Sharing

- **No third-party sharing** of personal data
- Contact relationships are mutual: both parties can see each other's display name
- Push notification tokens are used solely for delivering wake calls

## Data Deletion

### User-Initiated (In-App)
Users can delete their account from **Settings → Delete Account**. This triggers:

1. Server-side cascade deletion of all user data (see `delete-account` edge function)
2. Removal of all wake permissions, invites, and request history
3. Deletion of device registrations and push tokens
4. Deletion of the auth user record
5. Local session cleared on device

### What Remains After Deletion
- **Aggregated analytics** (if any) are anonymized and not linked to user identity
- **Push notification tokens** are immediately invalidated with Apple/Google

## Platform-Specific Storage

### iOS
- Auth session: iOS Keychain (managed by Supabase SDK)
- Biometric preference: Keychain
- Alarm preference: UserDefaults
- Theme preference: UserDefaults

### Android
- Auth session: SharedPreferences (encrypted on devices with file-based encryption)
- Biometric preference: SharedPreferences
- Alarm preference: SharedPreferences
- Theme preference: DataStore

## Compliance Notes

- **GDPR**: Users can request data export via Supabase dashboard; deletion is self-service
- **CCPA**: No data sold to third parties; deletion available in-app
- **App Store Review**: Account deletion required per guideline 5.1.1(v) — implemented ✓
- **Google Play Policy**: Account deletion required — implemented ✓