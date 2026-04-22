import SwiftUI

struct ContactsView: View {
    @StateObject private var viewModel = ContactsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Active Contacts Section
                        if !viewModel.activeContacts.isEmpty {
                            ContactsSection(
                                title: "People Who Can Wake Me",
                                contacts: viewModel.activeContacts,
                                rowType: .active
                            )
                        }

                        // Pending Requests Section
                        if !viewModel.pendingContacts.isEmpty {
                            ContactsSection(
                                title: "Pending Requests",
                                contacts: viewModel.pendingContacts,
                                rowType: .pending
                            )
                        }
                    }
                    .padding(.top, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
            }
            .navigationTitle("Contacts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.primaryOrange)
                    }
                    .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)
                }
            }
        }
    }
}

// MARK: - Contacts Section
struct ContactsSection: View {
    let title: String
    let contacts: [Contact]
    let rowType: ContactRowType

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundColor(.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            VStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(contacts) { contact in
                    ContactRow(
                        contact: contact,
                        rowType: rowType
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
    }
}

// MARK: - Contact Row Type
enum ContactRowType {
    case active
    case pending
}

// MARK: - Contact Row
struct ContactRow: View {
    let contact: Contact
    let rowType: ContactRowType

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(hex: contact.avatarColor).opacity(rowType == .pending ? 0.3 : 1.0))
                    .frame(width: DesignSystem.TouchTargets.minimum + 8, height: DesignSystem.TouchTargets.minimum + 8)

                Text(contact.displayName.prefix(1).uppercased())
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(rowType == .pending ? Color(hex: contact.avatarColor) : .white)
            }

            // Info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(contact.displayName)
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Text(rowType == .active ? "Can wake me anytime" : "Wants to wake you")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            // Action
            if rowType == .active {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.success)
            } else {
                PendingActions()
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.appCard)
        .cornerRadius(DesignSystem.Spacing.buttonRadius)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if rowType == .active {
                Button(role: .destructive) {
                    // Delete action
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Pending Actions with Larger Touch Targets
struct PendingActions: View {
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            // Deny Button
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)
                    .background(DesignSystem.Colors.error)
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())

            // Approve Button
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }) {
                Image(systemName: "checkmark")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)
                    .background(DesignSystem.Colors.success)
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
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
