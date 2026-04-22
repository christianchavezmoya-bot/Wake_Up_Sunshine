import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var criticalAlertsEnabled = true
    @State private var testAlarmPlaying = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Profile Section
                        SettingsSection(title: "Profile") {
                            ProfileRow()
                        }

                        // Devices Section
                        SettingsSection(title: "Devices") {
                            VStack(spacing: DesignSystem.Spacing.xs) {
                                DeviceRow(
                                    icon: "iphone",
                                    name: "iPhone 15 Pro",
                                    status: "Active",
                                    isOnline: true
                                )

                                DeviceRow(
                                    icon: "ipad",
                                    name: "iPad Pro",
                                    status: "Last active 2 days ago",
                                    isOnline: false
                                )
                            }
                        }

                        // Notifications Section
                        SettingsSection(title: "Notifications") {
                            VStack(spacing: DesignSystem.Spacing.xs) {
                                SettingsRow(
                                    icon: "bell.badge.fill",
                                    iconColor: DesignSystem.Colors.primaryOrange,
                                    title: "Critical Alerts",
                                    subtitle: "Always wake you up"
                                ) {
                                    Toggle("", isOn: $criticalAlertsEnabled)
                                        .labelsHidden()
                                        .tint(DesignSystem.Colors.success)
                                }

                                SettingsRow(
                                    icon: "speaker.wave.3.fill",
                                    iconColor: .textSecondary,
                                    title: "Alarm Sound",
                                    subtitle: "Siren (Loud)"
                                ) {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.textTertiary)
                                }

                                SettingsRow(
                                    icon: "play.circle.fill",
                                    iconColor: DesignSystem.Colors.success,
                                    title: "Test Alarm",
                                    subtitle: "Tap to preview sound"
                                ) {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.textTertiary)
                                }
                                .onTapGesture {
                                    testAlarm()
                                }
                            }
                        }

                        // Privacy Section
                        SettingsSection(title: "Privacy") {
                            SettingsRow(
                                icon: "hand.raised.fill",
                                iconColor: .textSecondary,
                                title: "Blocked Contacts",
                                subtitle: "Manage blocked users"
                            ) {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.textTertiary)
                            }
                        }

                        // Danger Zone - With Red Border
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Danger Zone")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.error)
                                .padding(.horizontal, DesignSystem.Spacing.lg)

                            Button(action: {}) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    Image(systemName: "trash.fill")
                                        .font(.body)
                                        .foregroundColor(DesignSystem.Colors.error)

                                    Text("Delete Account")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(DesignSystem.Colors.error)

                                    Spacer()
                                }
                                .padding(DesignSystem.Spacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.appCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.Spacing.buttonRadius)
                                        .strokeBorder(DesignSystem.Colors.error.opacity(0.3), lineWidth: 1)
                                )
                                .cornerRadius(DesignSystem.Spacing.buttonRadius)
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        }
                    }
                    .padding(.top, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
            }
            .navigationTitle("Settings")
        }
        .alert("Test Alarm", isPresented: $testAlarmPlaying) {
            Button("Stop", role: .cancel) {}
        } message: {
            Text("Playing alarm sound...")
        }
    }

    private func testAlarm() {
        testAlarmPlaying = true
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.textSecondary)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            content()
                .padding(.horizontal, DesignSystem.Spacing.lg)
        }
    }
}

// MARK: - Profile Row
struct ProfileRow: View {
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Circle()
                .fill(DesignSystem.Colors.primaryOrange)
                .frame(width: DesignSystem.TouchTargets.minimum + 8, height: DesignSystem.TouchTargets.minimum + 8)
                .overlay(
                    Text("A")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text("Alex Thompson")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Text("+1 (555) 123-4567")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundColor(.textTertiary)
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.appCard)
        .cornerRadius(DesignSystem.Spacing.buttonRadius)
    }
}

// MARK: - Device Row
struct DeviceRow: View {
    let icon: String
    let name: String
    let status: String
    let isOnline: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Spacing.xs)
                    .fill(DesignSystem.Colors.primaryOrange.opacity(0.1))
                    .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(DesignSystem.Colors.primaryOrange)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(name)
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                HStack(spacing: DesignSystem.Spacing.xxs) {
                    if isOnline {
                        Circle()
                            .fill(DesignSystem.Colors.success)
                            .frame(width: 8, height: 8)
                        Text("Active")
                            .foregroundColor(DesignSystem.Colors.success)
                    } else {
                        Text(status)
                            .foregroundColor(.textSecondary)
                    }
                }
                .font(.caption)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundColor(.textTertiary)
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.appCard)
        .cornerRadius(DesignSystem.Spacing.buttonRadius)
    }
}

// MARK: - Settings Row
struct SettingsRow<Accessory: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Spacing.xs)
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

            Spacer()

            accessory()
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.appCard)
        .cornerRadius(DesignSystem.Spacing.buttonRadius)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
