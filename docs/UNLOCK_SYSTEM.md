# Wake Me Up - Unlock System Documentation

## Overview

The Wake Me Up unlock system is a cross-platform invite-based unlock system that allows:
- Users to purchase a lifetime unlock
- Paid users to receive 2 invite credits
- Invites to be shared via link and QR code
- Invited users to get full access without paying
- Works on both iOS and Android

---

## Architecture

### Backend (Supabase + PostgreSQL)

The backend consists of:
1. **Database Tables** (migration `012_unlock_purchase_system.sql`)
   - `unlock_users` - Device-based users with unlock status
   - `purchases` - Purchase records with validation status
   - `unlock_invites` - Invite codes created by paid users
   - `invite_redemptions` - Records of invites redeemed

2. **Edge Functions** (Supabase Functions)
   - `unlock-purchase-validate` - Validates purchases with Apple/Google
   - `unlock-invite-create` - Creates new invite codes
   - `unlock-invite-validate` - Validates invite codes
   - `unlock-invite-redeem` - Redeems invite codes
   - `unlock-get-status` - Gets user unlock status
   - `unlock-landing` - Web landing page for invite links

### Mobile Apps

**iOS (SwiftUI + StoreKit 2)**
- `UnlockManager.swift` - Manages purchases and invites
- `PaywallView.swift` - Purchase UI
- `InviteView.swift` - Invite creation with QR code
- `RedemptionView.swift` - Invite redemption UI
- `DeepLinkManager.swift` - Handles deep links

**Android (Kotlin + Jetpack Compose + Google Play Billing)**
- `UnlockRepository.kt` - API client
- `UnlockViewModel.kt` - State management
- `UnlockScreens.kt` - UI screens (Paywall, Invite, Redemption)

---

## Setup Steps

### 1. Database Migration

Apply the migration to your Supabase database:

```bash
# Using Supabase CLI
supabase db push

# Or manually via SQL editor
# Copy and run the contents of:
# backend/supabase/migrations/012_unlock_purchase_system.sql
```

### 2. Deploy Edge Functions

Deploy all the unlock-related Edge Functions:

```bash
cd backend/supabase

supabase functions deploy unlock-purchase-validate
supabase functions deploy unlock-invite-create
supabase functions deploy unlock-invite-validate
supabase functions deploy unlock-invite-redeem
supabase functions deploy unlock-get-status
supabase functions deploy unlock-landing
```

### 3. Configure iOS (StoreKit 2)

1. **Add In-App Purchase in App Store Connect:**
   - Product ID: `wake_unlock_lifetime`
   - Type: Non-Consumable
   - Price: Set your desired price

2. **Add StoreKit Configuration File:**
   Create `WakeUpSunshine/Resources/Products.storekit`:
   ```json
   {
     "identifier" : "Products",
     "nonRenewingSubscriptions" : [],
     "products" : [
       {
         "displayPrice" : "9.99",
         "familyShareable" : false,
         "internalID" : "wake_unlock_lifetime",
         "localizations" : [],
         "productID" : "wake_unlock_lifetime",
         "referenceName" : "Lifetime Unlock",
         "type" : "NonConsumable"
       }
     ],
     "settings" : {
       "_failTransactionsEnabled" : false,
       "_locale" : "en_US",
       "_storefront" : "USA",
       "_storeKitErrors" : []
     },
     "version" : {
       "major" : 4,
       "minor" : 0
     }
   }
   ```

3. **Configure Universal Links:**
   Add to `WakeUpSunshine.entitlements`:
   ```xml
   <key>com.apple.developer.associated-domains</key>
   <array>
       <string>applinks:wakemeup.app</string>
   </array>
   ```

4. **Add files to Xcode project:**
   - `UnlockManager.swift`
   - `PaywallView.swift`
   - `InviteView.swift`
   - `RedemptionView.swift`

### 4. Configure Android (Google Play Billing)

1. **Add In-App Product in Google Play Console:**
   - Product ID: `wake_unlock_lifetime`
   - Type: Managed product (one-time purchase)
   - Price: Set your desired price

2. **Add Dependencies to `app/build.gradle`:**
   ```groovy
   dependencies {
       // Billing
       implementation 'com.android.billingclient:billing-ktx:6.1.0'
       
       // QR Code generation
       implementation 'com.google.zxing:core:3.5.2'
   }
   ```

3. **Configure App Links:**
   In `AndroidManifest.xml`, add intent filter for deep links:
   ```xml
   <intent-filter android:autoVerify="true">
       <action android:name="android.intent.action.VIEW" />
       <category android:name="android.intent.category.DEFAULT" />
       <category android:name="android.intent.category.BROWSABLE" />
       <data android:scheme="https" android:host="wakemeup.app" android:pathPrefix="/invite" />
   </intent-filter>
   
   <intent-filter>
       <action android:name="android.intent.action.VIEW" />
       <category android:name="android.intent.category.DEFAULT" />
       <category android:name="android.intent.category.BROWSABLE" />
       <data android:scheme="wakeupsunshine" android:host="unlock" />
   </intent-filter>
   ```

### 5. Configure Domain (Optional)

For the landing page at `https://wakemeup.app/invite/{CODE}`:

1. **Point domain to Supabase:**
   - Add custom domain in Supabase Dashboard
   - Configure DNS records

2. **Update URLs in code:**
   - Replace `wakemeup.app` with your domain in all files
   - Update App Store and Google Play URLs

---

## API Reference

### POST /unlock-purchase-validate

Validates a purchase with Apple/Google and grants credits.

