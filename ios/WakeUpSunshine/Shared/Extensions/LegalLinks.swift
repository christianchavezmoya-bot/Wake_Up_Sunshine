import SwiftUI

enum AppLegalLinks {
    static let termsOfService = URL(string: "https://wakeupsunshine.app/terms")!
    static let privacyPolicy = URL(string: "https://wakeupsunshine.app/privacy")!
}

struct LegalDisclaimerView: View {
    var body: some View {
        Group {
            Text("By continuing, you agree to our ")
            + Text(.init("[Terms of Service](\(AppLegalLinks.termsOfService.absoluteString))"))
            + Text(" and ")
            + Text(.init("[Privacy Policy](\(AppLegalLinks.privacyPolicy.absoluteString))"))
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .tint(DesignSystem.Colors.primaryOrange)
    }
}
