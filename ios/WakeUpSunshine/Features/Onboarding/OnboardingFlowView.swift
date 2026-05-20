import SwiftUI

struct OnboardingFlowView: View {
    @State private var currentStep: OnboardingStep = .welcome
    @EnvironmentObject var authManager: AuthManager

    enum OnboardingStep: Int, CaseIterable {
        case welcome
        case emailAuth
        case phoneInput
        case otpVerification
        case permissions // Consolidated: notifications + critical alerts
        case ready

        var progress: Double {
            switch self {
            case .welcome: return 0.15
            case .emailAuth: return 0.3
            case .phoneInput: return 0.5
            case .otpVerification: return 0.7
            case .permissions: return 0.85
            case .ready: return 1.0
            }
        }

        var title: String {
            switch self {
            case .welcome: return ""
            case .emailAuth: return "Back"
            case .phoneInput: return "Back"
            case .otpVerification: return "Back"
            case .permissions: return "Back"
            case .ready: return ""
            }
        }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar with back button
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Back button (when applicable)
                    if currentStep != .welcome && currentStep != .ready {
                        Button(action: goBack) {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                                .foregroundColor(DesignSystem.Colors.primaryOrange)
                                .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)
                        }
                    }

                    ProgressView(value: currentStep.progress)
                        .tint(DesignSystem.Colors.primaryOrange)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.md)

                Spacer()

                // Content with spring animation
                switch currentStep {
                case .welcome:
                    WelcomeStepView(
                        onEmailContinue: { currentStep = .emailAuth },
                        onPhoneContinue: { currentStep = .phoneInput }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .emailAuth:
                    EmailAuthView(
                        onSuccess: { currentStep = .permissions },
                        onBack: { currentStep = .welcome }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                case .phoneInput:
                    PhoneInputStepView(onContinue: { currentStep = .otpVerification })
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .otpVerification:
                    OtpVerificationStepView(onContinue: { currentStep = .permissions })
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .permissions:
                    PermissionsStepView(onContinue: { currentStep = .ready })
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .ready:
                    ReadyStepView()
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(.springStandard, value: currentStep)
    }

    private func goBack() {
        switch currentStep {
        case .emailAuth:
            currentStep = .welcome
        case .phoneInput:
            currentStep = .welcome
        case .otpVerification:
            currentStep = .phoneInput
        case .permissions:
            currentStep = .emailAuth
        default:
            break
        }
    }
}

// MARK: - Welcome Step
struct WelcomeStepView: View {
    let onEmailContinue: () -> Void
    let onPhoneContinue: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            // Animated logo
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DesignSystem.Colors.primaryOrange, DesignSystem.Colors.primaryOrangeLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 180, height: 180)
                    .shadow(color: DesignSystem.Colors.primaryOrange.opacity(0.4), radius: 30, y: 10)

                Image(systemName: "sun.max.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.white)
            }
            .modifier(PulseAnimation())

            VStack(spacing: DesignSystem.Spacing.md) {
                Text("Never Miss\nWhat Matters")
                    .font(.system(size: 34, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.textPrimary)

                Text("A trusted wake system that guarantees your loved ones can always reach you, even on silent.")
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            }

            Spacer()

            // Email button (Primary)
            Button(action: onEmailContinue) {
                HStack {
                    Image(systemName: "envelope.fill")
                    Text("Continue with Email")
                }
                .primaryButtonStyle()
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            // Phone button (Secondary)
            Button(action: onPhoneContinue) {
                HStack {
                    Image(systemName: "phone.fill")
                    Text("Continue with Phone")
                }
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.primaryOrange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(Color.appSurface)
                .cornerRadius(DesignSystem.Spacing.buttonRadius)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
    }
}

// MARK: - Phone Input Step
struct PhoneInputStepView: View {
    let onContinue: () -> Void
    @State private var phoneNumber = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Enter Your\nPhone Number")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.textPrimary)

                Text("We'll send you a verification code to set up your account.")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Phone input
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text("+1")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, DesignSystem.Spacing.sm + 4)
                    .padding(.vertical, DesignSystem.Spacing.sm + 2)
                    .background(Color.appSurface)
                    .cornerRadius(DesignSystem.Spacing.buttonRadius)

                TextField("(555) 123-4567", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .font(.title3)
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, DesignSystem.Spacing.sm + 4)
                    .padding(.vertical, DesignSystem.Spacing.sm + 2)
                    .background(Color.appSurface)
                    .cornerRadius(DesignSystem.Spacing.buttonRadius)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            Spacer()

            Button(action: {
                isLoading = true
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isLoading = false
                    onContinue()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Continue")
                    }
                }
                .primaryButtonStyle()
            }
            .disabled(phoneNumber.isEmpty)
            .opacity(phoneNumber.isEmpty ? 0.6 : 1)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
    }
}

