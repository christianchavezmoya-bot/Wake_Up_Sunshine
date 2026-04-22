import SwiftUI

struct OnboardingFlowView: View {
    @State private var currentStep: OnboardingStep = .welcome
    @EnvironmentObject var authManager: AuthManager

    enum OnboardingStep: Int, CaseIterable {
        case welcome
        case phoneInput
        case otpVerification
        case notifications
        case criticalAlerts
        case ready

        var progress: Double {
            Double(rawValue + 1) / Double(OnboardingStep.allCases.count)
        }
    }

    var body: some View {
        ZStack {
            Color("Background").ignoresSafeArea()

            VStack {
                ProgressView(value: currentStep.progress)
                    .tint(Color("PrimaryOrange"))
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                Spacer()

                switch currentStep {
                case .welcome:
                    WelcomeStepView(onContinue: { currentStep = .phoneInput })
                case .phoneInput:
                    PhoneInputStepView(onContinue: { currentStep = .otpVerification })
                case .otpVerification:
                    OtpVerificationStepView(onContinue: { currentStep = .notifications })
                case .notifications:
                    NotificationsStepView(onContinue: { currentStep = .criticalAlerts })
                case .criticalAlerts:
                    CriticalAlertsStepView(onContinue: { currentStep = .ready })
                case .ready:
                    ReadyStepView()
                }
            }
        }
    }
}

// MARK: - Welcome Step
struct WelcomeStepView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color("PrimaryOrange"), Color("PrimaryOrangeLight")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 180, height: 180)
                    .shadow(color: Color("PrimaryOrange").opacity(0.4), radius: 30, y: 10)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.white)
            }
            .modifier(PulseAnimation())

            VStack(spacing: 16) {
                Text("Never Miss\nWhat Matters")
                    .font(.system(size: 34, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("A trusted wake system that guarantees your loved ones can always reach you, even on silent.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color("PrimaryOrange"))
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Phone Input Step
struct PhoneInputStepView: View {
    let onContinue: () -> Void
    @State private var phoneNumber = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Enter Your\nPhone Number")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("We'll send you a verification code to set up your account.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Text("+1")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color("Surface"))
                    .cornerRadius(12)

                TextField("(555) 123-4567", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .font(.title3)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color("Surface"))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: {
                isLoading = true
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
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(phoneNumber.isEmpty ? Color.gray : Color("PrimaryOrange"))
                .cornerRadius(16)
            }
            .disabled(phoneNumber.isEmpty)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - OTP Verification Step
struct OtpVerificationStepView: View {
    let onContinue: () -> Void
    @State private var otpDigits: [String] = ["", "", "", "", "", ""]
    @FocusState private var focusedField: Int?

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Verify Your\nPhone Number")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("Enter the 6-digit code we sent to\n+1 (555) 123-4567")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
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
            .padding(.horizontal, 24)
            .onAppear { focusedField = 0 }

            Text("Resend code in 60s")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: onContinue) {
                Text("Verify")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color("PrimaryOrange"))
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

struct OTPTextField: View {
    @Binding var digit: String

    var body: some View {
        TextField("", text: $digit)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.title)
            .fontWeight(.semibold)
            .frame(width: 48, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(digit.isEmpty ? Color.gray.opacity(0.3) : Color("PrimaryOrange"), lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(digit.isEmpty ? Color("Surface") : Color("PrimaryOrange").opacity(0.05))
            )
    }
}

// MARK: - Notifications Step
struct NotificationsStepView: View {
    let onContinue: () -> Void
    @State private var notificationsEnabled = true

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Enable\nNotifications")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("Wake Up Sunshine needs to send you notifications so you can receive wake alerts from your trusted contacts.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                Image(systemName: "bell.badge.fill")
                    .font(.title)
                    .foregroundColor(Color("Secondary"))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Notifications")
                        .font(.headline)
                    Text("Receive wake alerts and updates")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $notificationsEnabled)
                    .labelsHidden()
                    .tint(Color("PrimaryOrange"))
            }
            .padding(20)
            .background(Color("Surface"))
            .cornerRadius(16)
            .padding(.horizontal, 24)

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color("PrimaryOrange"))
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Critical Alerts Step
struct CriticalAlertsStepView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Critical Alerts")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("This is what makes Wake Up Sunshine special. Critical Alerts will always wake you up, even if your phone is on silent or Do Not Disturb is on.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color("Error"), Color("Error").opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }

                Text("Guaranteed Wake")
                    .font(.headline)

                Text("Louder than normal alerts. Cannot be silenced. Essential for emergencies.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(Color("Surface"))
            .cornerRadius(16)
            .padding(.horizontal, 24)

            Spacer()

            Button(action: onContinue) {
                Text("Enable Critical Alerts")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color("PrimaryOrange"))
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Ready Step
struct ReadyStepView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                // Pulse circles
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(Color("Success"), lineWidth: 3)
                        .frame(width: CGFloat(200 + index * 60), height: CGFloat(200 + index * 60))
                        .opacity(index == 0 ? 1 : 0)
                        .modifier(PulseCircleAnimation(delay: Double(index) * 0.5))
                }

                Circle()
                    .fill(Color("Success"))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.system(size: 28, weight: .bold))

                Text("Now add trusted contacts who can wake you up when it matters most.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button(action: {
                appState.completeOnboarding()
            }) {
                Text("Start Using Wake Up Sunshine")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color("PrimaryOrange"))
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Animations
struct PulseAnimation: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.05 : 1.0)
            .animation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true),
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
                .easeOut(duration: 2)
                .repeatForever(autoreverses: false)
                .delay(delay),
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