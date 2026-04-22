import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            if !appState.isOnboardingComplete {
                OnboardingFlowView()
            } else if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .fullScreenCover(isPresented: $appState.showingWakeAlert) {
            if let wakeRequest = appState.activeWakeRequest {
                WakeAlertView(wakeRequest: wakeRequest)
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .environmentObject(AuthManager())
        .environmentObject(PushNotificationManager())
}