**Request:**
```json
{
  "device_id": "string",
  "platform": "ios" | "android",
  "receipt_token": "string",
  "product_id": "wake_unlock_lifetime",
  "transaction_id": "string (optional)"
}
```

**Response:**
```json
{
  "success": true,
  "has_paid": true,
  "invite_credits": 2,
  "message": "Purchase validated successfully"
}
```

### POST /unlock-invite-create

Creates a new invite code.

**Request:**
```json
{
  "device_id": "string"
}
```

**Response:**
```json
{
  "success": true,
  "code": "ABC123XY",
  "invite_id": "uuid",
  "invite_link": "https://wakemeup.app/invite/ABC123XY",
  "deep_link": "wakeupsunshine://unlock/ABC123XY",
  "remaining_credits": 1
}
```

### GET /unlock-invite-validate?code={CODE}

Validates an invite code.

**Response:**
```json
{
  "valid": true,
  "status": "valid",
  "invite_id": "uuid",
  "remaining_uses": 1
}
```

### POST /unlock-invite-redeem

Redeems an invite code for the user.

**Request:**
```json
{
  "code": "ABC123XY",
  "device_id": "string",
  "platform": "ios" | "android"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Welcome! You now have full access to Wake Me Up",
  "user_id": "uuid"
}
```

### GET /unlock-get-status?device_id={DEVICE_ID}

Gets the unlock status for a device.

**Response:**
```json
{
  "success": true,
  "exists": true,
  "has_paid": true,
  "is_invited": false,
  "invite_credits": 2
}
```

---

## Testing Instructions

### Test Purchase Flow (iOS Simulator)

1. Use StoreKit configuration file for testing
2. In Xcode: Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration
3. Select `Products.storekit`
4. Run app and test purchase

### Test Purchase Flow (Android)

1. Add test user in Google Play Console
2. Use test card for purchases
3. Run app and test purchase

### Test Invite Flow

1. **Create Invite:**
   ```
   POST https://YOUR_SUPABASE_URL/functions/v1/unlock-invite-create
   Body: { "device_id": "test-device-1" }
   ```

2. **Validate Invite:**
   ```
   GET https://YOUR_SUPABASE_URL/functions/v1/unlock-invite-validate?code=ABC123XY
   ```

3. **Redeem Invite:**
   ```
   POST https://YOUR_SUPABASE_URL/functions/v1/unlock-invite-redeem
   Body: { "code": "ABC123XY", "device_id": "test-device-2" }
   ```

4. **Check Status:**
   ```
   GET https://YOUR_SUPABASE_URL/functions/v1/unlock-get-status?device_id=test-device-2
   ```

### Test Deep Links

**iOS (Simulator):**
```bash
xcrun simctl openurl booted "wakeupsunshine://unlock/ABC123XY"
```

**Android (Emulator):**
```bash
adb shell am start -a android.intent.action.VIEW -d "wakeupsunshine://unlock/ABC123XY"
```

### Test Landing Page

Visit: `https://YOUR_SUPABASE_URL/functions/v1/unlock-landing/invite/ABC123XY`

---

## Security Considerations

1. **Receipt Validation:** In production, always validate receipts with Apple/Google servers
2. **Rate Limiting:** Consider adding rate limits to prevent abuse
3. **Code Expiry:** Invite codes expire after 48 hours by default
4. **Self-Invite Prevention:** Users cannot redeem their own invites
5. **One-Time Use:** Each invite can only be used once

---

## Troubleshooting

### iOS Issues

**Product not loading:**
- Check StoreKit configuration
- Verify product ID matches App Store Connect
- Ensure you're signed in with a sandbox account

**Receipt validation fails:**
- Verify receipt is base64 encoded
- Check Apple's servers are reachable
- Try in sandbox environment first

### Android Issues

**Billing unavailable:**
- Ensure Google Play Services is installed
- Check device supports Play Billing
- Verify app is signed with correct key

**Purchase not acknowledged:**
- Check acknowledgment in `handlePurchase()`
- Verify purchase token is sent to backend

### Backend Issues

**Function fails:**
- Check Supabase logs
- Verify environment variables are set
- Test function locally with `supabase functions serve`

---

## File Structure

```
backend/supabase/
├── migrations/
│   └── 012_unlock_purchase_system.sql
└── functions/
    ├── unlock-purchase-validate/
    │   └── index.ts
    ├── unlock-invite-create/
    │   └── index.ts
    ├── unlock-invite-validate/
    │   └── index.ts
    ├── unlock-invite-redeem/
    │   └── index.ts
    ├── unlock-get-status/
    │   └── index.ts
    └── unlock-landing/
        └── index.ts

ios/WakeUpSunshine/
├── Services/
│   ├── UnlockManager.swift
│   └── DeepLinkManager.swift
└── Features/
    └── Unlock/
        ├── PaywallView.swift
        ├── InviteView.swift
        └── RedemptionView.swift

android/app/src/main/kotlin/com/wakeupsunshine/
├── data/
│   └── UnlockRepository.kt
└── ui/
    └── unlock/
        ├── UnlockViewModel.kt
        └── UnlockScreens.kt
```

---

## Production Checklist

- [ ] Update product IDs in App Store Connect and Google Play Console
- [ ] Configure Universal Links / App Links for your domain
- [ ] Update all URLs from placeholder to production
- [ ] Enable Apple receipt validation in production
- [ ] Enable Google Play Developer API for server-side validation
- [ ] Set up monitoring and alerts for Edge Functions
- [ ] Test end-to-end on real devices
- [ ] Create app store screenshots for new features