// MARK: - OTP Verification Step
struct OtpVerificationStepView: View {
    let onContinue: () -> Void
    @State private var otpDigits: [String] = ["", "", "", "", "", ""]
    @FocusState private var focusedField: Int?

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Verify Your\nPhone Number")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.textPrimary)

                Text("Enter the 6-digit code we sent to\n+1 (555) 123-4567")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // OTP input - flexible sizing
            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(0..<6, id: \.self) { index in
                    OTPTextField(digit: $otpDigits[index])
                        .focused($focusedField, equals: index)
                        .onChange(of: otpDigits[index]) { _, newValue in
                            if newValue.count == 1 && index < 5 {
                                focusedField = index + 1
                            }
                        }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            Text("Resend code in 60s")
                .font(.subheadline)
                .foregroundColor(.textSecondary)

            Spacer()

            Button(action: onContinue) {
                Text("Verify")
                    .primaryButtonStyle()
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
        .onAppear { focusedField = 0 }
    }
}

struct OTPTextField: View {
    @Binding var digit: String

    var body: some View {
        TextField("", text: $digit)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(.textPrimary)
            .frame(width: 48, height: 56)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Spacing.buttonRadius)
                    .stroke(digit.isEmpty ? Color.appDivider : DesignSystem.Colors.primaryOrange, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Spacing.buttonRadius)
                    .fill(digit.isEmpty ? Color.appSurface : DesignSystem.Colors.primaryOrange.opacity(0.05))
            )
    }
}

// MARK: - Consolidated Permissions Step
struct PermissionsStepView: View {
    let onContinue: () -> Void
    @State private var notificationsEnabled = true
    @State private var criticalAlertsEnabled = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Enable\nPermissions")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.textPrimary)

                Text("Allow these permissions for guaranteed wake alerts.")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: DesignSystem.Spacing.sm) {
                // Notifications
                PermissionToggle(
                    icon: "bell.badge.fill",
                    iconColor: DesignSystem.Colors.primaryOrange,
                    title: "Notifications",
                    subtitle: "Receive wake alerts and updates",
                    isEnabled: $notificationsEnabled
                )

                // Critical Alerts
                PermissionToggle(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: DesignSystem.Colors.warning,
                    title: "Critical Alerts",
                    subtitle: "Wake up even on silent/DND",
                    isEnabled: $criticalAlertsEnabled
                )
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            // Info box
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.textSecondary)

                Text("Critical Alerts will always play at full volume, regardless of your phone's settings.")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .padding(DesignSystem.Spacing.md)
            .background(Color.appSurface)
            .cornerRadius(DesignSystem.Spacing.buttonRadius)
            .padding(.horizontal, DesignSystem.Spacing.lg)

            Spacer()

            Button(action: onContinue) {
                Text(criticalAlertsEnabled ? "Enable Critical Alerts" : "Continue")
                    .primaryButtonStyle()
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
    }
}

struct PermissionToggle: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.1))
                        .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)

                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .tint(DesignSystem.Colors.success)
        .padding(DesignSystem.Spacing.md)
        .background(Color.appCard)
        .cornerRadius(DesignSystem.Spacing.buttonRadius)
    }
}

// MARK: - Ready Step
struct ReadyStepView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            // Success animation
            ZStack {
                // Pulse circles
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(DesignSystem.Colors.success, lineWidth: 3)
                        .frame(width: CGFloat(200 + index * 60), height: CGFloat(200 + index * 60))
                        .opacity(index == 0 ? 1 : 0)
                        .modifier(PulseCircleAnimation(delay: Double(index) * 0.5))
                }

                Circle()
                    .fill(DesignSystem.Colors.success)
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("You're All Set!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.textPrimary)

                Text("Now add trusted contacts who can wake you up when it matters most.")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button(action: {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                appState.completeOnboarding()
            }) {
                Text("Start Using Wake Up Sunshine")
                    .primaryButtonStyle()
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
    }
}

// MARK: - Spring-based Animations
struct PulseAnimation: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.05 : 1.0)
            .animation(
                .spring(response: 2, dampingFraction: 0.6).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

struct PulseCircleAnimation: ViewModifier {
    let delay: Double
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.5 : 1.0)
            .opacity(isAnimating ? 0 : 1)
            .animation(
                .spring(response: 2, dampingFraction: 0.8).repeatForever(autoreverses: false).delay(delay),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

#Preview {
    OnboardingFlowView()
        .environmentObject(AppState())
        .environmentObject(AuthManager())
}
