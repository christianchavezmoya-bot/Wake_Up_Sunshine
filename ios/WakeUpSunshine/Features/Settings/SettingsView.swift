import SwiftUI
import AVFoundation
import AudioToolbox

// MARK: - Profile Data
private struct GetProfileResponse: Decodable {
    let success: Bool
    let profile: ProfileData?
    let error: String?
}

private struct UpdateProfileResponse: Decodable {
    let success: Bool
    let profile: ProfileData?
    let error: String?
}

struct GetDevicesResponse: Decodable {
    let success: Bool
    let devices: [DeviceData]?
    let error: String?
}

struct ProfileData: Decodable {
    let id: String
    let email: String
    let displayName: String
    let phoneNumber: String
    let avatarColor: String
}

struct DeviceData: Decodable, Identifiable {
    let id: String
    let platform: String
    let deviceType: String
    let deviceName: String
    let isPrimary: Bool
    let criticalAlertsEnabled: Bool
    let isActive: Bool
    let isCurrent: Bool
    let lastActiveAt: String?
    let updatedAt: String?
    let createdAt: String?
}

// MARK: - Profile ViewModel
class ProfileViewModel: ObservableObject {
    @Published var profile: ProfileData?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?
    @Published var editDisplayName: String = ""
    @Published var editPhoneNumber: String = ""

