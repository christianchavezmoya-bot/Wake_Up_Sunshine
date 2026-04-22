import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = HomeViewModel()
    @State private var showAddContact = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color("Background").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Wake Up Sunshine")
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text(greeting())
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: {}) {
                                Circle()
                                    .fill(Color("PrimaryOrange"))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text("A")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                        // Section: People I Can Wake
                        VStack(alignment: .leading, spacing: 16) {
                            Text("People I Can Wake")
                                .font(.headline)
                                .padding(.horizontal, 24)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(viewModel.contacts) { contact in
                                    ContactCard(contact: contact) {
                                        viewModel.sendWakeRequest(to: contact)
                                    }
                                }

                                // Add Contact Card
                                Button(action: { showAddContact = true }) {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            Circle()
                                                .fill(Color("PrimaryOrange").opacity(0.1))
                                                .frame(width: 64, height: 64)

                                            Image(systemName: "plus")
                                                .font(.title2)
                                                .foregroundColor(Color("PrimaryOrange"))
                                        }

                                        Text("Add Contact")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)

                                        Text("Invite friends & family")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .background(Color("Surface"))
                                    .cornerRadius(16)
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        // Empty State
                        if viewModel.contacts.isEmpty {
                            EmptyContactsView()
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddContact) {
                AddContactSheet()
            }
            .alert("Wake Alert Sent", isPresented: $viewModel.showWakeConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("\(viewModel.lastWakedContact?.displayName ?? "Contact") received your wake alert!")
            }
        }
    }

    private func greeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good morning"
        } else if hour < 17 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }
}

// MARK: - Contact Card
struct ContactCard: View {
    let contact: Contact
    let onWake: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color(hex: contact.avatarColor))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Text(contact.displayName.prefix(1).uppercased())
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )

                if contact.isOnline {
                    Circle()
                        .fill(Color("Success"))
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color("Surface"), lineWidth: 2)
                        )
                        .offset(x: 4, y: -4)
                }
            }

            Text(contact.displayName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)

            Text(contact.isOnline ? "Online" : "Offline")
                .font(.caption)
                .foregroundColor(contact.isOnline ? Color("Success") : .secondary)

            // Wake Button
            Button(action: onWake) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color("PrimaryOrange"), Color("PrimaryOrangeLight")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: Color("PrimaryOrange").opacity(0.4), radius: 8, y: 4)

                    Image(systemName: "bell.fill")
                        .font(.title2)
                        .foregroundColor(.white)

                    // Pulse animation
                    Circle()
                        .stroke(Color("PrimaryOrange"), lineWidth: 2)
                        .frame(width: 56, height: 56)
                        .modifier(PulseRingAnimation())
                }
            }
        }
        .padding(20)
        .background(Color("Surface"))
        .cornerRadius(16)
    }
}

// MARK: - Pulse Ring Animation
struct PulseRingAnimation: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.3 : 1.0)
            .opacity(isAnimating ? 0 : 0.8)
            .animation(
                .easeOut(duration: 1.5)
                .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

// MARK: - Empty Contacts View
struct EmptyContactsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Trusted Contacts Yet")
                .font(.headline)

            Text("Add people who can wake you up when it matters most.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Add Contact Sheet
struct AddContactSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showInviteOptions = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color("Background").ignoresSafeArea()

                VStack(spacing: 16) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)

                        TextField("Search by phone number or name", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(14)
                    .background(Color("Surface"))
                    .cornerRadius(12)
                    .padding(.horizontal, 24)

                    // Invite Options
                    VStack(spacing: 12) {
                        Button(action: { showInviteOptions = true }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color("PrimaryOrange").opacity(0.1))
                                        .frame(width: 44, height: 44)

                                    Image(systemName: "message.fill")
                                        .foregroundColor(Color("PrimaryOrange"))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Invite via SMS")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Send an invite link to a phone number")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(16)
                            .background(Color("Surface"))
                            .cornerRadius(12)
                        }

                        Button(action: {}) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color("Secondary").opacity(0.1))
                                        .frame(width: 44, height: 44)

                                    Image(systemName: "qrcode.viewfinder")
                                        .foregroundColor(Color("Secondary"))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Share QR Code")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Let them scan your code to connect")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(16)
                            .background(Color("Surface"))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
                .padding(.top, 16)
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Home ViewModel
class HomeViewModel: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var showWakeConfirmation = false
    @Published var lastWakedContact: Contact?

    init() {
        loadMockContacts()
    }

    func loadMockContacts() {
        // Mock data
        contacts = [
            Contact(from: WakePermission(granterId: "me", trusteeId: "alex"), displayName: "Alex Chen", avatarColor: "#667eea", isOnline: true),
            Contact(from: WakePermission(granterId: "me", trusteeId: "sarah"), displayName: "Sarah Miller", avatarColor: "#f5576c", isOnline: false),
            Contact(from: WakePermission(granterId: "me", trusteeId: "mike"), displayName: "Mike Johnson", avatarColor: "#4facfe", isOnline: true),
            Contact(from: WakePermission(granterId: "me", trusteeId: "emma"), displayName: "Emma Davis", avatarColor: "#43e97b", isOnline: false),
        ]
    }

    func sendWakeRequest(to contact: Contact) {
        lastWakedContact = contact
        showWakeConfirmation = true
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}