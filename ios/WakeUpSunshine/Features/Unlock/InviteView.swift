import SwiftUI
import CoreImage.CIFilterBuiltins

struct InviteView: View {
    @StateObject private var unlockManager = UnlockManager.shared
    @State private var invite: UnlockInvite?
    @State private var isCreatingInvite = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var copiedToClipboard = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "FF6B35"))
                        
                        Text("Share Wake Me Up")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Give your friends free lifetime access")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Invite credits
                    HStack(spacing: 24) {
                        VStack {
                            Text("\(unlockManager.inviteCredits)")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(Color(hex: "FF6B35"))
                            
                            Text("Invites Left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 1, height: 40)
                        
                        VStack {
                            Text(unlockManager.isInvited ? "Yes" : "No")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Text("Invited User")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    // Check if user can create invites
                    if unlockManager.isInvited {
                        // Invited users cannot create invites
                        VStack(spacing: 16) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                            
                            Text("You were invited!")
                                .font(.headline)
                            
                            Text("Invited users receive full access but cannot create new invites. Upgrade to a paid account to share with more friends.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    } else if unlockManager.inviteCredits > 0 || invite != nil {
                        // Show invite creation or existing invite
                        if let invite = invite {
                            // Show QR code and share options
                            VStack(spacing: 24) {
                                // QR Code
                                VStack {
                                    Text("Your Invite Code")
                                        .font(.headline)
                                    
                                    Text(invite.code ?? "")
                                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                                        .foregroundColor(Color(hex: "FF6B35"))
                                        .padding(.vertical, 8)
                                    
                                    if let qrImage = generateQRCode(from: invite.inviteLink ?? "") {
                                        Image(uiImage: qrImage)
                                            .interpolation(.none)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 200, height: 200)
                                            .background(Color.white)
                                            .cornerRadius(12)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(16)
                                
                                // Invite link
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Invite Link")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text(invite.inviteLink ?? "")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                
                                // Action buttons
                                VStack(spacing: 12) {
                                    Button(action: { shareInvite(invite) }) {
                                        HStack {
                                            Image(systemName: "square.and.arrow.up")
                                            Text("Share Invite")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(Color(hex: "FF6B35"))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                    }
                                    
                                    HStack(spacing: 12) {
                                        Button(action: { copyLink(invite) }) {
                                            HStack {
                                                Image(systemName: "doc.on.doc")
                                                Text("Copy Link")
                                            }
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 50)
                                            .background(Color(.systemGray5))
                                            .foregroundColor(.primary)
                                            .cornerRadius(12)
                                        }
                                        
                                        Button(action: { 
                                            // Create another invite
                                            Task {
                                                await createInvite()
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: "plus")
                                                Text("New Code")
                                            }
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 50)
                                            .background(Color(.systemGray5))
                                            .foregroundColor(.primary)
                                            .cornerRadius(12)
                                        }
                                        .disabled(unlockManager.inviteCredits == 0)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            // Show create invite button
                            Button(action: {
                                Task {
                                    await createInvite()
                                }
                            }) {
                                VStack(spacing: 12) {
                                    if isCreatingInvite {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "qrcode")
                                            .font(.title)
                                        
                                        Text("Create Invite Code")
                                            .font(.headline)
                                        
                                        Text("Generate a unique code for your friend")
                                            .font(.caption)
                                            .opacity(0.8)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "FF6B35"), Color(hex: "F7931E")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(16)
                            }
                            .disabled(isCreatingInvite)
                            .padding(.horizontal)
                        }
                    } else {
                        // No credits
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            
                            Text("No Invites Remaining")
                                .font(.headline)
                            
                            Text("You've used all your invite credits. Thank you for sharing Wake Me Up!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    // Info section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How It Works")
                            .font(.headline)
                        
                        HStack(alignment: .top, spacing: 12) {
                            Text("1.")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "FF6B35"))
                            
                            Text("Share your unique invite code or link")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(alignment: .top, spacing: 12) {
                            Text("2.")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "FF6B35"))
                            
                            Text("Your friend opens the link and downloads the app")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(alignment: .top, spacing: 12) {
                            Text("3.")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "FF6B35"))
                            
                            Text("They get full lifetime access for free!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Copied!", isPresented: $copiedToClipboard) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Invite link copied to clipboard")
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityView(activityItems: shareItems)
            }
        }
    }
    
    // MARK: - Create Invite
    private func createInvite() async {
        isCreatingInvite = true
        defer { isCreatingInvite = false }
        
        do {
            let newInvite = try await unlockManager.createInvite()
            if newInvite.success {
                self.invite = newInvite
            } else {
                errorMessage = newInvite.error ?? "Failed to create invite"
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    // MARK: - Share Invite
    private func shareInvite(_ invite: UnlockInvite) {
        guard let link = invite.inviteLink, let code = invite.code else { return }
        
        shareItems = [
            "Join me on Wake Me Up! Use my invite code: \(code)\n\n\(link)"
        ]
        showShareSheet = true
    }
    
    // MARK: - Copy Link
    private func copyLink(_ invite: UnlockInvite) {
        guard let link = invite.inviteLink else { return }
        
        UIPasteboard.general.string = link
        copiedToClipboard = true
    }
    
    // MARK: - Generate QR Code
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        
        return nil
    }
}

// MARK: - Activity View for Share Sheet
struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    InviteView()
}