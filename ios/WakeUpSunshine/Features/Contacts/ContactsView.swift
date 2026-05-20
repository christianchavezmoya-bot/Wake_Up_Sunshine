import SwiftUI

struct ContactsView: View {
    @EnvironmentObject var viewModel: ContactsViewModel
    @State private var showAddContact = false
    @State private var editingNicknameFor: Contact?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if viewModel.isLoading && viewModel.activeContacts.isEmpty && viewModel.pendingReceived.isEmpty {
                    ProgressView("Loading contacts...")
                        .foregroundColor(.textSecondary)
                } else {
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            // People I Can Wake (I am the trustee - I can wake these people)
                            if !viewModel.peopleICanWake.isEmpty {
                                ContactsSection(
                                    title: "People I Can Wake",
                                    subtitle: "Tap to send a wake alert",
                                    contacts: viewModel.peopleICanWake,
                                    rowType: .canWake,
                                    onWakeTap: { _ in },
                                    onEditTap: { contact in editingNicknameFor = contact },
                                    onDelete: { contact in
                                        Task { await viewModel.removeContact(contact, iAmGranter: false) }
                                    }
                                )
                            }

                            // People Who Can Wake Me (I am the granter)
                            if !viewModel.peopleWhoCanWakeMe.isEmpty {
                                ContactsSection(
                                    title: "People Who Can Wake Me",
                                    subtitle: "They can send you wake alerts",
                                    contacts: viewModel.peopleWhoCanWakeMe,
                                    rowType: .canWakeMe,
                                    onWakeTap: nil,
                                    onEditTap: { contact in editingNicknameFor = contact },
                                    onDelete: { contact in
                                        Task { await viewModel.removeContact(contact, iAmGranter: true) }
                                    },
                                    onBlock: { contact in
                                        Task { await viewModel.blockContact(contact) }
                                    }
                                )
                            }

                            // Pending Invites Received
                            if !viewModel.pendingReceived.isEmpty {
                                PendingInvitesSection(
                                    title: "Pending Invites",
                                    subtitle: "People who want to wake you",
                                    invites: viewModel.pendingReceived,
                                    onAccept: { invite in
                                        Task { await viewModel.acceptInvite(invite) }
                                    },
                                    onDecline: { invite in
                                        Task { await viewModel.declineInvite(invite) }
                                    }
                                )
                            }

                            // Pending Invites Sent
                            if !viewModel.pendingSent.isEmpty {
                                SentInvitesSection(
                                    title: "Invites You Sent",
                                    invites: viewModel.pendingSent,
                                    onCancel: { invite in
                                        Task { await viewModel.cancelSentInvite(invite) }
                                    }
                                )
                            }

                            // Empty State
                            if viewModel.activeContacts.isEmpty && viewModel.pendingReceived.isEmpty && viewModel.pendingSent.isEmpty {
                                EmptyContactsState(onAddContact: { showAddContact = true })
                            }
                        }
                        .padding(.top, DesignSystem.Spacing.md)
                        .padding(.bottom, DesignSystem.Spacing.xxl)
                    }
                    .refreshable {
                        await viewModel.fetchAllData()
                    }
                }
            }
            .navigationTitle("Manage Contacts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddContact = true }) {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.primaryOrange)
                    }
                    .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)
                }
            }
            .sheet(isPresented: $showAddContact) {
                AddContactSheet(onInviteSent: {
                    Task { await viewModel.fetchAllData() }
                })
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "Unknown error")
            }
            .sheet(item: $editingNicknameFor) { contact in
                NicknameEditSheet(contact: contact) { newNickname in
                    NicknameStore.set(newNickname, for: contact.email)
                    editingNicknameFor = nil
                    Task { await viewModel.fetchAllData() }
                }
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Contact Grid Card (used in Contacts page grid)
struct ContactGridCard: View {
    let contact: Contact
    let rowType: ContactRowType
    var onEditTap: ((Contact) -> Void)?
    var onDelete: ((Contact) -> Void)?
    var onBlock: ((Contact) -> Void)?

    private var iconName: String { rowType == .canWake ? "bell.fill" : "person.fill" }
    private var iconColor: Color { rowType == .canWake ? DesignSystem.Colors.primaryOrange : DesignSystem.Colors.success }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)
                Image(systemName: iconName)
                    .font(.headline)
                    .foregroundColor(iconColor)
            }

            Text(contact.displayName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 4) {
                Circle()
                    .fill(DesignSystem.Colors.success)
                    .frame(width: 6, height: 6)
                Text("Ready")
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.success)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(Color.appCard)
        .cornerRadius(DesignSystem.Spacing.cardRadius)
        .shadow(
            color: DesignSystem.Shadows.cardShadow.color,
            radius: DesignSystem.Shadows.cardShadow.radius,
            x: DesignSystem.Shadows.cardShadow.x,
            y: DesignSystem.Shadows.cardShadow.y
        )
        .contextMenu {
            if let onEditTap {
                Button { onEditTap(contact) } label: {
                    Label("Edit Nickname", systemImage: "pencil")
                }
            }
            Divider()
            if let onBlock, rowType == .canWakeMe {
                Button(role: .destructive) { onBlock(contact) } label: {
                    Label("Block Contact", systemImage: "hand.raised.fill")
                }
            }
            if let onDelete {
                Button(role: .destructive) { onDelete(contact) } label: {
                    Label("Remove Contact", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Contacts Section
struct ContactsSection: View {
    let title: String
    let subtitle: String
    let contacts: [Contact]
    let rowType: ContactRowType
    var onWakeTap: ((Contact) -> Void)?
    var onEditTap: ((Contact) -> Void)?
    var onDelete: ((Contact) -> Void)?
    var onBlock: ((Contact) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundColor(.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.textSecondary)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: DesignSystem.Spacing.md
            ) {
                ForEach(contacts) { contact in
                    ContactGridCard(
                        contact: contact,
                        rowType: rowType,
                        onEditTap: onEditTap,
                        onDelete: onDelete,
                        onBlock: onBlock
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
    }
}

// MARK: - Pending Invites Section
struct PendingInvitesSection: View {
    let title: String
    let subtitle: String
    let invites: [InviteItem]
    let onAccept: (InviteItem) -> Void
    let onDecline: (InviteItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundColor(.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.textSecondary)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            VStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(invites) { invite in
                    PendingInviteItemRow(
                        invite: invite,
                        onAccept: { onAccept(invite) },
                        onDecline: { onDecline(invite) }
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
    }
}

// MARK: - Sent Invites Section
struct SentInvitesSection: View {
    let title: String
    let invites: [InviteItem]
    var onCancel: ((InviteItem) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundColor(.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            VStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(invites) { invite in
                    SentInviteItemRow(invite: invite, onCancel: onCancel.map { cb in { cb(invite) } })
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
    }
}

// MARK: - Contact Row Type
enum ContactRowType {
    case canWake
    case canWakeMe
}

// MARK: - Pending Invite Row
struct PendingInviteRow: View {
    let invite: ReceivedInvite
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primaryOrange.opacity(0.2))
                    .frame(width: DesignSystem.TouchTargets.minimum + 8, height: DesignSystem.TouchTargets.minimum + 8)

                Text(invite.inviter_name.prefix(1).uppercased())
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.primaryOrange)
            }

            // Info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(invite.inviter_name)
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Text("Wants to wake you")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            // Actions
            HStack(spacing: DesignSystem.Spacing.xs) {
                Button(action: onDecline) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)
                        .background(DesignSystem.Colors.error)
                        .clipShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())

                Button(action: onAccept) {
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
        .padding(DesignSystem.Spacing.md)
        .background(Color.appCard)
        .cornerRadius(DesignSystem.Spacing.buttonRadius)
    }
}

// MARK: - Sent Invite Row
struct SentInviteRow: View {
    let invite: SentInvite

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.textTertiary.opacity(0.2))
                    .frame(width: DesignSystem.TouchTargets.minimum + 8, height: DesignSystem.TouchTargets.minimum + 8)

                Image(systemName: "envelope")
                    .font(.title3)
                    .foregroundColor(.textSecondary)
            }

            // Info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(invite.invitee_email)
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }

            Spacer()

            // Status Badge
            Text(invite.status.capitalized)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .background(statusColor.opacity(0.1))
                .cornerRadius(DesignSystem.Spacing.xs)
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.appCard)
        .cornerRadius(DesignSystem.Spacing.buttonRadius)
    }

    private var statusText: String {
        switch invite.status {
        case "pending":
            let expires = ISO8601DateFormatter().date(from: invite.expires_at) ?? Date()
            let formatter = RelativeDateTimeFormatter()
            return "Expires \(formatter.localizedString(for: expires, relativeTo: Date()))"
        case "accepted":
            return "Accepted"
        case "declined":
            return "Declined"
        default:
            return invite.status.capitalized
        }
    }

    private var statusColor: Color {
        switch invite.status {
        case "pending":
            return DesignSystem.Colors.primaryOrange
        case "accepted":
            return DesignSystem.Colors.success
        case "declined":
            return DesignSystem.Colors.error
        default:
            return .textSecondary
        }
    }
}

// MARK: - Pending Invite Item Row (New)
struct PendingInviteItemRow: View {
    let invite: InviteItem
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(invite.inviterName ?? invite.inviterEmail ?? "Unknown")
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Text("Wants to wake you")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            // Actions
            HStack(spacing: DesignSystem.Spacing.xs) {
                Button(action: onDecline) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)
                        .background(DesignSystem.Colors.error)
                        .clipShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())

                Button(action: onAccept) {
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
        .padding(DesignSystem.Spacing.md)
        .background(Color.appCard)
        .cornerRadius(DesignSystem.Spacing.buttonRadius)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDecline) {
                Label("Decline", systemImage: "xmark.circle")
            }
        }
    }
}

