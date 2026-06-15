import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var pushManager: PushNotificationManager
    @EnvironmentObject var deepLinkManager: DeepLinkManager

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else if authManager.requiresBiometricAuth {
                BiometricLockView()
            } else {
                OnboardingFlowView()
            }
        }
        // Incoming wake alarm
        .fullScreenCover(isPresented: $pushManager.showingWakeAlert) {
            if let wakeRequest = pushManager.activeWakeRequest {
                WakeAlertView(
                    wakeRequest: wakeRequest,
                    alarmSoundId: wakeRequest.alarmSoundId
                )
            }
        }
        // Wake confirmation
        .alert("They're Awake! 🌅", isPresented: $pushManager.showingWakeConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(pushManager.wakeConfirmedByName) confirmed they're awake")
        }
        // Invite deep-link result
        .alert(deepLinkManager.inviteResultTitle, isPresented: $deepLinkManager.showInviteResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deepLinkManager.inviteResultMessage)
        }
        // Unlock invite redemption sheet
        .sheet(isPresented: $deepLinkManager.showRedemptionSheet) {
            if let code = deepLinkManager.pendingUnlockCode {
                RedemptionView(inviteCode: code)
                    .onDisappear {
                        deepLinkManager.clearUnlockCode()
                    }
            }
        }
    }
}

// MARK: - Biometric Lock Screen

struct BiometricLockView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var authError: String?
    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignSystem.Colors.primaryOrange, DesignSystem.Colors.primaryOrangeLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: DesignSystem.Colors.primaryOrange.opacity(0.4), radius: 20, y: 8)

                    Image(systemName: BiometricManager.shared.biometricSystemImageName)
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                }

                VStack(spacing: 8) {
                    Text("Wake Up Sunshine")
                        .font(.title2).bold()
                        .foregroundColor(.textPrimary)
                    Text("Unlock with \(BiometricManager.shared.biometricTypeName)")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }

                if let error = authError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                Button {
                    Task { await authenticate() }
                } label: {
                    HStack {
                        if isAuthenticating {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: BiometricManager.shared.biometricSystemImageName)
                            Text("Unlock with \(BiometricManager.shared.biometricTypeName)")
                        }
                    }
                    .primaryButtonStyle()
                }
                .disabled(isAuthenticating)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
        }
        .task { await authenticate() }
    }

    private func authenticate() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        authError = nil
        let success = await BiometricManager.shared.authenticate()
        isAuthenticating = false
        if success {
            authManager.confirmBiometricAuth()
        } else {
            authError = "\(BiometricManager.shared.biometricTypeName) failed. Tap to try again."
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .environmentObject(AuthManager())
        .environmentObject(PushNotificationManager())
}