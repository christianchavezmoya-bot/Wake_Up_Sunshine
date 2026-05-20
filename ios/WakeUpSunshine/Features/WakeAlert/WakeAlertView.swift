import SwiftUI
import AVFoundation
import AudioToolbox
import UserNotifications

struct WakeAlertView: View {
    let wakeRequest: WakeRequest
    let alarmSoundId: String?

    init(wakeRequest: WakeRequest, alarmSoundId: String? = nil) {
        self.wakeRequest = wakeRequest
        self.alarmSoundId = alarmSoundId
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isConfirming = false
    @State private var isSnoozing = false
    
    /// Reference to the ambient audio manager for alarm playback
    private let ambientAudioManager = AmbientAudioManager.shared
    
    /// Get the alarm sound to play
    private var alarmSound: AlarmSound {
        AlarmSound.from(id: alarmSoundId ?? wakeRequest.alarmSoundId)
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [DesignSystem.Colors.wakeGradientStart, DesignSystem.Colors.wakeGradientEnd],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Pulsing glow effect - Centered in safe area
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 300, height: 300)
                .modifier(GlowPulseAnimation())
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()

                // Alarm icon with shake
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 100, height: 100)
                        .modifier(ShakeAnimation())
                        .shadow(color: Color.black.opacity(0.2), radius: 20, y: 10)

                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 50))
                        .foregroundColor(DesignSystem.Colors.wakeGradientStart)
                }

                // Title
                Text("Wake Up!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                // Sender info
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("Wake request from")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))

                    Text(wakeRequest.senderName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                // Message
                if let message = wakeRequest.message {
                    Text(message)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(DesignSystem.Spacing.buttonRadius)
                }

                // Time using system formatting
                Text("Received at \(formattedTime)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                // Action buttons - Using safe area
                VStack(spacing: DesignSystem.Spacing.md) {
                    // I'm Awake button - Larger touch target
                    Button(action: confirmAwake) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            if isConfirming {
                                ProgressView()
                                    .tint(DesignSystem.Colors.success)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("I'm Awake")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.success)
                        .frame(maxWidth: .infinity)
                        .frame(height: DesignSystem.TouchTargets.standard)
                        .background(Color.white)
                        .cornerRadius(DesignSystem.Spacing.cardRadius)
                        .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
                    }
                    .disabled(isConfirming)
                    .buttonStyle(ScaleButtonStyle())

                    // Snooze button - Larger touch target
                    Button(action: snoozeAlarm) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            if isSnoozing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "moon.fill")
                                Text("Snooze (5 min)")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: DesignSystem.TouchTargets.standard)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(DesignSystem.Spacing.cardRadius)
                    }
                    .disabled(isSnoozing)
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg) // Use standard bottom padding
            }
        }
        .onAppear {
            playAlarmSound()
            triggerHaptic()
        }
        .onDisappear {
            stopAlarmSound()
        }
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: wakeRequest.sentAt)
    }

    private func confirmAwake() {
        isConfirming = true
        stopAlarmSound()
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        Task {
            await sendWakeResponse(action: "confirmed")
            isConfirming = false
            dismiss()
        }
    }

    private func snoozeAlarm() {
        isSnoozing = true
        stopAlarmSound()
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        Task {
            await sendWakeResponse(action: "snoozed")
            isSnoozing = false
            dismiss()
        }
    }

    private func sendWakeResponse(action: String) async {
        let endpoint = action == "confirmed" ? "/wake/\(wakeRequest.id)/confirm" : "/wake/\(wakeRequest.id)/\(action)"
        do {
            struct WakeResponseResult: Decodable { let success: Bool }
            let _: WakeResponseResult = try await APIClient.shared.request(
                endpoint: endpoint,
                method: "POST",
                body: ["wakeRequestId": wakeRequest.id, "action": action]
            )
            NotificationCenter.default.post(name: .wakeResponseReceived, object: nil)
        } catch {
            print("[WakeAlertView] wake-response failed: \(error)")
        }
    }

    private func playAlarmSound() {
        // Use AmbientAudioManager to play alarm at maximum volume
        // This works even when the phone is locked due to background audio
        ambientAudioManager.playAlarm(soundName: alarmSound.rawValue, fileExtension: "caf")
    }
    
    private func playSystemAlarmSound() {
        // Play system alarm sound as fallback - handled by AmbientAudioManager
        AudioServicesPlaySystemSound(SystemSoundID(1005)) // Mail incoming sound
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
    }

    private func stopAlarmSound() {
        // Stop the alarm and resume ambient audio
        ambientAudioManager.stopAlarm()
    }

    private func triggerHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}

// MARK: - Spring-based Animations
struct GlowPulseAnimation: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.3 : 1.0)
            .opacity(isAnimating ? 0 : 0.5)
            .animation(
                .spring(response: 1.5, dampingFraction: 0.6).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

struct ShakeAnimation: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isAnimating ? -5 : 5))
            .animation(
                .spring(response: 0.1, dampingFraction: 0.5).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

#Preview {
    WakeAlertView(
        wakeRequest: WakeRequest(senderId: "alex", receiverId: "me", senderName: "Alex", message: "Don't forget - morning shift starts in 30 minutes!"),
        alarmSoundId: "classic"
    )
    .environmentObject(AppState())
}