// MARK: - Sent Invite Item Row (New)
struct SentInviteItemRow: View {
    let invite: InviteItem
    var onCancel: (() -> Void)?

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(primaryText)
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Text(secondaryText)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            // Cancel button
            if let cancel = onCancel {
                Button(action: cancel) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(DesignSystem.Colors.error)
                        .clipShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.appCard)
        .cornerRadius(DesignSystem.Spacing.buttonRadius)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onCancel?()
            } label: {
                Label("Cancel", systemImage: "xmark.circle")
            }
        }
    }

    private var primaryText: String {
        let label = invite.inviteeLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !label.isEmpty {
            return label
        }

        guard let email = invite.inviteeEmail, !email.isEmpty else {
            return "Share Link Invite"
        }
        if email.hasSuffix("@share.link") || email.hasSuffix("@qr.code") {
            return "Share Link Invite"
        }
        return email
    }

    private var secondaryText: String {
        guard let email = invite.inviteeEmail, !email.isEmpty else {
            return "Waiting for them to accept"
        }
        if email.hasSuffix("@share.link") || email.hasSuffix("@qr.code") {
            return "Waiting for them to accept via shared link"
        }
        if let label = invite.inviteeLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            return "\(email) - Waiting for them to accept"
        }
        return "Waiting for them to accept"
    }
}

