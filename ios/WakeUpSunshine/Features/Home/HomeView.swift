import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var contactsViewModel: ContactsViewModel
    @State private var showAddContact = false
    @State private var showSimulateWake = false
    @State private var selectedContact: Contact?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if contactsViewModel.isLoading && contactsViewModel.peopleICanWake.isEmpty {
                    ProgressView("Loading contacts…")
                        .foregroundColor(.textSecondary)
                }

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                                Text("Wake Up Sunshine")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.textPrimary)

                                Text(greeting())
                                    .font(.subheadline)
                                    .foregroundColor(.textSecondary)
                            }

                            Spacer()

                            // Debug: Simulate Wake Button
                            Button(action: { showSimulateWake = true }) {
                                Circle()
                                    .fill(DesignSystem.Colors.primaryOrange)
                                    .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)
                                    .overlay(
                                        Image(systemName: "bell.fill")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.top, DesignSystem.Spacing.md)

                        // Section: People I Can Wake
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text("People I Can Wake")
                                .font(.headline)
                                .foregroundColor(.textPrimary)
                                .padding(.horizontal, DesignSystem.Spacing.lg)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.md) {
                                ForEach(contactsViewModel.peopleICanWake) { contact in
                                    ContactCard(contact: contact) {
                                        selectedContact = contact
                                    }
                                    .transition(.scale.combined(with: .opacity).animation(.springStandard))
                                }

                                // Add Contact Card
                                Button(action: { showAddContact = true }) {
                                    AddContactCard()
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        }

                        // Empty State
                        if contactsViewModel.peopleICanWake.isEmpty {
                            EmptyContactsView()
                                .transition(.opacity.animation(.springGentle))
                            }
                    }
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddContact) {
                AddContactSheet()
            }
            .alert("Error", isPresented: .init(
                get: { contactsViewModel.error != nil },
                set: { if !$0 { contactsViewModel.error = nil } }
            )) {
                Button("Retry") { Task { await contactsViewModel.fetchAllData() } }
                Button("OK", role: .cancel) { contactsViewModel.error = nil }
            } message: {
                Text(contactsViewModel.error ?? "")
            }
            .alert("Wake Alert Sent", isPresented: $viewModel.showWakeConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("\(viewModel.lastWakedContact?.displayName ?? "Contact") received your wake alert!")
            }
            .alert(viewModel.responseResultTitle, isPresented: $viewModel.showResponseResult) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.responseResultMessage)
            }
            .alert("Delivery Failed", isPresented: $viewModel.showDeliveryError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.deliveryErrorMessage)
            }
            .sheet(isPresented: $viewModel.isWaitingForResponse, onDismiss: {
                viewModel.dismissWaitingOverlay()
            }) {
                WaitingForResponseSheet(viewModel: viewModel)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showSimulateWake) {
                WakeAlertView(
                    wakeRequest: WakeRequest(
                        senderId: "test-user",
                        receiverId: "me",
                        senderName: "Test User",
                        message: "This is a simulated wake alert for testing",
                        urgency: .normal
                    )
                )
            }
            .sheet(item: $selectedContact) { contact in
                AlarmSoundPicker(
                    onSend: { sound in
                        viewModel.sendWakeRequest(to: contact, alarmSound: sound)
                    },
                    contactName: contact.displayName
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await contactsViewModel.fetchAllData() }
                }
            }
        }
    }

    private func greeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = appState.currentUser?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let firstName = name.components(separatedBy: " ").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let greetingName = firstName.isEmpty ? "" : " \(firstName)"
        if hour < 12 {
            return "Good morning\(greetingName)"
        } else if hour < 17 {
            return "Good afternoon\(greetingName)"
        } else {
            return "Good evening\(greetingName)"
        }
    }
}

