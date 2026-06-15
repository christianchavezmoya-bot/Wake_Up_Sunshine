import SwiftUI

// MARK: - App Theme
enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case light = "light"
    case dark = "dark"
    case fun = "fun"
    case professional = "professional"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .fun: return "Girly"
        case .professional: return "Professional"
        }
    }
    
    var iconName: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .fun: return "heart.fill"
        case .professional: return "briefcase.fill"
        }
    }
    
    var description: String {
        switch self {
        case .light: return "Always light mode"
        case .dark: return "Always dark mode"
        case .fun: return "Pink & playful vibes"
        case .professional: return "Dark & modern"
        }
    }
}

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "app_theme")
        }
    }
    
    @Published var colorScheme: ColorScheme?
    
    private init() {
        let savedTheme = UserDefaults.standard.string(forKey: "app_theme") ?? "light"
        self.currentTheme = AppTheme(rawValue: savedTheme) ?? .light
        updateColorScheme()
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        updateColorScheme()
    }
    
    private func updateColorScheme() {
        switch currentTheme {
        case .light:
            colorScheme = .light
        case .dark:
            colorScheme = .dark
        case .fun:
            // Girly theme: dark base with pink accents
            colorScheme = .dark
        case .professional:
            // Professional theme: dark modern
            colorScheme = .dark
        }
    }
    
    // MARK: - Theme Colors
    var primaryColor: Color {
        switch currentTheme {
        case .fun:
            return Color(hex: "#FF1493")  // Bright pink
        case .professional:
            return Color(hex: "#60A5FA")  // Modern blue
        default:
            return DesignSystem.Colors.primaryOrange
        }
    }
    
    var secondaryColor: Color {
        switch currentTheme {
        case .fun:
            return Color(hex: "#FF69B4")  // Hot pink
        case .professional:
            return Color(hex: "#334155")  // Dark slate
        default:
            return DesignSystem.Colors.primaryOrangeLight
        }
    }
    
    var wakeGradientStart: Color {
        switch currentTheme {
        case .fun:
            return Color(hex: "#FF1493")  // Bright pink
        case .professional:
            return Color(hex: "#1E293B")  // Dark slate
        default:
            return DesignSystem.Colors.wakeGradientStart
        }
    }
    
    var wakeGradientEnd: Color {
        switch currentTheme {
        case .fun:
            return Color(hex: "#C71585")  // Medium violet red
        case .professional:
            return Color(hex: "#0F172A")  // Very dark slate
        default:
            return DesignSystem.Colors.wakeGradientEnd
        }
    }
    
    // MARK: - Fun Theme Specific Colors
    var funBackgroundColor: Color { Color(hex: "#0A0A0A") }       // Black main background
    var funHeaderColor: Color { Color(hex: "#FF1493") }           // Bright pink header
    var funCardBorderColor: Color { Color(hex: "#FF69B4") }       // Hot pink card border
    var funTabColor: Color { Color(hex: "#4A4A4A") }              // Grey tabs
    
    // MARK: - Professional Theme Specific Colors
    var proBackgroundColor: Color { Color(hex: "#0F172A") }       // Very dark navy
    var proSurfaceColor: Color { Color(hex: "#1E293B") }          // Dark slate surface
    var proAccentColor: Color { Color(hex: "#60A5FA") }           // Modern blue accent
    var proCardBorder: Color { Color(hex: "#334155") }            // Slate border
}