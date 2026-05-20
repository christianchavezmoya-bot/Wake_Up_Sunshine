import SwiftUI

struct PaywallView: View {
    @StateObject private var unlockManager = UnlockManager.shared
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(hex: "FF6B35"), Color(hex: "F7931E")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Hero section
                        VStack(spacing: 16) {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                                .shadow(radius: 10)
                            
                            Text("Wake Me Up")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Lifetime Access")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.top, 40)
                        
                        // Features
                        VStack(spacing: 20) {
                            FeatureRow(
                                icon: "bell.badge.fill",
                                title: "Unlimited Wake Calls",
                                description: "Wake up your friends and family anytime"
                            )
                            
                            FeatureRow(
                                icon: "person.2.fill",
                                title: "Unlimited Contacts",
                                description: "Add as many contacts as you want"
                            )
                            
                            FeatureRow(
                                icon: "gift.fill",
                                title: "2 Free Invites",
                                description: "Share full access with 2 friends for free"
                            )
                            
                            FeatureRow(
                                icon: "infinity",
                                title: "Lifetime Access",
                                description: "One-time purchase, forever yours"
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(20)
                        .padding(.horizontal, 20)
                        
                        // Purchase button
                        VStack(spacing: 16) {
                            Button(action: {
                                Task {
                                    await purchase()
                                }
                            }) {
                                HStack {
                                    if isPurchasing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Unlock Lifetime")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white)
                                .foregroundColor(Color(hex: "FF6B35"))
                                .cornerRadius(16)
                            }
                            .disabled(isPurchasing)
                            
                            if !unlockManager.productPrice.isEmpty {
                                Text("One-time purchase • \(unlockManager.productPrice)")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Text("Restore Purchase")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .onTapGesture {
                                    Task {
                                        await restorePurchase()
                                    }
                                }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func purchase() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let success = try await unlockManager.purchase()
            if success {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func restorePurchase() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        // Check current status which should reflect restored purchases
        await unlockManager.checkUnlockStatus()
        
        if unlockManager.isUnlocked {
            dismiss()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
    }
}

#Preview {
    PaywallView()
}