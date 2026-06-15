import SwiftUI
import Network

// MARK: - Country Code Model
struct Country: Identifiable, Equatable {
    let id = UUID()
    let code: String
    let dialCode: String
    let name: String
    let flag: String

    static let supported: [Country] = [
        Country(code: "AU", dialCode: "+61", name: "Australia", flag: "🇦🇺"),
        Country(code: "CL", dialCode: "+56", name: "Chile", flag: "🇨🇱"),
        Country(code: "US", dialCode: "+1", name: "United States", flag: "🇺🇸"),
        Country(code: "CA", dialCode: "+1", name: "Canada", flag: "🇨🇦")
    ]

    static let `default` = Country.supported.first { $0.code == "AU" }!
}

// MARK: - Login View
struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var phoneNumber = ""
    @State private var selectedCountry = Country.default
    @State private var showCountryPicker = false
    @State private var isLoading = false
    @State private var showOTPVerification = false
    @State private var errorMessage: String?
    @State private var formattedPhone: String = ""

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

                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        // Country Selector Button
                        Button(action: { showCountryPicker = true }) {
                            HStack(spacing: 8) {
                                Text(selectedCountry.flag)
                                    .font(.title3)
                                Text(selectedCountry.dialCode)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .background(Color("Surface"))
                            .cornerRadius(12)
                        }

                        TextField("Phone number", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .font(.title3)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color("Surface"))
                            .cornerRadius(12)
                            .onChange(of: phoneNumber) { _, newValue in
                                // Only allow digits
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered != newValue {
                                    phoneNumber = filtered
                                }
                            }
                    }
                    .padding(.horizontal, 24)

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                    }
                }

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

                LegalDisclaimerView()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerView(selectedCountry: $selectedCountry)
        }
        .sheet(isPresented: $showOTPVerification) {
            OTPVerificationSheet(
                phoneNumber: formattedPhone,
                countryCode: selectedCountry,
                onVerified: {
                    // OTP verification already authenticated the user via verifyOTPAsync
                    // No additional sign-in call needed
                }
            )
        }
    }

    // MARK: - Validation & Formatting
    private func validateAndFormatPhone() -> (isValid: Bool, formatted: String, error: String?) {
        let digits = phoneNumber.filter { $0.isNumber }

        // Empty check
        guard !digits.isEmpty else {
            return (false, "", "Enter a phone number")
        }

        // Length validation based on country
        let minLength: Int
        let maxLength: Int

        switch selectedCountry.code {
        case "AU":
            // Australian mobile: 04XXXXXXXX or 4XXXXXXXX (8-9 digits after country code)
            minLength = 8
            maxLength = 9
        case "CL":
            // Chile mobile: 9XXXXXXXX (8 digits after country code, usually starts with 9)
            minLength = 8
            maxLength = 9
        case "US", "CA":
            // US/Canada: 10 digits
            minLength = 10
            maxLength = 10
        default:
            minLength = 8
            maxLength = 15
        }

        // Check length
        guard digits.count >= minLength else {
            return (false, "", "Phone number looks too short")
        }

        guard digits.count <= maxLength else {
            return (false, "", "Phone number is too long")
        }

        // Format to E.164
        let dialCode = selectedCountry.dialCode.dropFirst() // Remove the "+"
        var formatted: String

        switch selectedCountry.code {
        case "AU":
            // Remove leading 0 if present (0412... -> 412...)
            let nationalNumber = digits.hasPrefix("0") ? String(digits.dropFirst()) : digits
            formatted = "+\(dialCode)\(nationalNumber)"
        case "CL":
            // Chile numbers typically start with 9 for mobile
            let nationalNumber = digits.hasPrefix("0") ? String(digits.dropFirst()) : digits
            formatted = "+\(dialCode)\(nationalNumber)"
        case "US", "CA":
            // US/Canada - use as is
            formatted = "+\(dialCode)\(digits)"
        default:
            formatted = "+\(dialCode)\(digits)"
        }

        return (true, formatted, nil)
    }

    private func sendOTP() {
        // Clear previous error
        errorMessage = nil

        // Check internet connectivity
        if isOffline() {
            errorMessage = "Make sure your phone is connected to the internet before you sign in"
            return
        }

        // Validate phone number
        let validation = validateAndFormatPhone()

        guard validation.isValid else {
            errorMessage = validation.error
            return
        }

        formattedPhone = validation.formatted

        isLoading = true

        // Call Supabase OTP
        Task {
            do {
                try await authManager.sendOTP(phoneNumber: formattedPhone)
                await MainActor.run {
                    isLoading = false
                    showOTPVerification = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Country Picker View
struct CountryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCountry: Country

    var body: some View {
        NavigationStack {
            List(Country.supported) { country in
                Button(action: {
                    selectedCountry = country
                    dismiss()
                }) {
                    HStack {
                        Text(country.flag)
                            .font(.title2)
                        Text(country.name)
                            .font(.body)
                        Spacer()
                        Text(country.dialCode)
                            .font(.body)
                            .foregroundColor(.secondary)
                        if selectedCountry.id == country.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color("PrimaryOrange"))
                        }
                    }
                }
                .foregroundColor(.primary)
            }
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - OTP Verification Sheet
struct OTPVerificationSheet: View {
    let phoneNumber: String
    let countryCode: Country
    let onVerified: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var otpDigits: [String] = ["", "", "", "", "", ""]
    @FocusState private var focusedField: Int?
    @State private var countdown = 60
    @State private var isVerified = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color("Background").ignoresSafeArea()

                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Text("Verify Your Phone")
                            .font(.system(size: 24, weight: .bold))

                        Text("Enter the 6-digit code sent to\n\(phoneNumber)")
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
                                    // Only allow digits
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue {
                                        otpDigits[index] = filtered
                                    } else if newValue.count == 1 && index < 5 {
                                        focusedField = index + 1
                                    }
                                }
                        }
                    }

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
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
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else if isVerified {
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
                    .disabled(isLoading || isVerified)

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
            .onAppear { focusedField = 0; startCountdown() }
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

    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }

    private func verifyOTP() {
        let otp = otpDigits.joined()

        guard otp.count == 6 else {
            errorMessage = "Enter all 6 digits"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let success = try await authManager.verifyOTPAsync(phoneNumber: phoneNumber, otp: otp)
                await MainActor.run {
                    isLoading = false
                    if success {
                        isVerified = true
                    } else {
                        errorMessage = "Invalid code. Please try again."
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    @EnvironmentObject var authManager: AuthManager
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
