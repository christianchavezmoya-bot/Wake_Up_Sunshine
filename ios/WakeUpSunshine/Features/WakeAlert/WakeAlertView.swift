import SwiftUI
import AVFoundation
import UserNotifications

struct WakeAlertView: View {
    let wakeRequest: WakeRequest

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var isConfirming = false
    @State private var isSnoozing = false
    @State private var audioPlayer: AVAudioPlayer?

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color("PrimaryOrange"), Color("PrimaryOrangeLight")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Pulsing glow effect
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 300, height: 300)
                .modifier(GlowPulseAnimation())
                .position(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY - 100)

            VStack(spacing: 32) {
                Spacer()

                // Alarm icon with shake
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 100, height: 100)
                        .modifier(ShakeAnimation())

                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 50))
                        .foregroundColor(Color("PrimaryOrange"))
                }

                // Title
                Text("Wake Up!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                // Sender info
                VStack(spacing: 8) {
                    Text("Wake request from")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))

                    Text("Alex Chen")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                // Message
                if let message = wakeRequest.message {
                    Text(message)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }

                // Time
                Text("Received at \(formatTime(wakeRequest.sentAt))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                // Action buttons
                VStack(spacing: 16) {
                    // I'm Awake button
                    Button(action: confirmAwake) {
                        HStack {
                            if isConfirming {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("I'm Awake")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(Color("Success"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .cornerRadius(16)
                    }
                    .disabled(isConfirming)

                    // Snooze button
                    Button(action: snoozeAlarm) {
                        HStack {
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
                        .padding(.vertical, 18)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(16)
                    }
                    .disabled(isSnoozing)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 60)
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

    private func confirmAwake() {
        isConfirming = true
        stopAlarmSound()

        // Send confirmation to backend
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isConfirming = false
            dismiss()
        }
    }

    private func snoozeAlarm() {
        isSnoozing = true
        stopAlarmSound()

        // Send snooze to backend
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSnoozing = false
            dismiss()
        }
    }

    private func playAlarmSound() {
        // In production, this would play a critical alert sound
        // For now, we'll just trigger haptic
    }

    private func stopAlarmSound() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    private func triggerHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Animations
struct GlowPulseAnimation: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.3 : 1.0)
            .opacity(isAnimating ? 0 : 0.5)
            .animation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true),
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
                .easeInOut(duration: 0.1)
                .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

#Preview {
    WakeAlertView(wakeRequest: WakeRequest(senderId: "alex", receiverId: "me", message: "Don't forget - morning shift starts in 30 minutes!"))
        .environmentObject(AppState())
}