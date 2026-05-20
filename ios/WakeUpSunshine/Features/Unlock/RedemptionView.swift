import SwiftUI

struct RedemptionView: View {
    let inviteCode: String
    @StateObject private var unlockManager = UnlockManager.shared
    @State private var isRedeeming = true
    @State private var success = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 32) {
            if isRedeeming {
                // Loading state
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "FF6B35")))
                    .scaleEffect(2)
                
                Text("Redeeming your invite...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            } else if success {
                // Success state
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("Welcome!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("You now have full lifetime access to Wake Me Up. Enjoy waking up your friends!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button("Get Started") {
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(hex: "FF6B35"))
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal, 40)
            } else {
                // Error state
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                
                Text("Oops!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                VStack(spacing: 12) {
                    Button("Try Again") {
                        Task {
                            await redeemInvite()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: "FF6B35"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    
                    Button("Close") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }
        }
        .padding()
        .task {
            await redeemInvite()
        }
    }
    
    private func redeemInvite() async {
        isRedeeming = true
        defer { isRedeeming = false }
        
        do {
            let result = try await unlockManager.redeemInvite(code: inviteCode)
            
            if result.success {
                success = true
                errorMessage = ""
            } else {
                success = false
                errorMessage = result.error ?? "Something went wrong. Please try again."
            }
        } catch {
            success = false
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    RedemptionView(inviteCode: "ABC12345")
}