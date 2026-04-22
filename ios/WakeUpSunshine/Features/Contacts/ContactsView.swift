import SwiftUI

struct ContactsView: View {
    @StateObject private var viewModel = ContactsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color("Background").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Active Contacts
                        VStack(alignment: .leading, spacing: 16) {
                            Text("People Who Can Wake Me")
                                .font(.headline)
                                .padding(.horizontal, 24)

                            VStack(spacing: 12) {
                                ForEach(viewModel.activeContacts) { contact in
                                    ContactListRow(contact: contact)
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        // Pending Requests
                        if !viewModel.pendingContacts.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Pending Requests")
                                    .font(.headline)
                                    .padding(.horizontal, 24)

                                VStack(spacing: 12) {
                                    ForEach(viewModel.pendingContacts) { contact in
                                        PendingContactRow(contact: contact) { approved in
                                            viewModel.handlePermission(contact: contact, approved: approved)
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Contacts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .foregroundColor(Color("PrimaryOrange"))
                    }
                }
            }
        }
    }
}

// MARK: - Contact List Row
struct ContactListRow: View {
    let contact: Contact

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: contact.avatarColor))
                    .frame(width: 52, height: 52)

                Text(contact.displayName.prefix(1).uppercased())
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(contact.displayName)
                    .font(.headline)

                Text("Can wake me anytime")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(Color("Success"))
        }
        .padding(16)
        .background(Color("Surface"))
        .cornerRadius(12)
    }
}

// MARK: - Pending Contact Row
struct PendingContactRow: View {
    let contact: Contact
    let onAction: (Bool) -> Void

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: contact.avatarColor).opacity(0.3))
                    .frame(width: 52, height: 52)

                Text(contact.displayName.prefix(1).uppercased())
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: contact.avatarColor))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(contact.displayName)
                    .font(.headline)

                Text("Wants to wake you")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: { onAction(false) }) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color("Error"))
                        .clipShape(Circle())
                }

                Button(action: { onAction(true) }) {
                    Image(systemName: "checkmark")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color("Success"))
                        .clipShape(Circle())
                }
            }
        }
        .padding(16)
        .background(Color("Surface"))
        .cornerRadius(12)
    }
}

// MARK: - Contacts ViewModel
class ContactsViewModel: ObservableObject {
    @Published var activeContacts: [Contact] = []
    @Published var pendingContacts: [Contact] = []

    init() {
        loadMockData()
    }

    func loadMockData() {
        activeContacts = [
            Contact(from: WakePermission(granterId: "me", trusteeId: "alex"), displayName: "Alex Chen", avatarColor: "#667eea", isOnline: true),
            Contact(from: WakePermission(granterId: "me", trusteeId: "sarah"), displayName: "Sarah Miller", avatarColor: "#f5576c", isOnline: false),
            Contact(from: WakePermission(granterId: "me", trusteeId: "mike"), displayName: "Mike Johnson", avatarColor: "#4facfe", isOnline: true),
        ]

        pendingContacts = [
            Contact(from: WakePermission(granterId: "me", trusteeId: "james"), displayName: "James Wilson", avatarColor: "#ffecd2", isOnline: false),
        ]
    }

    func handlePermission(contact: Contact, approved: Bool) {
        if approved {
            pendingContacts.removeAll { $0.id == contact.id }
            activeContacts.append(contact)
        } else {
            pendingContacts.removeAll { $0.id == contact.id }
        }
    }
}

#Preview {
    ContactsView()
}