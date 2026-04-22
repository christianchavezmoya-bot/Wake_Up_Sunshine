import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var criticalAlertsEnabled = true
    @State private var testAlarmPlaying = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color("Background").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Profile")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 24)

                            Button(action: {}) {
                                HStack(spacing: 16) {
                                    Circle()
                                        .fill(Color("PrimaryOrange"))
                                        .frame(width: 52, height: 52)
                                        .overlay(
                                            Text("A")
                                                .font(.title3)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Alex Thompson")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("+1 (555) 123-4567")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding(16)
                                .background(Color("Surface"))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 24)
                        }

                        // Devices Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Devices")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 24)

                            VStack(spacing: 8) {
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
                            .padding(.horizontal, 24)
                        }

                        // Notifications Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notifications")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 24)

                            VStack(spacing: 8) {
                                SettingsRow(
                                    icon: "bell.badge.fill",
                                    iconColor: Color("PrimaryOrange"),
                                    title: "Critical Alerts",
                                    subtitle: "Always wake you up"
                                ) {
                                    Toggle("", isOn: $criticalAlertsEnabled)
                                        .labelsHidden()
                                        .tint(Color("Success"))
                                }

                                SettingsRow(
                                    icon: "speaker.wave.3.fill",
                                    iconColor: Color("Secondary"),
                                    title: "Alarm Sound",
                                    subtitle: "Siren (Loud)"
                                ) {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }

                                Button(action: testAlarm) {
                                    SettingsRow(
                                        icon: "play.circle.fill",
                                        iconColor: Color("Success"),
                                        title: "Test Alarm",
                                        subtitle: "Tap to preview sound"
                                    ) {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        // Privacy Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Privacy")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 24)

                            Button(action: {}) {
                                SettingsRow(
                                    icon: "hand.raised.fill",
                                    iconColor: Color("Secondary"),
                                    title: "Blocked Contacts",
                                    subtitle: "Manage blocked users"
                                ) {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        // Danger Zone
                        VStack(alignment: .leading, spacing: 12) {
                            Button(action: {}) {
                                HStack(spacing: 12) {
                                    Image(systemName: "trash.fill")
                                        .foregroundColor(Color("Error"))

                                    Text("Delete Account")
                                        .font(.subheadline)
                                        .foregroundColor(Color("Error"))
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color("Surface"))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 100)
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

// MARK: - Device Row
struct DeviceRow: View {
    let icon: String
    let name: String
    let status: String
    let isOnline: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color("Secondary").opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(Color("Secondary"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)

                HStack(spacing: 6) {
                    if isOnline {
                        Circle()
                            .fill(Color("Success"))
                            .frame(width: 8, height: 8)
                        Text("Active")
                            .foregroundColor(Color("Success"))
                    } else {
                        Text(status)
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color("Surface"))
        .cornerRadius(12)
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
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            accessory()
        }
        .padding(16)
        .background(Color("Surface"))
        .cornerRadius(12)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}