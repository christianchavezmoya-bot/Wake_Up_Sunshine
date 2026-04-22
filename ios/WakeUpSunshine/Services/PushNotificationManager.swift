import Foundation
import UserNotifications

class PushNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var deviceToken: String?
    @Published var criticalAlertsEnabled: Bool = false

    private let apiClient = APIClient.shared

    // MARK: - Register for Notifications
    func requestAuthorization() async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()

            // Request notification permission
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert])

            await MainActor.run {
                self.criticalAlertsEnabled = granted
            }

            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    // MARK: - Register Device Token
    func registerDeviceToken(_ token: String) {
        deviceToken = token

        // Send token to backend
        Task {
            await sendTokenToServer(token)
        }
    }

    private func sendTokenToServer(_ token: String) async {
        do {
            let _: EmptyResponse = try await apiClient.request(
                endpoint: "/devices/register",
                method: "POST",
                body: [
                    "token": token,
                    "deviceType": "iphone",
                    "isPrimary": true
                ]
            )
        } catch {
            print("Failed to register device token: \(error)")
        }
    }

    // MARK: - Handle Remote Notifications
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        registerDeviceToken(token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }

    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Handle notification when app is in foreground
        let userInfo = notification.request.content.userInfo

        if let wakeData = userInfo["wakeRequest"] as? [String: Any] {
            // This is a wake alert - show it even when app is in foreground
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.banner, .sound])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Handle wake alert actions
        if response.actionIdentifier == "CONFIRM_WAKE" {
            handleWakeConfirmation(userInfo)
        } else if response.actionIdentifier == "SNOOZE_WAKE" {
            handleWakeSnooze(userInfo)
        }

        completionHandler()
    }

    // MARK: - Handle Wake Actions
    private func handleWakeConfirmation(_ userInfo: [AnyHashable: Any]) {
        if let requestId = userInfo["requestId"] as? String {
            Task {
                await sendWakeConfirmation(requestId: requestId)
            }
        }
    }

    private func handleWakeSnooze(_ userInfo: [AnyHashable: Any]) {
        if let requestId = userInfo["requestId"] as? String {
            Task {
                await sendWakeSnooze(requestId: requestId)
            }
        }
    }

    private func sendWakeConfirmation(requestId: String) async {
        do {
            let _: EmptyResponse = try await apiClient.request(
                endpoint: "/wake/\(requestId)/confirm",
                method: "POST"
            )
        } catch {
            print("Failed to send wake confirmation: \(error)")
        }
    }

    private func sendWakeSnooze(requestId: String) async {
        do {
            let _: EmptyResponse = try await apiClient.request(
                endpoint: "/wake/\(requestId)/snooze",
                method: "POST"
            )
        } catch {
            print("Failed to send wake snooze: \(error)")
        }
    }

    // MARK: - Register Notification Categories
    func registerNotificationCategories() {
        let confirmAction = UNNotificationAction(
            identifier: "CONFIRM_WAKE",
            title: "I'm Awake",
            options: [.foreground]
        )

        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_WAKE",
            title: "Snooze (5 min)",
            options: []
        )

        let wakeCategory = UNNotificationCategory(
            identifier: "WAKE_ALERT",
            actions: [confirmAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([wakeCategory])
    }
}