// MARK: - Contact Card
struct ContactCard: View {
    let contact: Contact
    let onWakeTap: () -> Void
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            // Bell wake button at top
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onWakeTap()
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignSystem.Colors.primaryOrange, DesignSystem.Colors.primaryOrangeLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)
                        .shadow(color: DesignSystem.Colors.primaryOrange.opacity(0.35), radius: 6, y: 3)

                    Image(systemName: "bell.fill")
                        .font(.headline)
                        .foregroundColor(.white)

                    Circle()
                        .stroke(DesignSystem.Colors.primaryOrange, lineWidth: 2)
                        .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)
                        .modifier(PulseRingAnimation())
                }
            }
            .buttonStyle(ScaleButtonStyle())

            Text(contact.displayName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 4) {
                Circle()
                    .fill(DesignSystem.Colors.success)
                    .frame(width: 6, height: 6)
                Text(contact.isOnline ? "Online" : "Ready")
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.success)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(Color.appCard)
        .cornerRadius(DesignSystem.Spacing.cardRadius)
        .shadow(
            color: isPressed ? DesignSystem.Shadows.cardShadow.color.opacity(0.3) : DesignSystem.Shadows.cardShadow.color,
            radius: isPressed ? 2 : DesignSystem.Shadows.cardShadow.radius,
            x: DesignSystem.Shadows.cardShadow.x,
            y: isPressed ? 1 : DesignSystem.Shadows.cardShadow.y
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.springBounce, value: configuration.isPressed)
    }
}

// MARK: - Add Contact Card
struct AddContactCard: View {
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignSystem.Colors.primaryOrange, DesignSystem.Colors.primaryOrangeLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Add Contact")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)

            Text("Invite friends")
                .font(.caption2)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.sm)
        .background(Color.appCard)
        .cornerRadius(DesignSystem.Spacing.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardRadius)
                .strokeBorder(Color.appDivider, style: StrokeStyle(lineWidth: 1, dash: [6]))
        )
        .shadow(
            color: isPressed ? DesignSystem.Shadows.cardShadow.color.opacity(0.3) : DesignSystem.Shadows.cardShadow.color,
            radius: isPressed ? 2 : DesignSystem.Shadows.cardShadow.radius,
            x: DesignSystem.Shadows.cardShadow.x,
            y: isPressed ? 1 : DesignSystem.Shadows.cardShadow.y
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Pulse Ring Animation with Spring
struct PulseRingAnimation: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.4 : 1.0)
            .opacity(isAnimating ? 0 : 0.8)
            .animation(
                .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

// MARK: - Empty Contacts View with Illustration
struct EmptyContactsView: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Custom Sun/Moon illustration
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DesignSystem.Colors.primaryOrange.opacity(0.2), DesignSystem.Colors.primaryOrangeLight.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "sun.max.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignSystem.Colors.primaryOrange, DesignSystem.Colors.primaryOrangeLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.bottom, DesignSystem.Spacing.xs)

            Text("No Trusted Contacts Yet")
                .font(.headline)
                .foregroundColor(.textPrimary)

            Text("Add people who can wake you up when it matters most.")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)
        }
        .padding(.vertical, DesignSystem.Spacing.xxl)
    }
}

// Note: AddContactSheet is now defined in Features/Contacts/InviteContactView.swift

// MARK: - Notification Names
extension Notification.Name {
    static let wakeResponseReceived = Notification.Name("wakeResponseReceived")
    static let wakeSent = Notification.Name("wakeSent")
    static let contactsShouldRefresh = Notification.Name("contactsShouldRefresh")
}

// MARK: - Home ViewModel
class HomeViewModel: ObservableObject {
    @Published var showWakeConfirmation = false
    @Published var lastWakedContact: Contact?

    // Waiting state
    @Published var isWaitingForResponse = false
    @Published var activeWakeRequestId: String?
    @Published var wakeResponseStatus: String = "pending"
    @Published var wakeResponseAction: String?
    @Published var waitingElapsedSeconds: Int = 0
    @Published var waitingContactName: String = ""

