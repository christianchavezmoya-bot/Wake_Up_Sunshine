import SwiftUI

// MARK: - Alarm Sound Picker View
struct AlarmSoundPicker: View {
    let onSend: (AlarmSound) -> Void
    let contactName: String
    
    @State private var selectedSound: AlarmSound = .classic
    @State private var isSending = false
    @Environment(\.dismiss) private var dismiss
    
    private let debugLogger = DebugLogger.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Header
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Text("Wake Up Request")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                        
                        Text("Choose a wake sound for \(contactName)")
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DesignSystem.Spacing.lg)
                    
                    // Sound Options
                    VStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(AlarmSound.allCases) { sound in
                            SoundOptionCard(
                                sound: sound,
                                isSelected: selectedSound == sound,
                                onTap: {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                    selectedSound = sound
                                }
                            )
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    Spacer()
                    
                    // Send Button
                    Button(action: {
                        guard !isSending else { return }
                        isSending = true
                        
                        debugLogger.log(
                            eventType: "alarm_sound_selected",
                            message: "User selected alarm sound",
                            metadata: [
                                "soundId": selectedSound.id,
                                "soundName": selectedSound.displayName,
                                "targetContact": contactName
                            ]
                        )
                        
                        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                        impactFeedback.impactOccurred()
                        
                        onSend(selectedSound)
                        dismiss()
                    }) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            if isSending {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "bell.fill")
                            }
                            
                            Text(isSending ? "Sending..." : "Send Wake Request")
                                .fontWeight(.semibold)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(
                                colors: [DesignSystem.Colors.primaryOrange, DesignSystem.Colors.primaryOrangeLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(DesignSystem.Spacing.buttonRadius)
                        .shadow(color: DesignSystem.Colors.primaryOrange.opacity(0.4), radius: 8, y: 4)
                    }
                    .disabled(isSending)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.textSecondary)
                }
            }
        }
    }
}

// MARK: - Sound Option Card
struct SoundOptionCard: View {
    let sound: AlarmSound
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? sound.iconColor : sound.iconColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: sound.iconName)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : sound.iconColor)
                }
                
                // Name and Description
                VStack(alignment: .leading, spacing: 2) {
                    Text(sound.displayName)
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    
                    Text(sound.description)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.primaryOrange)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(Color.appCard)
            .cornerRadius(DesignSystem.Spacing.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardRadius)
                    .stroke(isSelected ? DesignSystem.Colors.primaryOrange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    AlarmSoundPicker(
        onSend: { sound in
            print("Selected sound: \(sound.displayName)")
        },
        contactName: "John"
    )
}