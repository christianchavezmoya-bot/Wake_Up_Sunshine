import SwiftUI

// MARK: - Email Authentication View
struct EmailAuthView: View {
    let onSuccess: () -> Void
    let onBack: () -> Void

    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var displayName = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var showForgotPassword = false
    @State private var forgotPasswordEmail = ""
    @State private var isResettingPassword = false
    @State private var passwordResetSent = false
    @State private var isResendingVerification = false
    @State private var verificationResent = false
    @State private var signupPendingVerification = false
    @State private var forgotPasswordError: String?

    var body: some View {
        Group {
            if signupPendingVerification {
                verificationPendingView
            } else {
                formView
            }
        }
    }

    // MARK: - Verification Pending Screen
    private var verificationPendingView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: DesignSystem.Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.primaryOrange.opacity(0.12))
                        .frame(width: 100, height: 100)
                    Image(systemName: "envelope.badge.checkmark.fill")
                        .font(.system(size: 44))
                        .foregroundColor(DesignSystem.Colors.primaryOrange)
                }

                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Check Your Email")
                        .font(.title2.bold())
                        .foregroundColor(.textPrimary)
                    Text("We sent a confirmation link to")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                    Text(email)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.textPrimary)
                    Text("Click the link in the email to verify your account, then come back here to sign in.")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                }
            }

            Spacer()

            VStack(spacing: DesignSystem.Spacing.md) {
                Button(action: handleResendVerification) {
                    HStack(spacing: 6) {
                        if isResendingVerification {
                            ProgressView().tint(.white).scaleEffect(0.85)
                        } else if verificationResent {
                            Image(systemName: "checkmark")
                        }
                        Text(verificationResent ? "Email Sent!" : "Resend Verification Email")
                    }
                    .primaryButtonStyle()
                }
                .disabled(isResendingVerification || verificationResent)
                .padding(.horizontal, DesignSystem.Spacing.lg)

                Button(action: {
                    signupPendingVerification = false
                    isSignUp = false
                    errorMessage = nil
                    verificationResent = false
                    confirmPassword = ""
                    displayName = ""
                }) {
                    Text("Back to Sign In")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryOrange)
                }
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryOrange)
                }
            }
        }
    }

    // MARK: - Form View
    private var formView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Header
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(isSignUp ? "Create Account" : "Welcome Back")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.textPrimary)

                Text(isSignUp ? "Sign up with your email to get started" : "Sign in with your email")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Form
            VStack(spacing: DesignSystem.Spacing.md) {
                if isSignUp {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Name or Nickname")
                            .font(.caption)
                            .foregroundColor(.textSecondary)

                        TextField("How should we show you?", text: $displayName)
                            .textContentType(.nickname)
                            .autocapitalization(.words)
                            .autocorrectionDisabled()
                            .font(.body)
                            .foregroundColor(.textPrimary)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.sm + 2)
                            .background(Color.appSurface)
                            .cornerRadius(DesignSystem.Spacing.buttonRadius)
                    }
                }

                // Email field
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Email")
                        .font(.caption)
                        .foregroundColor(.textSecondary)

                    TextField("Enter your email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .font(.body)
                        .foregroundColor(.textPrimary)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm + 2)
                        .background(Color.appSurface)
                        .cornerRadius(DesignSystem.Spacing.buttonRadius)
                }

                // Password field
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Password")
                        .font(.caption)
                        .foregroundColor(.textSecondary)

                    HStack {
                        if showPassword {
                            TextField("Enter password", text: $password)
                                .textContentType(.password)
                                .font(.body)
                                .foregroundColor(.textPrimary)
                        } else {
                            SecureField("Enter password", text: $password)
                                .textContentType(.password)
                                .font(.body)
                                .foregroundColor(.textPrimary)
                        }

                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm + 2)
                    .background(Color.appSurface)
                    .cornerRadius(DesignSystem.Spacing.buttonRadius)
                }

                // Forgot Password (sign in only)
                if !isSignUp {
                    HStack {
                        Spacer()
                        Button("Forgot Password?") {
                            forgotPasswordEmail = email
                            passwordResetSent = false
                            errorMessage = nil
                            showForgotPassword = true
                        }
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.primaryOrange)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }

                // Confirm password (sign up only)
                if isSignUp {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Confirm Password")
                            .font(.caption)
                            .foregroundColor(.textSecondary)

                        HStack {
                            if showConfirmPassword {
                                TextField("Confirm password", text: $confirmPassword)
                                    .textContentType(.newPassword)
                                    .font(.body)
                                    .foregroundColor(.textPrimary)
                            } else {
                                SecureField("Confirm password", text: $confirmPassword)
                                    .textContentType(.newPassword)
                                    .font(.body)
                                    .foregroundColor(.textPrimary)
                            }

                            Button(action: { showConfirmPassword.toggle() }) {
                                Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm + 2)
                        .background(Color.appSurface)
                        .cornerRadius(DesignSystem.Spacing.buttonRadius)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                // "Account already exists" → Switch to sign in
                if isSignUp && (error.localizedCaseInsensitiveContains("already registered") || error.localizedCaseInsensitiveContains("already exists") || error.localizedCaseInsensitiveContains("User already")) {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                        Button("Sign In") {
                            isSignUp = false
                            errorMessage = nil
                            confirmPassword = ""
                            displayName = ""
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.primaryOrange)
                    }
                }

                // Wrong password on sign in → Forgot password link
                if !isSignUp && (error.localizedCaseInsensitiveContains("Invalid login credentials") || error.localizedCaseInsensitiveContains("invalid credentials") || error.localizedCaseInsensitiveContains("wrong password") || error.localizedCaseInsensitiveContains("incorrect")) {
                    Button("Forgot your password?") {
                        forgotPasswordEmail = email
                        passwordResetSent = false
                        errorMessage = nil
                        showForgotPassword = true
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryOrange)
                }

                // Resend verification button (shown after sign-in when email needs confirmation)
                if error.localizedCaseInsensitiveContains("confirm") || error.localizedCaseInsensitiveContains("verification") || error.localizedCaseInsensitiveContains("verify") {
                    Button(action: handleResendVerification) {
                        HStack(spacing: 4) {
                            if isResendingVerification {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else if verificationResent {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text(verificationResent ? "Verification email sent!" : "Resend Verification Email")
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.primaryOrange)
                    }
                    .disabled(isResendingVerification || verificationResent)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
            }

            Spacer()

            // Action buttons
            VStack(spacing: DesignSystem.Spacing.md) {
                // Primary button
                Button(action: handleAuth) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(isSignUp ? "Create Account" : "Sign In")
                        }
                }
                .primaryButtonStyle()
                }
                .disabled(email.isEmpty || password.isEmpty || (isSignUp && (confirmPassword.isEmpty || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)) || isLoading)
                .opacity(email.isEmpty || password.isEmpty || (isSignUp && (confirmPassword.isEmpty || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)) ? 0.6 : 1)
                .padding(.horizontal, DesignSystem.Spacing.lg)

                // Toggle sign up / sign in
                Button(action: {
                    isSignUp.toggle()
                    errorMessage = nil
                    confirmPassword = ""
                    displayName = ""
                }) {
                    HStack(spacing: 4) {
                        Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                            .foregroundColor(.textSecondary)
                        Text(isSignUp ? "Sign In" : "Sign Up")
                            .foregroundColor(DesignSystem.Colors.primaryOrange)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
            }
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryOrange)
                }
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            NavigationStack {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 40))
                            .foregroundColor(DesignSystem.Colors.primaryOrange)
                        Text("Reset Password")
                            .font(.title2.bold())
                            .foregroundColor(.textPrimary)
                        Text("Enter your email and we'll send you a link to reset your password.")
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .onAppear { forgotPasswordError = nil }

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Email")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                        TextField("Enter your email", text: $forgotPasswordEmail)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .font(.body)
                            .foregroundColor(.textPrimary)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.sm + 2)
                            .background(Color.appSurface)
                            .cornerRadius(DesignSystem.Spacing.buttonRadius)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                    if passwordResetSent {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(DesignSystem.Colors.success)
                            Text("Password reset email sent! Check your inbox.")
                                .font(.subheadline)
                                .foregroundColor(DesignSystem.Colors.success)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }

                    if let error = forgotPasswordError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                    }

                    Spacer()

                    Button(action: handlePasswordReset) {
                        HStack {
                            if isResettingPassword {
                                ProgressView().tint(.white)
                            } else {
                                Text("Send Reset Link")
                            }
                        }
                        .primaryButtonStyle()
                    }
                    .disabled(forgotPasswordEmail.isEmpty || isResettingPassword)
                    .opacity(forgotPasswordEmail.isEmpty ? 0.6 : 1)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                }
                .navigationTitle("Reset Password")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showForgotPassword = false }
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Password Reset
    private func handlePasswordReset() {
        guard !forgotPasswordEmail.isEmpty, forgotPasswordEmail.contains("@") else {
            forgotPasswordError = "Please enter a valid email address"
            return
        }

        isResettingPassword = true
        forgotPasswordError = nil

        Task {
            do {
                try await authManager.resetPassword(email: forgotPasswordEmail)
                await MainActor.run {
                    isResettingPassword = false
                    passwordResetSent = true
                }
            } catch {
                await MainActor.run {
                    isResettingPassword = false
                    forgotPasswordError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Resend Verification
    private func handleResendVerification() {
        guard !email.isEmpty, email.contains("@") else { return }
        isResendingVerification = true

        Task {
            do {
                try await authManager.resendVerification(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
                await MainActor.run {
                    isResendingVerification = false
                    verificationResent = true
                }
            } catch {
                await MainActor.run {
                    isResendingVerification = false
                    errorMessage = "Failed to resend verification: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Validation
    private func validate() -> String? {
        guard !email.isEmpty else {
            return "Email is required"
        }

        guard email.contains("@") && email.contains(".") else {
            return "Please enter a valid email address"
        }

        if isSignUp && displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Name or nickname is required"
        }

        guard !password.isEmpty else {
            return "Password is required"
        }

        guard password.count >= 6 else {
            return "Password must be at least 6 characters"
        }

        if isSignUp && password != confirmPassword {
            return "Passwords do not match"
        }

        return nil
    }

    // MARK: - Authentication
    private func handleAuth() {
        errorMessage = nil

        if isOffline() {
            errorMessage = "Make sure your phone is connected to the internet before you login or sign up"
            return
        }

        if let error = validate() {
            errorMessage = error
            return
        }

        isLoading = true

        Task {
            do {
                if isSignUp {
                    try await authManager.signUp(
                        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                        password: password,
                        displayName: displayName
                    )
                } else {
                    try await authManager.signIn(
                        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                        password: password
                    )
                }

                await MainActor.run {
                    isLoading = false
                    if authManager.isAuthenticated {
                        onSuccess()
                    } else if isSignUp {
                        signupPendingVerification = true
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
}

#Preview {
    NavigationStack {
        EmailAuthView(onSuccess: {}, onBack: {})
            .environmentObject(AuthManager())
    }
}
