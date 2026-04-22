import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    enum Tab: Int, CaseIterable {
        case home
        case contacts
        case history
        case settings

        var title: String {
            switch self {
            case .home: return "Home"
            case .contacts: return "Contacts"
            case .history: return "History"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .home: return "house.fill"
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
        .tint(Color("PrimaryOrange"))
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
        .environmentObject(AuthManager())
        .environmentObject(PushNotificationManager())
}