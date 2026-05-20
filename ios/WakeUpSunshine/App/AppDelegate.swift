import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        DebugLogger.shared.log(eventType: "app_launch", message: "Application launched")
        
        // Set the notification delegate to PushNotificationManager
        UNUserNotificationCenter.current().delegate = PushNotificationManager.shared
        
        // Start ambient audio to keep app alive in background for alarm delivery
        AmbientAudioManager.shared.startAmbientAudio()
        
        return true
    }
    
    // MARK: - APNs Registration
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        DebugLogger.shared.log(eventType: "apns_token_received", message: "APNs device token received")
        PushNotificationManager.shared.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        DebugLogger.shared.log(eventType: "apns_register_failed", message: "APNs registration failed: \(error.localizedDescription)")
        PushNotificationManager.shared.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }

    // Handle remote notification delivered while app is in background
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        DebugLogger.shared.log(eventType: "background_notification_received", message: "Remote notification received in background")
        PushNotificationManager.shared.handleRemoteNotification(userInfo)
        completionHandler(.newData)
    }
}

// MARK: - Push Notification Registration Helper
extension AppDelegate {
    
    /// Call this after user logs in or on app launch if already authenticated
    func registerForPushNotifications() {
        DebugLogger.shared.log(eventType: "push_registration_requested", message: "Requesting push notification registration")
        
        Task {
            await PushNotificationManager.shared.registerForPushNotifications()
        }
    }
}