    // Persistent response result
    @Published var showResponseResult = false
    @Published var responseResultTitle: String = ""
    @Published var responseResultMessage: String = ""

    // Delivery failure
    @Published var showDeliveryError = false
    @Published var deliveryErrorMessage: String = ""

    private let debugLogger = DebugLogger.shared
    private var pollingTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?

    init() {
        // React to wake-response push immediately (instead of waiting for next poll tick)
        NotificationCenter.default.addObserver(forName: .wakeResponseReceived, object: nil, queue: .main) { [weak self] notification in
            guard let self = self, self.isWaitingForResponse else { return }
            if let action = notification.userInfo?["responseAction"] as? String {
                self.wakeResponseAction = action
            }
            self.stopWaiting(showResult: true)
        }
    }

    func sendWakeRequest(to contact: Contact, alarmSound: AlarmSound = .classic) {
        lastWakedContact = contact
        debugLogger.logWakeButtonTapped(targetUserId: contact.userId, targetName: contact.displayName)
        Task { await sendWakeToBackend(contact: contact, alarmSound: alarmSound) }
    }

    private func sendWakeToBackend(contact: Contact, alarmSound: AlarmSound) async {
        let traceId = debugLogger.generateTraceId()
        debugLogger.logWakeRequestSent(traceId: traceId, targetUserId: contact.userId, alarmSoundId: alarmSound.id)

        do {
            let wakeResponse = try await WakeAlertManager.shared.sendWake(
                to: contact.userId,
                message: nil,
                urgency: .normal,
                alarmSoundId: alarmSound.id
            )
            debugLogger.logWakeResponse(["success": wakeResponse.success, "requestId": wakeResponse.requestId])

            if !wakeResponse.success || wakeResponse.devicesNotified == 0 {
                // Delivery failed — likely stale token
                let errMsg = "Could not deliver wake request — \(contact.displayName)'s device token is invalid. Ask them to reopen the app."
                await MainActor.run {
                    deliveryErrorMessage = errMsg
                    showDeliveryError = true
                }
                debugLogger.logError(NSError(domain: "DeliveryFailed", code: 0), context: errMsg)
                return
            }

            await MainActor.run {
                activeWakeRequestId = wakeResponse.requestId
                waitingContactName = contact.displayName
                wakeResponseStatus = "sent"
                wakeResponseAction = nil
                waitingElapsedSeconds = 0
                isWaitingForResponse = true
            }
            NotificationCenter.default.post(name: .wakeSent, object: nil)
            startPolling(requestId: wakeResponse.requestId)
            startTimer()
        } catch {
            debugLogger.logError(error, context: "Failed to send wake request")
        }
    }

