import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Add Contact Sheet (Updated)
struct AddContactSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var inviteService = InviteService.shared
    
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var showEmailInvite = false
    @State private var showQRCode = false
    @State private var showShareSheet = false
    @State private var showSuccessMessage = false
    
    var onInviteSent: (() -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.md) {
                    // Tab Picker
                    Picker("Invite Method", selection: $selectedTab) {
                        Text("Email").tag(0)
                        Text("Share Link").tag(1)
                        Text("QR Code").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    // Content based on selected tab
                    switch selectedTab {
                    case 0:
                        EmailInviteView(
                            onSuccess: { showSuccessMessage = true }
                        )
                    case 1:
                        ShareLinkView(
                            onShare: { showShareSheet = true }
                        )
                    case 2:
                        QRCodeInviteView()
                    default:
                        EmptyView()
                    }
                    
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
            .alert("Invite Created", isPresented: $showSuccessMessage) {
                Button("OK") { dismiss() }
            } message: {
                Text("The person will see it when they log in with this email.")
            }
        }
    }
}

// MARK: - Email Invite View
struct EmailInviteView: View {
    @StateObject private var inviteService = InviteService.shared
    @State private var email = ""
    @State private var nickname = ""
    @State private var message = ""
    @State private var showError = false
    @State private var errorMessage = ""
    let onSuccess: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Email Input
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Email Address")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.textSecondary)