// MARK: - Empty State
struct EmptyContactsState: View {
    let onAddContact: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primaryOrange.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "person.badge.plus")
                    .font(.system(size: 44))
                    .foregroundColor(DesignSystem.Colors.primaryOrange)
            }

            Text("No Contacts Yet")
                .font(.headline)
                .foregroundColor(.textPrimary)

            Text("Invite friends and family so they can wake you up when it matters most.")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)

            Button(action: onAddContact) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Contact")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.primaryOrange)
                .cornerRadius(DesignSystem.Spacing.buttonRadius)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xxl)
    }
}

// MARK: - Contacts ViewModel
@MainActor
class ContactsViewModel: ObservableObject {
    @Published var peopleICanWake: [Contact] = []
    @Published var peopleWhoCanWakeMe: [Contact] = []
    @Published var blockedContacts: [Contact] = []
    @Published var pendingReceived: [InviteItem] = []
    @Published var pendingSent: [InviteItem] = []
    @Published var isLoading = false
    @Published var error: String?

    private let inviteService = InviteService.shared
    private var autoRefreshTask: Task<Void, Never>?

    var activeContacts: [Contact] {
        peopleICanWake + peopleWhoCanWakeMe
    }

    deinit {
        autoRefreshTask?.cancel()
    }

    func startSync() {
        guard autoRefreshTask == nil else { return }

        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.refreshIfNeeded()
            }
        }
    }

    private func refreshIfNeeded() async {
        guard !isLoading else { return }
        guard SupabaseManager.shared.client.auth.currentSession != nil else { return }
        await fetchAllData()
    }

    func fetchAllData() async {
        isLoading = true
        error = nil

        do {
            // Use new get-contacts endpoint with standard response shape
            let result = try await inviteService.fetchContacts()
            
            if !result.success {
                self.error = result.error ?? "Failed to fetch contacts"
                isLoading = false
                return
            }
            
            // Map ContactItem to Contact, applying any saved nickname
            let mapContact = { (item: ContactItem) -> Contact in
                let baseName = item.displayName.isEmpty ? item.email : item.displayName
                return Contact(
                    id: item.id.uuidString,
                    userId: item.userId?.uuidString ?? item.id.uuidString,
                    displayName: NicknameStore.get(for: item.email) ?? baseName,
                    email: item.email,
                    avatarColor: self.generateColor(from: item.email),
                    isOnline: false
                )
            }
            peopleICanWake = result.peopleICanWake.map(mapContact)
            peopleWhoCanWakeMe = result.peopleWhoCanWakeMe.map(mapContact)
            blockedContacts = result.blockedContacts.map(mapContact)
            
            pendingSent = result.pendingInvitesSent
            pendingReceived = result.pendingInvitesReceived

            print("[ContactsViewModel] Fetched: peopleICanWake=\(peopleICanWake.count), peopleWhoCanWakeMe=\(peopleWhoCanWakeMe.count), blocked=\(blockedContacts.count), sent=\(pendingSent.count), received=\(pendingReceived.count)")
        } catch {
            self.error = error.localizedDescription
            print("[ContactsViewModel] Error fetching data: \(error)")
        }

        isLoading = false
    }
    
    private func generateColor(from email: String) -> String {
        let colors = ["FF6B6B", "4ECDC4", "45B7D1", "96CEB4", "FFEAA7", "DDA0DD", "98D8C8", "F7DC6F"]
        let hash = email.hash
        let index = abs(hash) % colors.count
        return colors[index]
    }

    func acceptInvite(_ invite: InviteItem) async {
        isLoading = true
        error = nil

        let inviteId = invite.id.uuidString
        print("[ContactsViewModel] Accepting invite id=\(inviteId) token=\(invite.inviteToken?.prefix(8) ?? "none")")

        do {
            let result = try await inviteService.acceptInvite(inviteId: inviteId, inviteToken: invite.inviteToken)
            if result.success {
                pendingReceived.removeAll { $0.id == invite.id }
                await fetchAllData()
                print("[ContactsViewModel] Accepted successfully")
            } else {
                self.error = result.error ?? "Failed to accept invite"
                if let code = result.debugCode { print("[ContactsViewModel] debugCode:", code) }
            }
        } catch {
            self.error = error.localizedDescription
            print("[ContactsViewModel] Error accepting invite: \(error)")
        }

        isLoading = false
    }

    func removeContact(_ contact: Contact, iAmGranter: Bool) async {
        isLoading = true
        error = nil
        
        // Validate UUID before proceeding
        guard let them = UUID(uuidString: contact.userId) else {
            self.error = "Invalid contact ID - cannot remove"
            isLoading = false
            return
        }
        
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let me = session.user.id
            let client = SupabaseManager.shared.client
            
            print("[ContactsViewModel] Removing contact: me=\(me), them=\(them), iAmGranter=\(iAmGranter)")
            
            if iAmGranter {
                try await client.from("wake_permissions")
                    .delete()
                    .eq("granter_id", value: me)
                    .eq("trustee_id", value: them)
                    .execute()
            } else {
                try await client.from("wake_permissions")
                    .delete()
                    .eq("trustee_id", value: me)
                    .eq("granter_id", value: them)
                    .execute()
            }
            
            print("[ContactsViewModel] Delete completed successfully")
            
            // Refresh data regardless of outcome
            await fetchAllData()
        } catch {
            self.error = "Could not remove contact: \(error.localizedDescription)"
            print("[ContactsViewModel] Remove contact error: \(error)")
        }
        isLoading = false
    }

    func cancelSentInvite(_ invite: InviteItem) async {
        isLoading = true
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let me = session.user.id
            struct CancelUpdate: Encodable { let status: String }
            try await SupabaseManager.shared.client.from("contact_invites")
                .update(CancelUpdate(status: "cancelled"))
                .eq("id", value: invite.id)
                .eq("inviter_id", value: me)
                .execute()
            await fetchAllData()
        } catch {
            self.error = "Could not cancel invite: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func blockContact(_ contact: Contact) async {
        isLoading = true
        error = nil

        guard let trusteeId = UUID(uuidString: contact.userId) else {
            self.error = "Invalid contact ID - cannot block"
            isLoading = false
            return
        }

        do {
            try await inviteService.updateWakePermissionStatus(trusteeId: trusteeId, status: "blocked")
            await fetchAllData()
        } catch {
            self.error = "Could not block contact: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func unblockContact(_ contact: Contact) async {
        isLoading = true
        error = nil

        guard let trusteeId = UUID(uuidString: contact.userId) else {
            self.error = "Invalid contact ID - cannot unblock"
            isLoading = false
            return
        }

        do {
            try await inviteService.updateWakePermissionStatus(trusteeId: trusteeId, status: "active")
            await fetchAllData()
        } catch {
            self.error = "Could not unblock contact: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func declineInvite(_ invite: InviteItem) async {
        isLoading = true
        error = nil

        let inviteId = invite.id.uuidString
        print("[ContactsViewModel] Declining invite id=\(inviteId)")

        do {
            let result = try await inviteService.declineInvite(inviteId: inviteId, inviteToken: invite.inviteToken)
            if result.success {
                await fetchAllData()
                print("[ContactsViewModel] Declined successfully")
            } else {
                self.error = result.error ?? "Failed to decline invite"
            }
        } catch {
            self.error = error.localizedDescription
            print("[ContactsViewModel] Error declining invite: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Nickname Edit Sheet
struct NicknameEditSheet: View {
    let contact: Contact
    let onSave: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var nickname: String

    init(contact: Contact, onSave: @escaping (String?) -> Void) {
        self.contact = contact
        self.onSave = onSave
        _nickname = State(initialValue: NicknameStore.get(for: contact.email) ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Nickname for \(contact.email)")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, DesignSystem.Spacing.lg)

                    TextField("Leave blank to use real name", text: $nickname)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .padding(DesignSystem.Spacing.sm + 2)
                        .background(Color.appSurface)
                        .cornerRadius(DesignSystem.Spacing.buttonRadius)
                        .foregroundColor(.textPrimary)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                }

                Text("Shown on contact cards instead of their account name.")
                    .font(.caption2)
                    .foregroundColor(.textTertiary)
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                Spacer()
            }
            .padding(.top, DesignSystem.Spacing.md)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Edit Nickname")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.primaryOrange)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = nickname.trimmingCharacters(in: .whitespaces)
                        onSave(trimmed.isEmpty ? nil : trimmed)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryOrange)
                }
            }
        }
    }
}

#Preview {
    ContactsView()
        .environmentObject(ContactsViewModel())
}
