import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = HomeViewModel()
    @State private var showAddContact = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                                Text("Wake Up Sunshine")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.textPrimary)

                                Text(greeting())
                                    .font(.subheadline)
                                    .foregroundColor(.textSecondary)
                            }

                            Spacer()

                            Button(action: {}) {
                                Circle()
                                    .fill(DesignSystem.Colors.primaryOrange)
                                    .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)
                                    .overlay(
                                        Text("A")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.top, DesignSystem.Spacing.md)

                        // Section: People I Can Wake
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text("People I Can Wake")
                                .font(.headline)
                                .foregroundColor(.textPrimary)
                                .padding(.horizontal, DesignSystem.Spacing.lg)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.md) {
                                ForEach(viewModel.contacts) { contact in
                                    ContactCard(contact: contact) {
                                        viewModel.sendWakeRequest(to: contact)
                                    }
                                    .transition(.scale.combined(with: .opacity).animation(.springStandard))
                                }

                                // Add Contact Card
                                Button(action: { showAddContact = true }) {
                                    AddContactCard()
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        }

                        // Empty State
                        if viewModel.contacts.isEmpty {
                            EmptyContactsView()
                                .transition(.opacity.animation(.springGentle))
                            }
                    }
                    .padding(.bottom, DesignSystem.Spacing.xxl)
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

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color(hex: contact.avatarColor))
                    .frame(width: DesignSystem.TouchTargets.large, height: DesignSystem.TouchTargets.large)
                    .overlay(
                        Text(contact.displayName.prefix(1).uppercased())
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )

                if contact.isOnline {
                    Circle()
                        .fill(DesignSystem.Colors.success)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.appSurface, lineWidth: 2)
                        )
                        .offset(x: 4, y: -4)
                }
            }

            Text(contact.displayName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
                .lineLimit(1)

            Text(contact.isOnline ? "Online" : "Offline")
                .font(.caption)
                .foregroundColor(contact.isOnline ? DesignSystem.Colors.success : .textSecondary)

            // Wake Button - Sized to minimum touch target
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                onWake()
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignSystem.Colors.primaryOrange, DesignSystem.Colors.primaryOrangeLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)
                        .shadow(color: DesignSystem.Colors.primaryOrange.opacity(0.4), radius: 8, y: 4)

                    Image(systemName: "bell.fill")
                        .font(.title2)
                        .foregroundColor(.white)

                    // Pulse animation with spring
                    Circle()
                        .stroke(DesignSystem.Colors.primaryOrange, lineWidth: 2)
                        .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)
                        .modifier(PulseRingAnimation())
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.appCard)
        .cornerRadius(DesignSystem.Spacing.cardRadius)
        .shadow(
            color: DesignSystem.Shadows.cardShadow.color,
            radius: DesignSystem.Shadows.cardShadow.radius,
            x: DesignSystem.Shadows.cardShadow.x,
            y: DesignSystem.Shadows.cardShadow.y
        )
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.springBounce, value: configuration.isPressed)
    }
}

// MARK: - Add Contact Card
struct AddContactCard: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primaryOrange.opacity(0.1))
                    .frame(width: DesignSystem.TouchTargets.large, height: DesignSystem.TouchTargets.large)

                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.primaryOrange)
            }

            Text("Add Contact")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)

            Text("Invite friends & family")
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(Color.appCard)
        .cornerRadius(DesignSystem.Spacing.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardRadius)
                .strokeBorder(Color.appDivider, style: StrokeStyle(lineWidth: 1, dash: [6]))
        )
    }
}

// MARK: - Pulse Ring Animation with Spring
struct PulseRingAnimation: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.4 : 1.0)
            .opacity(isAnimating ? 0 : 0.8)
            .animation(
                .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

// MARK: - Empty Contacts View with Illustration
struct EmptyContactsView: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Custom Sun/Moon illustration
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DesignSystem.Colors.primaryOrange.opacity(0.2), DesignSystem.Colors.primaryOrangeLight.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "sun.max.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignSystem.Colors.primaryOrange, DesignSystem.Colors.primaryOrangeLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.bottom, DesignSystem.Spacing.xs)

            Text("No Trusted Contacts Yet")
                .font(.headline)
                .foregroundColor(.textPrimary)

            Text("Add people who can wake you up when it matters most.")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)
        }
        .padding(.vertical, DesignSystem.Spacing.xxl)
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
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: DesignSystem.Spacing.md) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.textSecondary)

                        TextField("Search by phone number or name", text: $searchText)
                            .textFieldStyle(.plain)
                            .foregroundColor(.textPrimary)
                    }
                    .padding(DesignSystem.Spacing.sm + 2)
                    .background(Color.appSurface)
                    .cornerRadius(DesignSystem.Spacing.buttonRadius)
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                    // Invite Options
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        InviteOptionButton(
                            icon: "message.fill",
                            iconColor: DesignSystem.Colors.primaryOrange,
                            title: "Invite via SMS",
                            subtitle: "Send an invite link to a phone number"
                        )

                        InviteOptionButton(
                            icon: "qrcode.viewfinder",
                            iconColor: DesignSystem.Colors.textSecondary,
                            title: "Share QR Code",
                            subtitle: "Let them scan your code to connect"
                        )
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                    Spacer()
                }
                .padding(.top, DesignSystem.Spacing.md)
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.primaryOrange)
                }
            }
        }
    }
}

// MARK: - Invite Option Button
struct InviteOptionButton: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        Button(action: {}) {
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.1))
                        .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)

                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(.textTertiary)
            }
            .padding(DesignSystem.Spacing.md)
            .background(Color.appCard)
            .cornerRadius(DesignSystem.Spacing.buttonRadius)
        }
        .buttonStyle(ScaleButtonStyle())
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
