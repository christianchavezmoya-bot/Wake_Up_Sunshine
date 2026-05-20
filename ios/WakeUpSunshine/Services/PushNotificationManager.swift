import Foundation
import UserNotifications
import SwiftUI

class PushNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationManager()
    
    @Published var deviceToken: String?
    @Published var isRegistered: Bool = false
    @Published var notificationPermissionGranted: Bool = false
    @Published var criticalAlertPermissionGranted: Bool = false
    @Published var criticalAlertEntitlementPresent: Bool = false
    @Published var showingWakeAlert: Bool = false
    @Published var activeWakeRequest: WakeRequest?
    @Published var showingWakeConfirmation: Bool = false
    @Published var wakeConfirmedByName: String = ""
    @Published var wakeResponseAction: String = "confirmed"
    
    private let debugLogger = DebugLogger.shared
    private let cachedTokenKey = "cached_apns_device_token"
    private let backendDeviceIdKey = "backend_device_id"
    
    override init() {
        super.init()
        // Load cached token on init
        if let cachedToken = UserDefaults.standard.string(forKey: cachedTokenKey) {
            self.deviceToken = cachedToken
            debugLogger.log(eventType: "cached_token_loaded", message: "Loaded cached token from storage")
        }
    }

    var currentBackendDeviceId: String? {
        UserDefaults.standard.string(forKey: backendDeviceIdKey)
    }

    func storeBackendDeviceId(_ deviceId: String) {
        UserDefaults.standard.set(deviceId, forKey: backendDeviceIdKey)
    }
    
    // MARK: - Register for Notifications
    func registerForPushNotifications() async {
        debugLogger.log(eventType: "push_registration_start", message: "Requesting notification permission")

        // Include .criticalAlert — system ignores it gracefully if entitlement is absent
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .criticalAlert]

        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)

            await MainActor.run {
                self.notificationPermissionGranted = granted
            }

            // Derive critical alert capability from actual settings (entitlement check)
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            let criticalSetting = settings.criticalAlertSetting
            let entitlementPresent = criticalSetting != .notSupported
            let criticalGranted = criticalSetting == .enabled

            await MainActor.run {
                self.criticalAlertEntitlementPresent = entitlementPresent
                self.criticalAlertPermissionGranted = criticalGranted
            }

            if !entitlementPresent {
                debugLogger.log(
                    eventType: "critical_alert_not_available",
                    message: "Critical Alerts entitlement absent — standard push only",
                    metadata: ["criticalAlertSetting": "\(criticalSetting.rawValue)"]
                )
            }

            debugLogger.log(eventType: "push_permission_result", message: "Permission result", metadata: [
                "granted": "\(granted)",
                "criticalAlertEnabled": "\(criticalGranted)",
                "criticalAlertEntitlementPresent": "\(entitlementPresent)"
            ])

            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            debugLogger.logError(error, context: "Failed to request notification permission")
            debugLogger.log(
                eventType: "critical_alert_not_available",
                message: "Critical alert request threw — falling back to standard options",
                metadata: ["error": error.localizedDescription]
            )
            // Fallback without critical alerts
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                await MainActor.run {
                    self.notificationPermissionGranted = granted
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } catch {
                debugLogger.logError(error, context: "Fallback notification permission request failed")
            }
        }
    }
    
    // MARK: - Handle Device Token
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        
        debugLogger.logAPNsRegistrationSuccess(
            tokenPrefix: String(token.prefix(8)),
            tokenSuffix: String(token.suffix(6))
        )
        
        print("[PushNotificationManager] APNs token received: \(token.prefix(8))...\(token.suffix(6))")
        
        // Cache the token locally for later use (in case user not logged in yet)
        UserDefaults.standard.set(token, forKey: cachedTokenKey)
        
        Task { @MainActor in
            self.deviceToken = token
            self.isRegistered = true
            
            // Register with backend
            await self.registerDeviceTokenWithBackend(token: token)
        }
    }
    
    func didFailToRegisterForRemoteNotifications(withError error: Error) {
        debugLogger.logAPNsRegistrationFailure(error: error.localizedDescription)
        print("[PushNotificationManager] Failed to register for remote notifications: \(error)")
    }
    
    // MARK: - Register Token with Backend
    private func registerDeviceTokenWithBackend(token: String) async {
        debugLogger.logDeviceTokenRegisterStart(token: token)
        
        guard let session = SupabaseManager.shared.client.auth.currentSession else {
            debugLogger.logDeviceTokenRegisterFailure(error: "Not authenticated")
            return
        }
        
        do {
            let deviceMetadata = await MainActor.run {
                (
                    UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone",
                    UIDevice.current.name
                )
            }
            var urlRequest = URLRequest(url: URL(string: "\(SupabaseManager.shared.supabaseURLString)/functions/v1/register-device")!)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            urlRequest.setValue(SupabaseManager.shared.supabaseAnonKey, forHTTPHeaderField: "apikey")
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: [
                "token": token,
                "platform": "ios",
                "deviceType": deviceMetadata.0,
                "deviceName": deviceMetadata.1
            ])
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "InvalidResponse", code: -1)
            }
            
            if httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let deviceId = json["deviceId"] as? String {
                    storeBackendDeviceId(deviceId)
                    debugLogger.logDeviceTokenRegisterSuccess(deviceId: deviceId)
                    print("[PushNotificationManager] Device token registered with backend: \(deviceId)")
                }
            } else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                debugLogger.logDeviceTokenRegisterFailure(error: "HTTP \(httpResponse.statusCode): \(errorBody)")
                print("[PushNotificationManager] Failed to register device: \(errorBody)")
            }
        } catch {
            debugLogger.logDeviceTokenRegisterFailure(error: error.localizedDescription)
            print("[PushNotificationManager] Failed to register device token with backend: \(error)")
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        
        let payload = userInfo.reduce(into: [String: Any]()) { result, pair in
            if let key = pair.key as? String {
                result[key] = pair.value
            }
        }
        debugLogger.logNotificationReceived(payload: payload, inForeground: true)
        print("[PushNotificationManager] Notification received in foreground: \(userInfo)")
        
        if isWakeAlarm(userInfo) {
            handleWakeAlarm(userInfo)
        } else if isWakeConfirmation(userInfo) {
            handleWakeConfirmation(userInfo)
        }

        // Show notification even when in foreground
        completionHandler([.banner, .sound, .badge, .list])
    }
    
    // Handle notification when user taps on it
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        let payload = userInfo.reduce(into: [String: Any]()) { result, pair in
            if let key = pair.key as? String {
                result[key] = pair.value
            }
        }
        debugLogger.logNotificationReceived(payload: payload, inForeground: false)
        print("[PushNotificationManager] Notification tapped: \(userInfo)")
        
        if isWakeAlarm(userInfo) {
            handleWakeAlarm(userInfo)
        } else if isWakeConfirmation(userInfo) {
            handleWakeConfirmation(userInfo)
        }

        completionHandler()
    }
    
    // MARK: - Wake Alarm Handling
    
    private func isWakeAlarm(_ userInfo: [AnyHashable: Any]) -> Bool {
        let type = userInfo["type"] as? String ?? ""
        return type == "wake_request" || type == "wake_alarm"
    }

    private func isWakeConfirmation(_ userInfo: [AnyHashable: Any]) -> Bool {
        let type = userInfo["type"] as? String ?? ""
        return type == "wake_response" || type == "wake_confirmed"
    }

    private func handleWakeConfirmation(_ userInfo: [AnyHashable: Any]) {
        let receiverName = userInfo["receiverName"] as? String ?? "They"
        let responseAction = userInfo["responseAction"] as? String ?? "confirmed"
        debugLogger.log(eventType: "wake_response_received", message: "Wake response received", metadata: [
            "receiverName": receiverName, "responseAction": responseAction
        ])
        Task { @MainActor in
            self.wakeConfirmedByName = receiverName
            self.wakeResponseAction = responseAction
            self.showingWakeConfirmation = true
        }
        // Notify HomeViewModel immediately so it stops polling and shows the result
        NotificationCenter.default.post(
            name: .wakeResponseReceived,
            object: nil,
            userInfo: ["receiverName": receiverName, "responseAction": responseAction]
        )
    }
    
    private func handleWakeAlarm(_ userInfo: [AnyHashable: Any]) {
        // Accept both wakeRequestId (new) and requestId (legacy)
        let requestId = (userInfo["wakeRequestId"] as? String)
            ?? (userInfo["requestId"] as? String)
            ?? UUID().uuidString
        let senderId = userInfo["senderId"] as? String ?? "unknown"
        let senderName = userInfo["senderName"] as? String ?? "Someone"
        let message = userInfo["message"] as? String
        let urgency = userInfo["urgency"] as? String ?? "normal"
        let alarmSoundId = userInfo["alarmSoundId"] as? String ?? "classic"

        // Store payload mode reported by backend for diagnostics
        if let mode = userInfo["apnsPayloadMode"] as? String {
            UserDefaults.standard.set(mode, forKey: "last_apns_payload_mode")
        }
        
        debugLogger.logWakeAlertPresented(requestId: requestId, senderName: senderName)
        
        let wakeRequest = WakeRequest(
            id: requestId,
            senderId: senderId,
            receiverId: "me",
            senderName: senderName,
            message: message,
            urgency: WakeRequest.Urgency(rawValue: urgency) ?? .normal,
            alarmSoundId: alarmSoundId
        )
        
        Task { @MainActor in
            self.activeWakeRequest = wakeRequest
            self.showingWakeAlert = true
            
            // Play alarm at maximum volume using AmbientAudioManager
            // This ensures alarm sounds even when phone is locked
            let alarmSound = AlarmSound.from(id: alarmSoundId)
            AmbientAudioManager.shared.playAlarm(soundName: alarmSound.rawValue, fileExtension: "caf")
        }
    }
    
    // MARK: - Register Existing Token
    func registerExistingToken() async {
        guard let token = deviceToken else {
            debugLogger.log(eventType: "register_existing_token_failed", message: "No existing token to register")
            return
        }
        
        await registerDeviceTokenWithBackend(token: token)
    }
    
    /// Called by AppDelegate for background remote notifications
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        if isWakeAlarm(userInfo) {
            handleWakeAlarm(userInfo)
        } else if isWakeConfirmation(userInfo) {
            handleWakeConfirmation(userInfo)
        }
    }

    /// Call this when user logs in to register any cached token
    func onUserLoggedIn() async {
        debugLogger.log(eventType: "user_logged_in", message: "User logged in, checking for cached token")
        
        // Check for cached token
        if let cachedToken = UserDefaults.standard.string(forKey: cachedTokenKey) {
            debugLogger.log(eventType: "uploading_cached_token", message: "Uploading cached token to backend")
            await registerDeviceTokenWithBackend(token: cachedToken)
        } else if let token = deviceToken {
            // Or use in-memory token
            debugLogger.log(eventType: "uploading_memory_token", message: "Uploading in-memory token to backend")
            await registerDeviceTokenWithBackend(token: token)
        } else {
            debugLogger.log(eventType: "no_token_to_upload", message: "No token available to upload")
        }
    }
}

// MARK: - App Delegate Handlers
extension PushNotificationManager {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        didFailToRegisterForRemoteNotifications(withError: error)
    }
}
