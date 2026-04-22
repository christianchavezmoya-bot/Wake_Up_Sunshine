import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var phoneNumber = ""
    @State private var isLoading = false
    @State private var showOTPVerification = false

    var body: some View {
        ZStack {
            Color("Background").ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color("PrimaryOrange"), Color("PrimaryOrangeLight")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)

                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }

                    Text("Wake Up Sunshine")
                        .font(.title)
                        .fontWeight(.bold)
                }

                VStack(spacing: 12) {
                    Text("Welcome Back")
                        .font(.system(size: 24, weight: .bold))

                    Text("Enter your phone number to sign in")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    Text("+1")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color("Surface"))
                        .cornerRadius(12)

                    TextField("(555) 123-4567", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .font(.title3)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color("Surface"))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)

                Button(action: sendOTP) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Continue")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(phoneNumber.isEmpty ? Color.gray : Color("PrimaryOrange"))
                    .cornerRadius(16)
                }
                .disabled(phoneNumber.isEmpty || isLoading)
                .padding(.horizontal, 24)

                Spacer()

                Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showOTPVerification) {
            OTPVerificationSheet(phoneNumber: phoneNumber) {
                authManager.signIn(phoneNumber: phoneNumber)
            }
        }
    }

    private func sendOTP() {
        isLoading = true
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            showOTPVerification = true
        }
    }
}

struct OTPVerificationSheet: View {
    let phoneNumber: String
    let onVerified: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var otpDigits: [String] = ["", "", "", "", "", ""]
    @FocusState private var focusedField: Int?
    @State private var countdown = 60
    @State private var isVerified = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color("Background").ignoresSafeArea()

                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Text("Verify Your Phone")
                            .font(.system(size: 24, weight: .bold))

                        Text("Enter the 6-digit code sent to\n+1 \(phoneNumber)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: 12) {
                        ForEach(0..<6, id: \.self) { index in
                            TextField("", text: $otpDigits[index])
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .font(.title)
                                .fontWeight(.semibold)
                                .frame(width: 48, height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(otpDigits[index].isEmpty ? Color.gray.opacity(0.3) : Color("PrimaryOrange"), lineWidth: 2)
                                )
                                .focused($focusedField, equals: index)
                                .onChange(of: otpDigits[index]) { _, newValue in
                                    if newValue.count == 1 && index < 5 {
                                        focusedField = index + 1
                                    }
                                }
                        }
                    }

                    HStack {
                        Text("Resend code in ")
                            .foregroundColor(.secondary)
                        Text("\(countdown)s")
                            .foregroundColor(Color("PrimaryOrange"))
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)

                    Button(action: verifyOTP) {
                        HStack {
                            if isVerified {
                                Image(systemName: "checkmark.circle.fill")
                            } else {
                                Text("Verify")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color("PrimaryOrange"))
                        .cornerRadius(16)
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear { focusedField = 0 }
            .onChange(of: isVerified) { _, newValue in
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                        onVerified()
                    }
                }
            }
        }
    }

    private func verifyOTP() {
        // Simulate verification
        withAnimation {
            isVerified = true
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}