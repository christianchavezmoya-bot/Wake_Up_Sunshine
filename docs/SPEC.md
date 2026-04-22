# Wake Up Sunshine - Design Specification

## Overview

Wake Up Sunshine is a trusted wake system that allows users to send guaranteed wake-up alerts to their trusted contacts. The app uses iOS Critical Alerts to ensure alarms are never missed.

## Design System

### Color Palette

| Name | Hex Code | Usage |
|------|----------|-------|
| Primary Orange | `#FF6B35` | Main brand color, CTAs, icons |
| Primary Orange Light | `#FF8F66` | Gradients, hover states |
| Secondary | `#2D3047` | Text, headers |
| Accent Teal | `#1B998B` | Success states, confirmations |
| Background | `#FAF9F7` | Screen backgrounds |
| Surface | `#FFFFFF` | Cards, modals |
| Success | `#2ECC71` | Confirmed status |
| Error | `#E63946` | Errors, blocked states |

### Typography

| Style | Font | Size | Weight |
|-------|------|------|--------|
| Large Title | SF Pro Display | 34pt | Bold |
| Title 1 | SF Pro Display | 28pt | Bold |
| Title 2 | SF Pro Display | 22pt | Semibold |
| Headline | SF Pro Text | 17pt | Semibold |
| Body | SF Pro Text | 17pt | Regular |
| Callout | SF Pro Text | 16pt | Regular |
| Subhead | SF Pro Text | 15pt | Regular |
| Footnote | SF Pro Text | 13pt | Regular |
| Caption | SF Pro Text | 12pt | Regular |

### Spacing System (8pt Grid)

- XS: 4pt
- SM: 8pt
- MD: 16pt
- LG: 24pt
- XL: 32pt
- XXL: 48pt

### Corner Radius

- Small: 8pt
- Medium: 12pt
- Large: 16pt
- XLarge: 24pt
- Full: 9999pt (pills/circles)

### Shadows

```swift
// Card shadow
shadow(color: .black.opacity(0.08), radius: 20, y: 10)

// Button shadow
shadow(color: PrimaryOrange.opacity(0.4), radius: 8, y: 4)
```

## Screen Structure

### 1. Onboarding Flow

**6 Steps:**

1. **Welcome**
   - Hero illustration with pulsing bell
   - "Never Miss What Matters" headline
   - "Get Started" CTA

2. **Phone Input**
   - Phone number field with country code
   - Continue button

3. **OTP Verification**
   - 6-digit OTP input with auto-focus
   - Resend timer (60s)
   - Verify button

4. **Notifications Permission**
   - Explanation card
   - Toggle to enable

5. **Critical Alerts Permission**
   - Warning card with explanation
   - Enable button

6. **Ready**
   - Success animation with pulsing circles
   - "Start Using Wake Up Sunshine" CTA

### 2. Main App (Tab Bar)

**4 Tabs:**

- **Home** - Contact grid with wake buttons
- **Contacts** - Permission management
- **History** - Wake timeline
- **Settings** - Profile and preferences

### 3. Home Screen

- Header with greeting + profile avatar
- Section: "People I Can Wake"
- 2-column grid of contact cards
- Each card has:
  - Avatar with online indicator
  - Name
  - Status (Online/Offline)
  - Wake button (pulsing circle)

### 4. Contact Card

```
┌─────────────────┐
│  [Avatar]  ●   │  ← Online indicator
│                 │
│   Alex Chen     │  ← Name
│     Online      │  ← Status
│                 │
│    [🔔]         │  ← Wake button
│                 │
└─────────────────┘
```

### 5. Wake Alert Screen (Full Screen Overlay)

**Orange gradient background with:**

- Pulsing glow effect (background)
- Large bell icon with shake animation
- "Wake Up!" title
- Sender name
- Optional message
- "I'm Awake" button (white)
- "Snooze (5 min)" button (translucent)

### 6. Settings Screen

**Sections:**

- **Profile** - User info row
- **Devices** - List of registered devices
- **Notifications** - Critical alerts toggle, alarm sound
- **Privacy** - Blocked contacts
- **Danger Zone** - Delete account

## Components

### Buttons

**Primary Button:**
```swift
.font(.headline)
.foregroundColor(.white)
.frame(maxWidth: .infinity)
.padding(.vertical, 16)
.background(PrimaryOrange)
.cornerRadius(16)
```

**Secondary Button:**
```swift
.background(Surface)
.foregroundColor(Primary)
.border(Color.gray.opacity(0.3), width: 1)
.cornerRadius(16)
```

### Cards

```swift
.padding(20)
.background(Surface)
.cornerRadius(16)
.shadow(color: .black.opacity(0.08), radius: 20, y: 10)
```

### Avatar

```swift
Circle()
    .fill(avatarColor)
    .frame(width: 64, height: 64)
    .overlay(
        Text(name.prefix(1).uppercased())
            .font(.title)
            .foregroundColor(.white)
    )
```

### Wake Button

```swift
Circle()
    .fill(LinearGradient(PrimaryOrange, PrimaryOrangeLight))
    .frame(width: 56, height: 56)
    .shadow(color: PrimaryOrange.opacity(0.4), radius: 8, y: 4)
    .overlay(
        Image(systemName: "bell.fill")
            .foregroundColor(.white)
    )
    .overlay(
        Circle()
            .stroke(PrimaryOrange, lineWidth: 2)
            .modifier(PulseRingAnimation())
    )
```

## Animations

### Pulse Ring Animation
```swift
.scaleEffect(isAnimating ? 1.3 : 1.0)
.opacity(isAnimating ? 0 : 0.8)
.animation(.easeOut(duration: 1.5).repeatForever, value: isAnimating)
```

### Shake Animation
```swift
.rotationEffect(.degrees(isAnimating ? -5 : 5))
.animation(.easeInOut(duration: 0.1).repeatForever, value: isAnimating)
```

### Glow Pulse Animation
```swift
.scaleEffect(isAnimating ? 1.3 : 1.0)
.opacity(isAnimating ? 0 : 0.5)
.animation(.easeInOut(duration: 1.5).repeatForever, value: isAnimating)
```

## User Flows

### Onboarding
1. Open app → Welcome screen
2. Tap "Get Started"
3. Enter phone number
4. Enter OTP
5. Enable notifications
6. Enable Critical Alerts
7. → Main app

### Send Wake Alert
1. Open app → Home tab
2. Tap wake button on contact card
3. Alert sent confirmation
4. Contact receives Critical Alert

### Receive Wake Alert
1. Critical Alert arrives
2. Full-screen alarm shows
3. Tap "I'm Awake" or "Snooze"
4. → Sender sees confirmed status

## Responsive Design

- Optimized for iPhone (375pt width)
- Adapts to larger screens
- Minimum touch target: 44pt × 44pt

## Accessibility

- Dynamic Type support
- VoiceOver labels on all interactive elements
- High contrast colors
- Haptic feedback for important actions

## Assets Required

### App Icon
- 1024×1024 App Store icon
- Sunrise/wake theme
- Orange gradient background

### SF Symbols Used
- `bell.badge.fill` - Wake button
- `house.fill` - Home tab
- `person.2.fill` - Contacts tab
- `clock.fill` - History tab
- `gearshape.fill` - Settings tab
- `plus` - Add contact
- `checkmark` - Confirm
- `xmark` - Cancel/Block
- `chevron.right` - Navigation
- `moon.fill` - Snooze
- `exclamationmark.triangle.fill` - Warning
- `qrcode.viewfinder` - QR code
- `message.fill` - SMS invite