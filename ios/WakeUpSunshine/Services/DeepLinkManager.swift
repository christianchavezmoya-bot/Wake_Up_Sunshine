import Foundation
import SwiftUI

/// Handles incoming deep links for both contact invites and unlock invites.
/// - Contact invite: `wakeupsunshine://invite/<token>`
/// - Unlock invite: `wakeupsunshine://unlock/<code>`
/// Stores the token/code until the user is authenticated/ready, then processes.
@MainActor
final class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()

    @Published var showInviteResult = false
    @Published var inviteResultTitle = ""
    @Published var inviteResultMessage = ""
    
    // Unlock invite handling
    @Published var pendingUnlockCode: String?
    @Published var showRedemptionSheet = false

    private(set) var pendingToken: String?

    private init() {}

    // MARK: - URL handling

    func handle(url: URL) {
        guard url.scheme?.lowercased() == "wakeupsunshine" else { return }
        
        let host = url.host?.lowercased()
        let pathComponent = url.lastPathComponent
        
        guard !pathComponent.isEmpty, pathComponent != "/" else { return }
        
        switch host {
        case "invite":
            // Contact invite: wakeupsunshine://invite/<64-char-token>
            pendingToken = pathComponent
            print("[DeepLink] Stored contact invite token: \(pathComponent.prefix(8))…")
            
        case "unlock":
            // Unlock invite: wakeupsunshine://unlock/<8-char-code>
            pendingUnlockCode = pathComponent.uppercased()
            showRedemptionSheet = true
            print("[DeepLink] Stored unlock invite code: \(pathComponent)")
            
        default:
            print("[DeepLink] Unknown deep link host: \(host ?? "nil")")
        }
    }
    
    // MARK: - Process Unlock Invite from Universal Link
    func handleUniversalLink(_ url: URL) {
        // Expected: https://wakeupsunshine.app/invite/<code>
        guard let host = url.host?.lowercased(),
              host == "wakeupsunshine.app" || host == "wakemeup.app" else { return }
        
        let pathComponents = url.pathComponents
        // pathComponents = ["/", "invite", "<code>"]
        
        if pathComponents.count >= 3 && pathComponents[1] == "invite" {
            let code = pathComponents[2].uppercased()
            if code.count == 8 {
                pendingUnlockCode = code
                showRedemptionSheet = true
                print("[DeepLink] Universal link unlock code: \(code)")
            }
        }
    }

    // MARK: - Accept Contact Invite

    func processPendingInvite() async {
        guard let token = pendingToken else { return }
        pendingToken = nil
        print("[DeepLink] Accepting invite token: \(token.prefix(8))…")

        do {
            // inviteId: "" is falsy in JS → backend falls through to use inviteToken
            let result = try await InviteService.shared.acceptInvite(inviteId: "", inviteToken: token)
            inviteResultTitle = result.success ? "Invite Accepted!" : "Invite Failed"
            inviteResultMessage = result.success
                ? "You are now connected. You'll see each other in your contacts."
                : (result.error ?? "The invite may have expired or already been used.")
            if result.success {
                NotificationCenter.default.post(name: .contactsShouldRefresh, object: nil)
            }
        } catch {
            inviteResultTitle = "Invite Failed"
            inviteResultMessage = error.localizedDescription
        }
        showInviteResult = true
    }
    
    // MARK: - Clear Unlock Code
    func clearUnlockCode() {
        pendingUnlockCode = nil
        showRedemptionSheet = false
    }
}