                TextField("Enter email address", text: $email)
                    .textFieldStyle(.plain)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(DesignSystem.Spacing.sm + 2)
                    .background(Color.appSurface)
                    .cornerRadius(DesignSystem.Spacing.buttonRadius)
                    .foregroundColor(.textPrimary)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            // Nickname
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Nickname (Optional)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.textSecondary)

                TextField("e.g. Mom, Best Friend…", text: $nickname)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .padding(DesignSystem.Spacing.sm + 2)
                    .background(Color.appSurface)
                    .cornerRadius(DesignSystem.Spacing.buttonRadius)
                    .foregroundColor(.textPrimary)

                Text("Shown on contact cards instead of their account name.")
                    .font(.caption2)
                    .foregroundColor(.textTertiary)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            // Optional Message
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Message (Optional)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.textSecondary)
                
                TextField("Add a personal message...", text: $message)
                    .textFieldStyle(.plain)
                    .padding(DesignSystem.Spacing.sm + 2)
                    .background(Color.appSurface)
                    .cornerRadius(DesignSystem.Spacing.buttonRadius)
                    .foregroundColor(.textPrimary)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            // Send Button
            Button(action: sendInvite) {
                HStack {
                    if inviteService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "person.badge.plus")
                        Text("Create Invite")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.Spacing.md)
                .background(
                    LinearGradient(
                        colors: [DesignSystem.Colors.primaryOrange, DesignSystem.Colors.primaryOrangeLight],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(DesignSystem.Spacing.buttonRadius)
            }
            .disabled(email.isEmpty || inviteService.isLoading)
            .opacity(email.isEmpty ? 0.5 : 1.0)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            // Info Text
            Text("The recipient will need to accept your invitation before you can wake them.")
                .font(.caption)
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func sendInvite() {
        Task {
            do {
                print("[InviteContactView] Sending invite to: \(email)")
                let trimmed = nickname.trimmingCharacters(in: .whitespaces)
                let result = try await inviteService.createInvite(
                    email: email,
                    inviteeLabel: trimmed.isEmpty ? nil : trimmed,
                    message: message.isEmpty ? nil : message
                )
                
                if result.success {
                    print("[InviteContactView] Invite sent successfully")
                    NicknameStore.set(trimmed.isEmpty ? nil : trimmed, for: email)
                    onSuccess()
                } else if let error = result.error {
                    await MainActor.run {
                        errorMessage = error
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Share Link View
struct ShareLinkView: View {
    @StateObject private var inviteService = InviteService.shared
    @State private var nickname = ""
    @State private var inviteLink: String?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    let onShare: () -> Void
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Nickname")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.textSecondary)

                TextField("e.g. Mom, Best Friend…", text: $nickname)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .padding(DesignSystem.Spacing.sm + 2)
                    .background(Color.appSurface)
                    .cornerRadius(DesignSystem.Spacing.buttonRadius)
                    .foregroundColor(.textPrimary)

                Text("Required so you can recognize this share-link invite later.")
                    .font(.caption2)
                    .foregroundColor(.textTertiary)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            if isLoading {
                ProgressView("Creating invite link...")
                    .padding()
            } else if let link = inviteLink {
                // Show the invite link
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Your Invite Link")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.textSecondary)
                    
                    HStack {
                        Text(link)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.textPrimary)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        Button(action: { UIPasteboard.general.string = link }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(DesignSystem.Colors.primaryOrange)
                        }
                    }
                    .padding(DesignSystem.Spacing.sm + 2)
                    .background(Color.appSurface)
                    .cornerRadius(DesignSystem.Spacing.buttonRadius)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                
                // Share Button
                Button(action: shareLink) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Link")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.primaryOrange)
                    .cornerRadius(DesignSystem.Spacing.buttonRadius)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            } else {
                // Create link button
                Button(action: createLink) {
                    HStack {
                        Image(systemName: "link")
                        Text("Create Invite Link")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.primaryOrange)
                    .cornerRadius(DesignSystem.Spacing.buttonRadius)
                }
                .disabled(nickname.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(nickname.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            
            Text("Share this link with your contact. They'll need to install Wake Up Sunshine and accept your invitation.")
                .font(.caption)
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)
        }
        .sheet(isPresented: $showShareSheet) {
            if !shareItems.isEmpty {
                ShareSheet(activityItems: shareItems)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func createLink() {
        Task {
            await MainActor.run { isLoading = true }
            
            do {
                let trimmed = nickname.trimmingCharacters(in: .whitespaces)
                let result = try await inviteService.createInvite(email: "pending@share.link", inviteeLabel: trimmed)
                
                await MainActor.run {
                    isLoading = false
                    if result.success, let link = result.httpsLink ?? result.inviteLink {
                        inviteLink = link
                    } else if let error = result.error {
                        errorMessage = error
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func shareLink() {
        guard let link = inviteLink else { return }
        shareItems = [
            "Join me on Wake Up Sunshine! I want to be able to wake you up when it matters. \(link)"
        ]
        showShareSheet = true
    }
}

// MARK: - QR Code Invite View
struct QRCodeInviteView: View {
    @StateObject private var inviteService = InviteService.shared
    @State private var nickname = ""
    @State private var qrCode: Image?
    @State private var inviteLink: String?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Nickname")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.textSecondary)

                TextField("e.g. Mom, Best Friend…", text: $nickname)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .padding(DesignSystem.Spacing.sm + 2)
                    .background(Color.appSurface)
                    .cornerRadius(DesignSystem.Spacing.buttonRadius)
                    .foregroundColor(.textPrimary)

                Text("Required so you can recognize this QR invite later.")
                    .font(.caption2)
                    .foregroundColor(.textTertiary)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            if isLoading {
                ProgressView("Generating QR Code...")
                    .padding()
            } else if let qrImage = qrCode {
                // QR Code Display
                VStack(spacing: DesignSystem.Spacing.md) {
                    qrImage
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .background(Color.white)
                        .cornerRadius(DesignSystem.Spacing.cardRadius)
                    
                    if let link = inviteLink {
                        HStack {
                            Text(link)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.textSecondary)
                                .lineLimit(1)
                            
                            Button(action: { UIPasteboard.general.string = link }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(DesignSystem.Colors.primaryOrange)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
                    
                    // Copy Link Button
                    Button(action: { if let link = inviteLink { UIPasteboard.general.string = link }}) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy Link")
                        }
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.primaryOrange)
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .background(Color.appCard)
                .cornerRadius(DesignSystem.Spacing.cardRadius)
                .shadow(color: DesignSystem.Shadows.cardShadow.color, radius: DesignSystem.Shadows.cardShadow.radius)
            } else {
                // Generate button
                Button(action: generateQRCode) {
                    HStack {
                        Image(systemName: "qrcode")
                        Text("Generate QR Code")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.primaryOrange)
                    .cornerRadius(DesignSystem.Spacing.buttonRadius)
                }
                .disabled(nickname.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(nickname.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            
            Text("Let your contact scan this QR code with their phone to accept your invitation.")
                .font(.caption)
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func generateQRCode() {
        Task {
            await MainActor.run { isLoading = true }
            
            do {
                let trimmed = nickname.trimmingCharacters(in: .whitespaces)
                let result = try await inviteService.createInvite(email: "pending@qr.code", inviteeLabel: trimmed)
                
                await MainActor.run {
                    isLoading = false
                    
                    if result.success, let link = result.qrPayload ?? result.httpsLink ?? result.inviteLink {
                        inviteLink = link
                        qrCode = generateQRCodeImage(from: link)
                    } else if let error = result.error {
                        errorMessage = error
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func generateQRCodeImage(from string: String) -> Image? {
        let data = string.data(using: .utf8)
        filter.setValue(data, forKey: "inputMessage")
        
        guard let outputImage = filter.outputImage else { return nil }
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        
        return Image(uiImage: UIImage(cgImage: cgImage))
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview
#Preview {
    AddContactSheet()
}
