import SwiftUI
import UserNotifications

@main
struct WakeUpSunshineApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authManager = AuthManager()
    @StateObject private var pushManager = PushNotificationManager()

    init() {
        setupAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(authManager)
                .environmentObject(pushManager)
                .onAppear {
                    setupNotifications()
                }
        }
    }

    private func setupAppearance() {
        // Navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor.systemBackground
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]

        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance

        // Tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }

    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = pushManager
    }
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var isOnboardingComplete: Bool
    @Published var currentUser: User?
    @Published var showingWakeAlert: Bool = false
    @Published var activeWakeRequest: WakeRequest?

    init() {
        self.isOnboardingComplete = UserDefaults.standard.bool(forKey: "onboardingComplete")
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
        isOnboardingComplete = true
    }
}

// MARK: - User Model
struct User: Identifiable, Codable {
    let id: String
    var phoneNumber: String
    var displayName: String
    var avatarColor: String
    var createdAt: Date

    init(id: String = UUID().uuidString, phoneNumber: String, displayName: String, avatarColor: String = "#FF6B35") {
        self.id = id
        self.phoneNumber = phoneNumber
        self.displayName = displayName
        self.avatarColor = avatarColor
        self.createdAt = Date()
    }
}

// MARK: - Device Model
struct UserDevice: Identifiable, Codable {
    let id: String
    let userId: String
    var deviceToken: String
    var deviceType: DeviceType
    var isPrimary: Bool
    var criticalAlertsEnabled: Bool
    var lastActiveAt: Date

    enum DeviceType: String, Codable {
        case iphone
        case ipad
        case watch
    }

    init(id: String = UUID().uuidString, userId: String, deviceToken: String, deviceType: DeviceType = .iphone, isPrimary: Bool = true) {
        self.id = id
        self.userId = userId
        self.deviceToken = deviceToken
        self.deviceType = deviceType
        self.isPrimary = isPrimary
        self.criticalAlertsEnabled = true
        self.lastActiveAt = Date()
    }
}

// MARK: - Permission Model
struct WakePermission: Identifiable, Codable {
    let id: String
    let granterId: String    // The receiver (person who grants permission)
    let trusteeId: String    // The sender (person who can wake)
    var status: PermissionStatus
    var scheduleStart: Date?
    var scheduleEnd: Date?
    var createdAt: Date
    var updatedAt: Date

    enum PermissionStatus: String, Codable {
        case pending
        case active
        case blocked
    }

    init(id: String = UUID().uuidString, granterId: String, trusteeId: String) {
        self.id = id
        self.granterId = granterId
        self.trusteeId = trusteeId
        self.status = .pending
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Wake Request Model
struct WakeRequest: Identifiable, Codable {
    let id: String
    let senderId: String
    let receiverId: String
    var message: String?
    var urgency: WakeUrgency
    var status: WakeStatus
    var sentAt: Date
    var deliveredAt: Date?
    var dismissedAt: Date?
    var confirmedAt: Date?
    var snoozedAt: Date?

    enum WakeUrgency: String, Codable {
        case low
        case normal
        case high
        case emergency
    }

    enum WakeStatus: String, Codable {
        case pending
        case delivered
        case alarmPlaying
        case dismissed
        case confirmed
        case snoozed
        case expired
    }

    init(id: String = UUID().uuidString, senderId: String, receiverId: String, message: String? = nil, urgency: WakeUrgency = .normal) {
        self.id = id
        self.senderId = senderId
        self.receiverId = receiverId
        self.message = message
        self.urgency = urgency
        self.status = .pending
        self.sentAt = Date()
    }
}

// MARK: - Contact Model (for display)
struct Contact: Identifiable {
    let id: String
    let userId: String
    var displayName: String
    var avatarColor: String
    var isOnline: Bool
    var permissionStatus: WakePermission.PermissionStatus
    var lastWakeAt: Date?

    init(from permission: WakePermission, displayName: String, avatarColor: String, isOnline: Bool = false) {
        self.id = permission.id
        self.userId = permission.trusteeId
        self.displayName = displayName
        self.avatarColor = avatarColor
        self.isOnline = isOnline
        self.permissionStatus = permission.status
        self.lastWakeAt = nil
    }
}