    @MainActor
    func load() async {
        guard profile == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let resp: GetProfileResponse = try await APIClient.shared.request(
                endpoint: "/get-profile",
                method: "GET"
            )
            if let p = resp.profile {
                profile = p
                editDisplayName = p.displayName
                editPhoneNumber = p.phoneNumber
            } else {
                error = resp.error
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let trimmedDisplayName = editDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
            var body: [String: Any] = ["displayName": trimmedDisplayName]
            if !editPhoneNumber.isEmpty { body["phoneNumber"] = editPhoneNumber }
            let resp: UpdateProfileResponse = try await APIClient.shared.request(
                endpoint: "/update-profile",
                method: "POST",
                body: body
            )
            if let p = resp.profile { profile = p } else { error = resp.error }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

class DevicesViewModel: ObservableObject {
    @Published var devices: [DeviceData] = []
    @Published var isLoading = false
    @Published var error: String?

    @MainActor
    func load(force: Bool = false) async {
        if isLoading { return }
        if !force && !devices.isEmpty { return }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            var headers: [String: String] = [:]
            if let deviceId = PushNotificationManager.shared.currentBackendDeviceId {
                headers["x-device-id"] = deviceId
            }

            let resp: GetDevicesResponse = try await APIClient.shared.request(
                endpoint: "/get-devices",
                method: "GET",
                headers: headers
            )
            if resp.success {
                devices = resp.devices ?? []
            } else {
                error = resp.error
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var contactsViewModel: ContactsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("selectedAlarmSoundId") private var selectedAlarmSoundId: String = "classic"
    @StateObject private var profileVM = ProfileViewModel()
    @StateObject private var devicesVM = DevicesViewModel()
    @StateObject private var themeManager = ThemeManager.shared

    @State private var showThemePicker = false
    @State private var playingSound: AlarmSound?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioError: String?
    @State private var biometricEnabled = BiometricManager.shared.isEnabled
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteErrorMessage: String?

    private var deleteErrorTitle: String {
        guard let deleteErrorMessage else { return "Delete Failed" }
        if deleteErrorMessage.localizedCaseInsensitiveContains("connected to the internet") {
            return "Connection Required"
        }
        return "Delete Failed"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {

                        // MARK: Profile
                        SettingsSection(title: "Profile") {
                            NavigationLink(destination: ProfileEditView(viewModel: profileVM)) {
                                ProfileRow(profile: profileVM.profile, isLoading: profileVM.isLoading)
                            }
                            .buttonStyle(.plain)
                        }
                        .task {
                            await profileVM.load()
                            await devicesVM.load()
                        }

                        // MARK: Devices
                        SettingsSection(title: "Devices") {
                            VStack(spacing: DesignSystem.Spacing.xs) {
                                if devicesVM.isLoading && devicesVM.devices.isEmpty {
                                    ProgressView()
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, DesignSystem.Spacing.md)
                                } else if devicesVM.devices.isEmpty {
                                    Text("No devices registered for this account")
                                        .font(.subheadline)
                                        .foregroundColor(.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(DesignSystem.Spacing.md)
                                        .background(Color.appCard)
                                        .cornerRadius(DesignSystem.Spacing.buttonRadius)
                                } else {
                                    ForEach(devicesVM.devices) { device in
                                        DeviceRow(device: device)
                                    }
                                }
                                if let error = devicesVM.error {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(DesignSystem.Colors.error)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }

                        // MARK: Alarm Sounds
                        SettingsSection(title: "Alarm Sound") {
                            VStack(spacing: DesignSystem.Spacing.xs) {
                                ForEach(AlarmSound.allCases) { sound in
                                    AlarmSoundRow(
                                        sound: sound,
                                        isSelected: selectedAlarmSoundId == sound.id,
                                        isPlaying: playingSound == sound,
                                        onSelect: {
                                            selectedAlarmSoundId = sound.id
                                        },
                                        onPlayToggle: {
                                            if playingSound == sound {
                                                stopAlarm()
                                            } else {
                                                testAlarm(sound: sound)
                                            }
                                        }
                                    )
                                }
                            }
                        }

                        // Audio error banner
                        if let error = audioError {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(DesignSystem.Colors.error)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.error)
                                Spacer()
                                Button("Dismiss") { audioError = nil }
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }
                            .padding(DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.error.opacity(0.08))
                            .cornerRadius(DesignSystem.Spacing.buttonRadius)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        }

                        // MARK: Appearance
                        SettingsSection(title: "Appearance") {
                            Button {
                                showThemePicker = true
                            } label: {
                                SettingsRow(
                                    icon: themeManager.currentTheme.iconName,
                                    iconColor: themeManager.primaryColor,
                                    title: "App Theme",
                                    subtitle: themeManager.currentTheme.displayName
                                ) {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.textTertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        // MARK: Privacy
                        SettingsSection(title: "Privacy") {
                            NavigationLink(destination: BlockedContactsView()) {
                                SettingsRow(
                                    icon: "hand.raised.fill",
                                    iconColor: .textSecondary,
                                    title: "Blocked Contacts",
                                    subtitle: contactsViewModel.blockedContacts.isEmpty ? "Manage blocked users" : "\(contactsViewModel.blockedContacts.count) blocked"
                                ) {
                                    Image(systemName: "chevron.right").foregroundColor(.textTertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // MARK: Developer
                        SettingsSection(title: "Developer") {
                            NavigationLink(destination: DiagnosticsView()) {
                                SettingsRow(
                                    icon: "ladybug.fill",
                                    iconColor: DesignSystem.Colors.primaryOrange,
                                    title: "Diagnostics",
                                    subtitle: "Debug logs and device info"
                                ) {
                                    Image(systemName: "chevron.right").foregroundColor(.textTertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        // MARK: Account
                        SettingsSection(title: "Account") {
                            Button(action: {
                                Task {
                                    await authManager.signOut()
                                }
                            }) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.body)
                                        .foregroundColor(DesignSystem.Colors.error)
                                    Text("Log Out")
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
                            .buttonStyle(.plain)
                        }

                        // MARK: Danger Zone
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Danger Zone")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.error)
                                .padding(.horizontal, DesignSystem.Spacing.lg)

                            Button(action: { showDeleteConfirmation = true }) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    if isDeletingAccount {
                                        ProgressView()
                                            .tint(DesignSystem.Colors.error)
                                    } else {
                                        Image(systemName: "trash.fill")
                                            .font(.body)
                                            .foregroundColor(DesignSystem.Colors.error)
                                    }
                                    Text(isDeletingAccount ? "Deleting..." : "Delete Account")
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
                            .disabled(isDeletingAccount)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        }
                    }
                    .padding(.top, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
            }
            .navigationTitle("Settings")
        }
        // Theme picker sheet
        .sheet(isPresented: $showThemePicker) {
            ThemePickerView(themeManager: themeManager)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        // Delete account confirmation
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if isOffline() {
                    deleteErrorMessage = "Make sure your phone is connected to the internet before deleting your account"
                    return
                }
                Task {
                    isDeletingAccount = true
                    do {
                        try await authManager.deleteAccount()
                    } catch {
                        isDeletingAccount = false
                        deleteErrorMessage = error.localizedDescription
                    }
                }
            }
        } message: {
            Text("This will permanently delete your account, all contacts, wake history, and device registrations. This action cannot be undone.")
        }
        .alert(deleteErrorTitle, isPresented: Binding(
            get: { deleteErrorMessage != nil },
            set: { if !$0 { deleteErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { deleteErrorMessage = nil }
        } message: {
            Text(deleteErrorMessage ?? "")
        }
        .onDisappear { stopAlarm() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await profileVM.load()
                await devicesVM.load(force: true)
                await contactsViewModel.fetchAllData()
            }
        }
    }

    // MARK: - Audio

    private func testAlarm(sound: AlarmSound) {
        stopAlarm()
        playingSound = sound
        audioError = nil
        print("[AlarmSettings] Testing sound='\(sound.id)'")

        if sound == .classic {
            AudioServicesPlaySystemSound(SystemSoundID(1005))
            autoStop(after: 4)
            return
        }

        guard let url = Bundle.main.url(forResource: sound.id, withExtension: "caf")
            ?? Bundle.main.url(forResource: sound.id, withExtension: "mp3") else {
            let msg = "'\(sound.id)' not found in bundle"
            print("[AlarmSettings] WARNING: \(msg)")
            audioError = msg
            AudioServicesPlaySystemSound(SystemSoundID(1005))
            autoStop(after: 4)
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = 2
            audioPlayer?.play()
            autoStop(after: 12)
        } catch {
            audioError = "Playback error: \(error.localizedDescription)"
            playingSound = nil
        }
    }

    private func stopAlarm() {
        audioPlayer?.stop()
        audioPlayer = nil
        playingSound = nil
    }

    private func autoStop(after seconds: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            if self.playingSound != nil { self.stopAlarm() }
        }
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
    let profile: ProfileData?
    let isLoading: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            let fallbackName = profile?.displayName.isEmpty == false ? profile?.displayName : profile?.email
            let initial = fallbackName?.prefix(1).uppercased() ?? "?"
            let color = Color(hex: profile?.avatarColor ?? "#FF6B35")
            Circle()
                .fill(color)
                .frame(width: DesignSystem.TouchTargets.minimum + 8, height: DesignSystem.TouchTargets.minimum + 8)
                .overlay(Text(initial).font(.title3).fontWeight(.bold).foregroundColor(.white))

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                if isLoading {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Text(profile?.displayName.isEmpty == false ? profile!.displayName : (profile?.email ?? "—"))
                        .font(.headline).foregroundColor(.textPrimary)
                    Text(profile?.phoneNumber.isEmpty == false ? profile!.phoneNumber : profile?.email ?? "—")
                        .font(.subheadline).foregroundColor(.textSecondary)
                }
            }

            Spacer()
            Image(systemName: "chevron.right").font(.body).foregroundColor(.textTertiary)
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.appCard)
        .cornerRadius(DesignSystem.Spacing.buttonRadius)
    }
}

// MARK: - Profile Edit View
struct ProfileEditView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            SwiftUI.Section {
                TextField("", text: .constant(viewModel.profile?.email ?? ""))
                    .disabled(true)
                    .foregroundColor(.secondary)
            } header: {
                Text("Email")
            } footer: {
                Text("Email is tied to this account. Sign out or delete the account to use a different email.")
            }
            SwiftUI.Section {
                TextField("How should we show you?", text: $viewModel.editDisplayName)
                    .autocorrectionDisabled()
            } header: {
                Text("Name or Nickname")
            }
            SwiftUI.Section {
                TextField("e.g. +1 555 000 1234", text: $viewModel.editPhoneNumber)
                    .keyboardType(.phonePad)
            } header: {
                Text("Phone Number")
            }
            if let error = viewModel.error {
                SwiftUI.Section {
                    Text(error).foregroundColor(.red).font(.caption)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Button("Save") {
                        Task {
                            await viewModel.save()
                            if viewModel.error == nil { dismiss() }
                        }
                    }
                    .disabled(viewModel.editDisplayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct BlockedContactsView: View {
    @EnvironmentObject var contactsViewModel: ContactsViewModel

    var body: some View {
        List {
            if contactsViewModel.blockedContacts.isEmpty {
                Text("No blocked contacts.")
                    .foregroundColor(.textSecondary)
            } else {
                ForEach(contactsViewModel.blockedContacts) { contact in
                    HStack(spacing: DesignSystem.Spacing.md) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                            Text(contact.displayName)
                                .font(.headline)
                                .foregroundColor(.textPrimary)
                            if !contact.email.isEmpty {
                                Text(contact.email)
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        Spacer()
                        Button("Unblock") {
                            Task { await contactsViewModel.unblockContact(contact) }
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Blocked Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await contactsViewModel.fetchAllData()
        }
        .task {
            if contactsViewModel.blockedContacts.isEmpty {
                await contactsViewModel.fetchAllData()
            }
        }
    }
}

// MARK: - Device Row
struct DeviceRow: View {
    let device: DeviceData

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Spacing.xs)
                    .fill(DesignSystem.Colors.primaryOrange.opacity(0.1))
                    .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)
                Image(systemName: iconName).font(.title3).foregroundColor(DesignSystem.Colors.primaryOrange)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(device.deviceName).font(.headline).foregroundColor(.textPrimary)
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    if device.isCurrent {
                        Circle().fill(DesignSystem.Colors.success).frame(width: 8, height: 8)
                        Text("This device").foregroundColor(DesignSystem.Colors.success)
                    } else {
                        Text(statusText).foregroundColor(.textSecondary)
                    }
                    if device.isPrimary {
                        Text("Primary")
                            .foregroundColor(.textSecondary)
                    }
                    if device.platform == "ios" && device.criticalAlertsEnabled {
                        Text("Critical alerts on")
                            .foregroundColor(.textSecondary)
                    }
                }
                .font(.caption)
            }

            Spacer()
            Image(systemName: "chevron.right").font(.body).foregroundColor(.textTertiary)
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.appCard)
        .cornerRadius(DesignSystem.Spacing.buttonRadius)
    }

    private var iconName: String {
        switch device.deviceType.lowercased() {
        case "ipad":
            return "ipad"
        case "watch":
            return "applewatch"
        case "android":
            return "iphone"
        default:
            return "iphone"
        }
    }

    private var statusText: String {
        if device.isActive, let lastActiveAt = device.lastActiveAt, isRecentlyActive(lastActiveAt) {
            return "Active recently"
        }
        if let lastActiveAt = device.lastActiveAt, let formatted = relativeTimeString(from: lastActiveAt) {
            return "Last active \(formatted)"
        }
        return "Registered device"
    }

    private func isRecentlyActive(_ iso8601: String) -> Bool {
        guard let date = iso8601DateFormatter.date(from: iso8601) else { return false }
        return Date().timeIntervalSince(date) < 15 * 60
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
                Image(systemName: icon).font(.title3).foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(title).font(.headline).foregroundColor(.textPrimary)
                Text(subtitle).font(.caption).foregroundColor(.textSecondary)
            }

            Spacer()
            accessory()
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.appCard)
        .cornerRadius(DesignSystem.Spacing.buttonRadius)
    }
}

// MARK: - Theme Picker View
struct ThemePickerView: View {
    @ObservedObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        themeManager.setTheme(theme)
                        dismiss()
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            ZStack {
                                RoundedRectangle(cornerRadius: DesignSystem.Spacing.xs)
                                    .fill(themeIconColor(for: theme).opacity(0.1))
                                    .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)
                                Image(systemName: theme.iconName)
                                    .font(.title3)
                                    .foregroundColor(themeIconColor(for: theme))
                            }
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                                Text(theme.displayName)
                                    .font(.headline)
                                    .foregroundColor(.textPrimary)
                                Text(theme.description)
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }
                            
                            Spacer()
                            
                            if themeManager.currentTheme == theme {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(DesignSystem.Colors.success)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Choose Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func themeIconColor(for theme: AppTheme) -> Color {
        switch theme {
        case .light:
            return DesignSystem.Colors.warning
        case .dark:
            return DesignSystem.Colors.textPrimaryDark
        case .fun:
            return Color(hex: "#FF6B9D")
        case .professional:
            return Color(hex: "#2563EB")
        }
    }
}

// MARK: - Alarm Sound Row
struct AlarmSoundRow: View {
    let sound: AlarmSound
    let isSelected: Bool
    let isPlaying: Bool
    let onSelect: () -> Void
    let onPlayToggle: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Spacing.xs)
                    .fill(isSelected ? sound.iconColor : sound.iconColor.opacity(0.15))
                    .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)
                Image(systemName: sound.iconName)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : sound.iconColor)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(sound.displayName)
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Text(sound.description)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Button(action: onPlayToggle) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(isPlaying ? DesignSystem.Colors.error : DesignSystem.Colors.success)
            }
            .buttonStyle(.plain)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(DesignSystem.Colors.primaryOrange)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.appCard)
        .cornerRadius(DesignSystem.Spacing.buttonRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.buttonRadius)
                .stroke(isSelected ? DesignSystem.Colors.primaryOrange : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}

private let iso8601DateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

private func relativeTimeString(from iso8601: String) -> String? {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full

    if let date = iso8601DateFormatter.date(from: iso8601) {
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    let fallback = ISO8601DateFormatter()
    guard let date = fallback.date(from: iso8601) else { return nil }
    return formatter.localizedString(for: date, relativeTo: Date())
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