    private func startPolling(requestId: String) {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { break }
                do {
                    let resp = try await WakeAlertManager.shared.getWakeStatus(requestId: requestId)
                    if let detail = resp.wakeRequest {
                        await MainActor.run { self.wakeResponseStatus = detail.status }
                        let terminal = ["confirmed", "snoozed", "dismissed", "timed_out"]
                        if terminal.contains(detail.status) {
                            await MainActor.run {
                                self.wakeResponseAction = detail.responseAction
                                self.wakeResponseStatus = detail.status
                            }
                            debugLogger.log(
                                eventType: "wake_response_received",
                                message: "Terminal status from polling",
                                metadata: [
                                    "status": detail.status,
                                    "responseAction": detail.responseAction ?? "none",
                                    "responseReceivedVia": "polling"
                                ]
                            )
                            stopWaiting(showResult: true)
                            break
                        }
                    }
                } catch {
                    print("[HomeViewModel] polling error: \(error)")
                }
            }
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }
                await MainActor.run { self.waitingElapsedSeconds += 1 }
                // Auto-timeout display after 5 minutes
                if waitingElapsedSeconds >= 300 {
                    stopWaiting()
                    break
                }
            }
        }
    }

    func stopWaiting(showResult: Bool = false) {
        pollingTask?.cancel()
        timerTask?.cancel()
        let capturedAction = wakeResponseAction ?? wakeResponseStatus
        let capturedName = waitingContactName
        Task { @MainActor in
            // Brief delay so the result state is visible in the sheet
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            isWaitingForResponse = false
            activeWakeRequestId = nil
            if showResult {
                let (title, msg) = responseResultContent(action: capturedAction, name: capturedName)
                responseResultTitle = title
                responseResultMessage = msg
                showResponseResult = true
                debugLogger.log(
                    eventType: "response_ui_presented",
                    message: "Showing persistent response result",
                    metadata: ["action": capturedAction, "contact": capturedName]
                )
                NotificationCenter.default.post(name: .wakeResponseReceived, object: nil)
            }
        }
    }

    private func responseResultContent(action: String, name: String) -> (title: String, message: String) {
        switch action {
        case "confirmed":
            return ("\(name) is Awake!", "Your wake alarm worked. \(name) confirmed they're up.")
        case "snoozed":
            return ("\(name) Snoozed", "\(name) snoozed the alarm. It will ring again shortly.")
        case "dismissed":
            return ("\(name) Dismissed", "\(name) dismissed the wake alarm.")
        case "timed_out":
            return ("No Response", "\(name) did not respond to the wake alarm.")
        default:
            return ("Wake Complete", "The wake alarm has ended.")
        }
    }

    func dismissWaitingOverlay() {
        pollingTask?.cancel()
        timerTask?.cancel()
        isWaitingForResponse = false
        activeWakeRequestId = nil
    }
}

// MARK: - Waiting For Response Sheet
struct WaitingForResponseSheet: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)

            statusIcon
                .frame(width: 80, height: 80)

            Text(statusTitle)
                .font(.title2).fontWeight(.bold)
                .foregroundColor(.textPrimary)

            Text(statusSubtitle)
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if viewModel.wakeResponseStatus == "sent" || viewModel.wakeResponseStatus == "delivered" || viewModel.wakeResponseStatus == "pending" {
                Text(elapsedText)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .monospacedDigit()
            }

            Button("Dismiss") { viewModel.dismissWaitingOverlay() }
                .buttonStyle(.bordered)
                .padding(.top, 8)

            Spacer(minLength: 16)
        }
        .padding()
    }

    private var statusIcon: some View {
        Group {
            switch viewModel.wakeResponseAction ?? viewModel.wakeResponseStatus {
            case "confirmed":
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64)).foregroundColor(DesignSystem.Colors.success)
            case "snoozed":
                Image(systemName: "zzz")
                    .font(.system(size: 56)).foregroundColor(DesignSystem.Colors.warning)
            case "dismissed":
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 64)).foregroundColor(.textSecondary)
            default:
                ZStack {
                    Circle().fill(DesignSystem.Colors.primaryOrange.opacity(0.15))
                    ProgressView().tint(DesignSystem.Colors.primaryOrange)
                }
            }
        }
    }

    private var statusTitle: String {
        switch viewModel.wakeResponseAction ?? viewModel.wakeResponseStatus {
        case "confirmed": return "\(viewModel.waitingContactName) is Awake!"
        case "snoozed": return "\(viewModel.waitingContactName) Snoozed"
        case "dismissed": return "\(viewModel.waitingContactName) Dismissed"
        default: return "Waiting for \(viewModel.waitingContactName)…"
        }
    }

    private var statusSubtitle: String {
        switch viewModel.wakeResponseAction ?? viewModel.wakeResponseStatus {
        case "confirmed": return "Your wake alarm was successful."
        case "snoozed": return "They snoozed the alarm. It will ring again shortly."
        case "dismissed": return "They dismissed the alarm."
        default: return "Your wake alarm was sent. Waiting for them to respond."
        }
    }

    private var elapsedText: String {
        let s = viewModel.waitingElapsedSeconds
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
        .environmentObject(ContactsViewModel())
}
