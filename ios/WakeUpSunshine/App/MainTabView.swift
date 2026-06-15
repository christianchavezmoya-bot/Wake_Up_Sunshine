import SwiftUI

struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: Tab = .home
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var contactsViewModel = ContactsViewModel()
    
    enum Tab: Int, CaseIterable {
        case home
        case contacts
        case history
        case settings

        var title: String {
            switch self {
            case .home: return "Wake up"
            case .contacts: return "Contacts"
            case .history: return "History"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .home: return "bell.fill"
            case .contacts: return "person.2.fill"
            case .history: return "clock.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(Tab.home.title, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)

            ContactsView()
                .tabItem {
                    Label(Tab.contacts.title, systemImage: Tab.contacts.icon)
                }
                .tag(Tab.contacts)

            HistoryView()
                .tabItem {
                    Label(Tab.history.title, systemImage: Tab.history.icon)
                }
                .tag(Tab.history)

            SettingsView()
                .tabItem {
                    Label(Tab.settings.title, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .tint(themeManager.primaryColor)
        .preferredColorScheme(themeManager.colorScheme)
        .environmentObject(contactsViewModel)
        .task {
            contactsViewModel.startSync()
            await contactsViewModel.fetchAllData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .contactsShouldRefresh)) { _ in
            Task { await contactsViewModel.fetchAllData() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await contactsViewModel.fetchAllData() }
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
        .environmentObject(AuthManager())
        .environmentObject(PushNotificationManager())
}
