import SwiftUI
import UserNotifications

@main
struct WakeUpSunshineApp: App {
    // Register AppDelegate for APNs callbacks
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var appState = AppState()
    @StateObject private var authManager = AuthManager()
    // Use the singleton so that notification callbacks update the same object the UI observes
    @StateObject private var pushManager = PushNotificationManager.shared

    init() {
        setupAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(authManager)
                .environmentObject(pushManager)
                .environmentObject(DeepLinkManager.shared)
                .onAppear {
                    setupNotifications()
                    Task {
                        await authManager.checkSession()
                        registerForPushNotificationsIfLoggedIn()
                    }
                }
                .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                    if isAuthenticated {
                        appDelegate.registerForPushNotifications()
                        Task { await PushNotificationManager.shared.onUserLoggedIn() }
                        // Process any invite link that arrived before login
                        Task { await DeepLinkManager.shared.processPendingInvite() }
                    }
                }
                .onOpenURL { url in
                    // Auth callback: wakeupsunshine://#access_token=...&type=signup|recovery
                    if url.scheme == "wakeupsunshine",
                       let fragment = url.fragment,
                       fragment.contains("access_token") {
                        Task {
                            do {
                                try await SupabaseManager.shared.client.auth.session(from: url)
                                await authManager.checkSession()
                            } catch {
                                await MainActor.run {
                                    appState.authCallbackError = "Sign-in link expired or already used. Please sign in manually."
                                }
                            }
                        }
                        return
                    }
                    DeepLinkManager.shared.handle(url: url)
                    if authManager.isAuthenticated {
                        Task { await DeepLinkManager.shared.processPendingInvite() }
                    }
                    // If not logged in, the token is held in pendingToken and
                    // processed by the onChange(of: isAuthenticated) block above.
                }
                .alert("Sign-in Failed", isPresented: Binding(
                    get: { appState.authCallbackError != nil },
                    set: { if !$0 { appState.authCallbackError = nil } }
                )) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(appState.authCallbackError ?? "")
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
    
    private func registerForPushNotificationsIfLoggedIn() {
        // Check if user is logged in and register for push notifications
        Task {
            if SupabaseManager.shared.client.auth.currentSession != nil {
                DebugLogger.shared.log(eventType: "push_auto_register", message: "User logged in, registering for push notifications")
                appDelegate.registerForPushNotifications()
                // Also upload any cached token
                await PushNotificationManager.shared.onUserLoggedIn()
            } else {
                DebugLogger.shared.log(eventType: "push_auto_register_skipped", message: "User not logged in, skipping push registration")
            }
        }
    }
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var isOnboardingComplete: Bool
    @Published var currentUser: User?
    @Published var showingWakeAlert: Bool = false
    @Published var activeWakeRequest: WakeRequest?
    @Published var authCallbackError: String?

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

// MARK: - Contact Model (for display)
struct Contact: Identifiable {
    let id: String
    let userId: String
    var displayName: String
    var email: String
    var avatarColor: String
    var isOnline: Bool
    var permissionStatus: WakePermission.PermissionStatus
    var lastWakeAt: Date?

    init(from permission: WakePermission, displayName: String, avatarColor: String, isOnline: Bool = false) {
        self.id = permission.id
        self.userId = permission.trusteeId
        self.displayName = displayName
        self.email = ""
        self.avatarColor = avatarColor
        self.isOnline = isOnline
        self.permissionStatus = permission.status
        self.lastWakeAt = nil
    }
    
    // Convenience initializer for ContactItem mapping
    init(id: String, userId: String, displayName: String, email: String, avatarColor: String, isOnline: Bool = false) {
        self.id = id
        self.userId = userId
        self.displayName = displayName
        self.email = email
        self.avatarColor = avatarColor
        self.isOnline = isOnline
        self.permissionStatus = .active
        self.lastWakeAt = nil
    }
}
