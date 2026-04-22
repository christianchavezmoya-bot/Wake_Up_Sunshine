import SwiftUI

// MARK: - Design System
struct DesignSystem {
    // MARK: - Colors
    struct Colors {
        // Primary Brand Colors
        static let primaryOrange = Color(hex: "#FF6B1A")
        static let primaryOrangeLight = Color(hex: "#FF9051")
        static let primaryOrangeDark = Color(hex: "#E55A00")

        // Background Colors - Light Mode
        static let backgroundLight = Color(hex: "#FFFFFF")
        static let surfaceLight = Color(hex: "#F5F5F7")
        static let cardLight = Color(hex: "#FFFFFF")

        // Background Colors - Dark Mode
        static let backgroundDark = Color(hex: "#000000")
        static let surfaceDark = Color(hex: "#1C1C1E")
        static let cardDark = Color(hex: "#2C2C2E")

        // Text Colors - Light Mode
        static let textPrimaryLight = Color(hex: "#1A1A1A")
        static let textSecondaryLight = Color(hex: "#6B6B6B")
        static let textTertiaryLight = Color(hex: "#9B9B9B")

        // Text Colors - Dark Mode
        static let textPrimaryDark = Color(hex: "#FFFFFF")
        static let textSecondaryDark = Color(hex: "#AEAEB2")
        static let textTertiaryDark = Color(hex: "#636366")

        // Semantic Colors
        static let success = Color(hex: "#34C759")  // Green - FIXED!
        static let successLight = Color(hex: "#E8F8ED")

        static let error = Color(hex: "#FF3B30")
        static let errorLight = Color(hex: "#FFEBEA")

        static let warning = Color(hex: "#FF9500")
        static let warningLight = Color(hex: "#FFF5E6")

        // Neutral Colors
        static let divider = Color(hex: "#E5E5EA")
        static let dividerDark = Color(hex: "#38383A")

        // Wake Alert Gradient
        static let wakeGradientStart = Color(hex: "#FF6B1A")
        static let wakeGradientEnd = Color(hex: "#FF3B30")
    }

    // MARK: - Spacing (4pt Grid System)
    struct Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48

        // Card specific
        static let cardPadding: CGFloat = 16
        static let cardRadius: CGFloat = 16
        static let buttonRadius: CGFloat = 12
        static let avatarRadius: CGFloat = 50
    }

    // MARK: - Touch Targets (iOS Minimum: 44pt)
    struct TouchTargets {
        static let minimum: CGFloat = 44
        static let standard: CGFloat = 56
        static let large: CGFloat = 64
    }

    // MARK: - Shadows
    struct Shadows {
        static let cardShadow = (color: Color.black.opacity(0.08), radius: CGFloat(12), x: CGFloat(0), y: CGFloat(4))
        static let buttonShadow = (color: Color.black.opacity(0.15), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
    }
}

// MARK: - Adaptive Colors (Light/Dark Mode Support)
extension Color {
    // Backgrounds
    static var appBackground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(DesignSystem.Colors.backgroundDark)
                : UIColor(DesignSystem.Colors.backgroundLight)
        })
    }

    static var appSurface: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(DesignSystem.Colors.surfaceDark)
                : UIColor(DesignSystem.Colors.surfaceLight)
        })
    }

    static var appCard: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(DesignSystem.Colors.cardDark)
                : UIColor(DesignSystem.Colors.cardLight)
        })
    }

    // Text
    static var textPrimary: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(DesignSystem.Colors.textPrimaryDark)
                : UIColor(DesignSystem.Colors.textPrimaryLight)
        })
    }

    static var textSecondary: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(DesignSystem.Colors.textSecondaryDark)
                : UIColor(DesignSystem.Colors.textSecondaryLight)
        })
    }

    static var textTertiary: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(DesignSystem.Colors.textTertiaryDark)
                : UIColor(DesignSystem.Colors.textTertiaryLight)
        })
    }

    // Dividers
    static var appDivider: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(DesignSystem.Colors.dividerDark)
                : UIColor(DesignSystem.Colors.divider)
        })
    }
}

// MARK: - Animation Extensions
extension Animation {
    static var springStandard: Animation {
        .spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0)
    }

    static var springBounce: Animation {
        .spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)
    }

    static var springGentle: Animation {
        .spring(response: 0.6, dampingFraction: 0.85, blendDuration: 0)
    }

    static var pulseAnimation: Animation {
        .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Date Extension
extension Date {
    func timeAgo() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: self, to: now)

        if let day = components.day, day > 0 {
            return day == 1 ? "Yesterday" : "\(day) days ago"
        } else if let hour = components.hour, hour > 0 {
            return hour == 1 ? "1 hour ago" : "\(hour) hours ago"
        } else if let minute = components.minute, minute > 0 {
            return minute == 1 ? "1 minute ago" : "\(minute) minutes ago"
        } else {
            return "Just now"
        }
    }

    func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: self)
    }

    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}

// MARK: - String Extension
extension String {
    var isValidPhoneNumber: Bool {
        let phoneRegex = "^[+]?[0-9]{10,14}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: self.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: ""))
    }

    func formattedPhoneNumber() -> String {
        let digits = self.filter { $0.isNumber }
        if digits.count == 10 {
            let areaCode = String(digits.prefix(3))
            let prefix = String(digits.dropFirst(3).prefix(3))
            let suffix = String(digits.suffix(4))
            return "(\(areaCode)) \(prefix)-\(suffix)"
        }
        return self
    }
}

// MARK: - View Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    // Card style modifier
    func cardStyle() -> some View {
        self
            .background(Color.appCard)
            .cornerRadius(DesignSystem.Spacing.cardRadius)
            .shadow(
                color: DesignSystem.Shadows.cardShadow.color,
                radius: DesignSystem.Shadows.cardShadow.radius,
                x: DesignSystem.Shadows.cardShadow.x,
                y: DesignSystem.Shadows.cardShadow.y
            )
    }

    // Primary button style
    func primaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.TouchTargets.standard)
            .background(Color.primaryOrange)
            .cornerRadius(DesignSystem.Spacing.buttonRadius)
            .shadow(
                color: DesignSystem.Shadows.buttonShadow.color,
                radius: DesignSystem.Shadows.buttonShadow.radius,
                x: DesignSystem.Shadows.buttonShadow.x,
                y: DesignSystem.Shadows.buttonShadow.y
            )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
