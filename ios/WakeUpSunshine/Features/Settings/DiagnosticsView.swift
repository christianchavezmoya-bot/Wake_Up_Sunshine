import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var pushManager: PushNotificationManager
    @StateObject private var debugLogger = DebugLogger.shared
    @StateObject private var viewModel = DiagnosticsViewModel()
    
    @State private var showCopyConfirmation = false
    @State private var showTestEventConfirmation = false
    
    var body: some View {
        List {
            // MARK: - User Info Section
            Section("User Info") {
                LabeledContent("User ID", value: viewModel.userId)
                LabeledContent("Email", value: viewModel.userEmail)
                LabeledContent("Session Exists", value: viewModel.sessionExists ? "Yes" : "No")
            }
            
            // MARK: - Push Notification Section
            Section("Push Notifications") {
                LabeledContent("APNs Token Registered", value: viewModel.apnsTokenRegistered ? "Yes" : "No")

                if let prefix = viewModel.apnsTokenPrefix, let suffix = viewModel.apnsTokenSuffix {
                    LabeledContent("Token", value: "\(prefix)...\(suffix)")
                }

                if let deviceId = viewModel.backendDeviceId {
                    LabeledContent("Backend Device ID", value: deviceId)
                }

                LabeledContent("Notification Permission", value: viewModel.notificationPermissionStatus)
                LabeledContent("Critical Alerts Entitlement", value: viewModel.criticalAlertEntitlementPresent ? "Present" : "Not Present")
                LabeledContent("Critical Alert Permission", value: viewModel.criticalAlertPermissionGranted ? "Granted" : "Not Granted")
                LabeledContent("Last APNs Payload Mode", value: viewModel.lastApnsPayloadMode)
            }

            Section("Registered Devices") {
                LabeledContent("Count", value: "\(viewModel.registeredDevices.count)")
                if viewModel.registeredDevices.isEmpty {
                    Text("No registered devices found for this account")
                        .foregroundColor(.textSecondary)
                } else {
                    ForEach(viewModel.registeredDevices) { device in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.deviceName)
                                .font(.subheadline)
                                .foregroundColor(.textPrimary)
                            Text(deviceDiagnosticsSummary(device))
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
                if let deviceError = viewModel.deviceError {
                    Text(deviceError)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // MARK: - Contacts Section
            Section("Contacts") {
                LabeledContent("People I Can Wake", value: "\(viewModel.peopleICanWakeCount)")
                LabeledContent("People Who Can Wake Me", value: "\(viewModel.peopleWhoCanWakeMeCount)")
                LabeledContent("Pending Invites Sent", value: "\(viewModel.pendingSentCount)")
                LabeledContent("Pending Invites Received", value: "\(viewModel.pendingReceivedCount)")
            }
            
            // MARK: - Last Wake Section
            Section("Last Wake Request") {
                if let traceId = debugLogger.lastWakeTraceId {
                    LabeledContent("Trace ID", value: traceId)
                } else {
                    Text("No wake request sent")
                        .foregroundColor(.textSecondary)
                }
                
                if let response = debugLogger.lastWakeResponse {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Response:")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                        Text(formatJSON(response))
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    }
                }
            }
            
            // MARK: - Last Notification Section
            Section("Last Notification") {
                if let payload = debugLogger.lastNotificationPayload {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Payload:")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                        Text(formatJSON(payload))
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    }
                } else {
                    Text("No notification received")
                        .foregroundColor(.textSecondary)
                }
                
                if let triggeredAt = debugLogger.lastAlarmTriggeredAt {
                    LabeledContent("Last Alarm Triggered", value: formatDate(triggeredAt))
                }
            }
            
            // MARK: - Actions Section
            Section("Actions") {
                Button(action: {
                    Task { await viewModel.refreshContacts() }
                }) {
                    Label("Refresh Contacts", systemImage: "arrow.clockwise")
                }

                Button(action: {
                    Task { await viewModel.refreshDevices() }
                }) {
                    Label("Refresh Registered Devices", systemImage: "ipad.and.iphone")
                }
                
                Button(action: {
                    Task { await viewModel.registerPushToken() }
                }) {
                    Label("Register Push Token Again", systemImage: "bell.badge")
                }
                
                Button(action: {
                    viewModel.sendTestDebugEvent()
                    showTestEventConfirmation = true
                }) {
                    Label("Send Test Debug Event", systemImage: "ladybug")
                }
                
                Button(action: {
                    viewModel.simulateIncomingWake()
                }) {
                    Label("Simulate Incoming Wake", systemImage: "sun.max.fill")
                }
                
                Button(action: {
                    debugLogger.clearEvents()
                }) {
                    Label("Clear Local Debug Logs", systemImage: "trash")
                }
                .foregroundColor(.red)
                
                Button(action: {
                    UIPasteboard.general.string = viewModel.exportDiagnostics()
                    showCopyConfirmation = true
                }) {
                    Label("Copy Diagnostics to Clipboard", systemImage: "doc.on.doc")
                }
            }
            
            // MARK: - Debug Log Section
            Section("Debug Log (last \(debugLogger.events.count))") {
                ForEach(debugLogger.events.prefix(20)) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(event.eventType)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.primaryOrange)
                            Spacer()
                            Text(formatTime(event.timestamp))
                                .font(.caption2)
                                .foregroundColor(.textSecondary)
                        }
                        Text(event.message)
                            .font(.caption)
                            .foregroundColor(.textPrimary)
                        if !event.metadata.isEmpty {
                            Text(event.metadata.map { "\($0.key): \($0.value)" }.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Copied!", isPresented: $showCopyConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Diagnostics copied to clipboard")
        }
        .alert("Test Event Sent", isPresented: $showTestEventConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Test debug event has been logged")
        }
        .task {
            await viewModel.loadDiagnostics()
        }
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatJSON(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
              let string = String(data: data, encoding: .utf8) else {
            return "\(dict)"
        }
        return string
    }
}

// MARK: - View Model
@MainActor
class DiagnosticsViewModel: ObservableObject {
    @Published var userId: String = "Not loaded"
    @Published var userEmail: String = "Not loaded"
    @Published var sessionExists: Bool = false
    @Published var apnsTokenRegistered: Bool = false
    @Published var apnsTokenPrefix: String?
    @Published var apnsTokenSuffix: String?
    @Published var notificationPermissionStatus: String = "Unknown"
    @Published var criticalAlertEntitlementPresent: Bool = false
    @Published var criticalAlertPermissionGranted: Bool = false
    @Published var lastApnsPayloadMode: String = "never received"
    @Published var backendDeviceId: String?
    @Published var registeredDevices: [DeviceData] = []
    @Published var deviceError: String?
    @Published var peopleICanWakeCount: Int = 0
    @Published var peopleWhoCanWakeMeCount: Int = 0
    @Published var pendingSentCount: Int = 0
    @Published var pendingReceivedCount: Int = 0
    
    private let debugLogger = DebugLogger.shared
    
    func loadDiagnostics() async {
        // Load auth info
        if let session = SupabaseManager.shared.client.auth.currentSession {
            userId = session.user.id.uuidString
            userEmail = session.user.email ?? "No email"
            sessionExists = true
        }
        
        // Load push notification info
        if let token = PushNotificationManager.shared.deviceToken {
            apnsTokenRegistered = true
            apnsTokenPrefix = String(token.prefix(8))
            apnsTokenSuffix = String(token.suffix(6))
        }
        backendDeviceId = PushNotificationManager.shared.currentBackendDeviceId
        
        // Check notification permission
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized:
            notificationPermissionStatus = "Authorized"
        case .denied:
            notificationPermissionStatus = "Denied"
        case .notDetermined:
            notificationPermissionStatus = "Not Determined"
        case .provisional:
            notificationPermissionStatus = "Provisional"
        case .ephemeral:
            notificationPermissionStatus = "Ephemeral"
        @unknown default:
            notificationPermissionStatus = "Unknown"
        }

        // Critical Alerts capability
        criticalAlertEntitlementPresent = settings.criticalAlertSetting != .notSupported
        criticalAlertPermissionGranted = settings.criticalAlertSetting == .enabled
        lastApnsPayloadMode = UserDefaults.standard.string(forKey: "last_apns_payload_mode") ?? "never received"

        // Load contacts count
        await refreshContacts()
        await refreshDevices()
    }
    
    func refreshContacts() async {
        debugLogger.logContactsRefreshStart()
        
        do {
            let result = try await InviteService.shared.fetchContacts()
            peopleICanWakeCount = result.peopleICanWake.count
            peopleWhoCanWakeMeCount = result.peopleWhoCanWakeMe.count
            pendingSentCount = result.pendingInvitesSent.count
            pendingReceivedCount = result.pendingInvitesReceived.count
            
            debugLogger.logContactsRefreshComplete(
                peopleICanWake: peopleICanWakeCount,
                peopleWhoCanWakeMe: peopleWhoCanWakeMeCount,
                pendingSent: pendingSentCount,
                pendingReceived: pendingReceivedCount
            )
        } catch {
            debugLogger.logError(error, context: "Failed to refresh contacts")
        }
    }
    
    func registerPushToken() async {
        guard let token = PushNotificationManager.shared.deviceToken else {
            debugLogger.log(eventType: "push_token_register_failed", message: "No device token available")
            return
        }
        
        debugLogger.logDeviceTokenRegisterStart(token: token)
        
        do {
            let response = try await registerDeviceToken(token)
            if let deviceId = response["deviceId"] as? String {
                apnsTokenRegistered = true
                PushNotificationManager.shared.storeBackendDeviceId(deviceId)
                backendDeviceId = deviceId
                debugLogger.logDeviceTokenRegisterSuccess(deviceId: deviceId)
            }
            await refreshDevices()
        } catch {
            debugLogger.logDeviceTokenRegisterFailure(error: error.localizedDescription)
        }
    }

    func refreshDevices() async {
        deviceError = nil
        do {
            var headers: [String: String] = [:]
            if let deviceId = PushNotificationManager.shared.currentBackendDeviceId {
                headers["x-device-id"] = deviceId
            }
            let response: GetDevicesResponse = try await APIClient.shared.request(
                endpoint: "/get-devices",
                method: "GET",
                headers: headers
            )
            if response.success {
                registeredDevices = response.devices ?? []
            } else {
                deviceError = response.error
            }
        } catch {
            deviceError = error.localizedDescription
        }
    }
    
    func sendTestDebugEvent() {
        debugLogger.log(
            eventType: "test_event",
            message: "Test debug event from iOS app",
            metadata: ["source": "diagnostics_button"]
        )
    }
    
    func simulateIncomingWake() {
        debugLogger.logNotificationReceived(payload: [
            "requestId": UUID().uuidString,
            "senderName": "Test User",
            "message": "This is a simulated wake alert",
            "alarmSoundId": "classic"
        ], inForeground: true)
    }
    
    func exportDiagnostics() -> String {
        var export = debugLogger.exportDiagnostics()
        
        export += "\n--- Device Info ---\n"
        export += "Platform: iOS\n"
        export += "User ID: \(userId)\n"
        export += "Email: \(userEmail)\n"
        export += "Session Exists: \(sessionExists)\n"
        export += "APNs Token Registered: \(apnsTokenRegistered)\n"
        if let prefix = apnsTokenPrefix, let suffix = apnsTokenSuffix {
            export += "APNs Token: \(prefix)...\(suffix)\n"
        }
        if let backendDeviceId {
            export += "Backend Device ID: \(backendDeviceId)\n"
        }
        export += "Registered Devices: \(registeredDevices.count)\n"
        for device in registeredDevices {
            export += "- \(device.deviceName) [\(device.platform)] current=\(device.isCurrent) active=\(device.isActive)\n"
        }
        export += "Notification Permission: \(notificationPermissionStatus)\n"
        export += "Critical Alerts Entitlement: \(criticalAlertEntitlementPresent ? "Present" : "Not Present")\n"
        export += "Critical Alert Permission: \(criticalAlertPermissionGranted ? "Granted" : "Not Granted")\n"
        export += "Last APNs Payload Mode: \(lastApnsPayloadMode)\n"
        export += "People I Can Wake: \(peopleICanWakeCount)\n"
        export += "People Who Can Wake Me: \(peopleWhoCanWakeMeCount)\n"
        export += "Pending Sent: \(pendingSentCount)\n"
        export += "Pending Received: \(pendingReceivedCount)\n"
        
        return export
    }
    
    private func registerDeviceToken(_ token: String) async throws -> [String: Any] {
        guard let session = SupabaseManager.shared.client.auth.currentSession else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var urlRequest = URLRequest(url: URL(string: "\(SupabaseManager.shared.supabaseURLString)/functions/v1/register-device")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(SupabaseManager.shared.supabaseAnonKey, forHTTPHeaderField: "apikey")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "token": token,
            "platform": "ios",
            "deviceType": UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone",
            "deviceName": UIDevice.current.name
        ])
        
        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "Parse", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        return json
    }
}

private func deviceDiagnosticsSummary(_ device: DeviceData) -> String {
    let current = device.isCurrent ? "This device" : device.platform.uppercased()
    let primary = device.isPrimary ? "Primary" : "Secondary"
    let active = device.isActive ? "Active" : "Inactive"
    return "\(current) • \(primary) • \(active)"
}

#Preview {
    NavigationStack {
        DiagnosticsView()
            .environmentObject(AuthManager())
            .environmentObject(PushNotificationManager())
    }
}
