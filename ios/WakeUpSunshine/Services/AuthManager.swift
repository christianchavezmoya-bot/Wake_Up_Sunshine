import Foundation
import Supabase

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var requiresBiometricAuth: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var authMethod: AuthMethod = .email

    private let supabase = SupabaseManager.shared.client
    private let supabaseManager = SupabaseManager.shared

    enum AuthMethod {
        case email
        case phone
    }

    // MARK: - Email Authentication (Primary)

    /// Sign up with email and password
    func signUp(email: String, password: String, displayName: String) async throws {
        isLoading = true
        error = nil

        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["display_name": .string(displayName.trimmingCharacters(in: .whitespacesAndNewlines))]
            )

            self.isLoading = false
            let user = response.user
            self.currentUser = makeCurrentUser(from: user)
            // Note: User may need to confirm email before being fully authenticated
            if response.session != nil {
                self.isAuthenticated = true
                self.saveSession()
            }
        } catch {
            self.isLoading = false
            self.error = error.localizedDescription
            throw error
        }
    }

    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        isLoading = true
        error = nil

        do {
            let response = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            self.isLoading = false
            let user = response.user
            self.currentUser = makeCurrentUser(from: user)
            self.isAuthenticated = true
            self.saveSession()
        } catch {
            self.isLoading = false
            self.error = error.localizedDescription
            throw error
        }
    }

    /// Sign out
    func signOut() async {
        isLoading = true
        do {
            try await supabase.auth.signOut()
            self.isLoading = false
            self.isAuthenticated = false
            self.currentUser = nil
            self.clearSession()
        } catch {
            self.isLoading = false
            self.error = error.localizedDescription
        }
    }

    /// Check for an existing Supabase session. If biometric auth is enabled the user must
    /// authenticate with Face ID / Touch ID before isAuthenticated is set to true.
    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            let user = session.user
            self.currentUser = makeCurrentUser(from: user)
            if BiometricManager.shared.isEnabled && BiometricManager.shared.isBiometricAvailable {
                self.requiresBiometricAuth = true
                // isAuthenticated stays false until the lock screen is passed
            } else {
                self.isAuthenticated = true
            }
        } catch {
            // No valid session — show onboarding
        }
    }

    /// Called by BiometricLockView after the user passes Face ID / Touch ID.
    func confirmBiometricAuth() {
        requiresBiometricAuth = false
        isAuthenticated = true
    }

    // MARK: - Phone Authentication (Optional)

    /// Send OTP to phone number via Supabase
    func sendOTP(phoneNumber: String) async throws {
        isLoading = true
        error = nil

        do {
            try await supabase.auth.signInWithOTP(
                phone: phoneNumber
            )
            self.isLoading = false
        } catch {
            self.isLoading = false
            self.error = error.localizedDescription
            throw error
        }
    }

    /// Verify OTP code
    func verifyOTPAsync(phoneNumber: String, otp: String) async throws -> Bool {
        isLoading = true
        error = nil

        do {
            let session = try await supabase.auth.verifyOTP(
                phone: phoneNumber,
                token: otp,
                type: .sms
            )

            self.isLoading = false
            let user = session.user
            self.currentUser = User(
                id: user.id.uuidString,
                phoneNumber: phoneNumber,
                displayName: "User"
            )
            self.isAuthenticated = true
            self.saveSession()
            return true
        } catch {
            self.isLoading = false
            self.error = error.localizedDescription
            throw error
        }
    }

    // MARK: - Email Verification

    /// Resend email verification to the given address
    func resendVerification(email: String) async throws {
        isLoading = true
        error = nil

        do {
            try await supabase.auth.resend(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                type: .signup
            )
            self.isLoading = false
        } catch {
            self.isLoading = false
            self.error = error.localizedDescription
            throw error
        }
    }

    // MARK: - Password Reset

    /// Send password reset email with deep link back to the app
    func resetPassword(email: String) async throws {
        isLoading = true
        error = nil

        do {
            try await supabase.auth.resetPasswordForEmail(
                email.trimmingCharacters(in: .whitespacesAndNewlines),
                redirectTo: URL(string: "wakeupsunshine://reset-password")
            )
            self.isLoading = false
        } catch {
            self.isLoading = false
            self.error = error.localizedDescription
            throw error
        }
    }

    // MARK: - Account Deletion

    /// Delete the current user's account
    func deleteAccount() async throws {
        isLoading = true
        error = nil

        do {
            guard let userId = currentUser?.id else {
                isLoading = false
                throw AuthError.noAuthenticatedUser
            }

            try await deleteAccountOnServer(userId: userId)

            // Sign out and clear local session
            try await supabase.auth.signOut()
            self.isLoading = false
            self.isAuthenticated = false
            self.currentUser = nil
            self.clearSession()
        } catch {
            self.isLoading = false
            self.error = error.localizedDescription
            throw error
        }
    }

    // MARK: - Session Management
    private func saveSession() {
        if let user = currentUser {
            UserDefaults.standard.set(user.id, forKey: "userId")
            UserDefaults.standard.set(user.phoneNumber, forKey: "phoneNumber")
        }
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "phoneNumber")
    }

    private func makeCurrentUser(from user: Supabase.User) -> User {
        User(
            id: user.id.uuidString,
            phoneNumber: "",
            displayName: preferredDisplayName(from: user)
        )
    }

    private func preferredDisplayName(from user: Supabase.User) -> String {
        if let metadataValue = user.userMetadata["display_name"]?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !metadataValue.isEmpty {
            return metadataValue
        }

        if let email = user.email, !email.isEmpty {
            let localPart = email.split(separator: "@").first.map(String.init) ?? email
            return localPart
        }

        return "User"
    }

    private func deleteAccountOnServer(userId: String) async throws {
        let endpoint = "\(supabaseManager.supabaseURLString)/functions/v1/delete-account"

        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }

        let accessToken = try await supabase.auth.session.accessToken
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseManager.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["user_id": userId])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let errorMessage = parseDeleteAccountError(from: data)
            throw DeleteAccountError.server(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }

    private func parseDeleteAccountError(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if let response = try? JSONDecoder().decode(DeleteAccountResponse.self, from: data),
           let error = response.error?.trimmingCharacters(in: .whitespacesAndNewlines),
           !error.isEmpty {
            return error
        }

        let body = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return body?.isEmpty == false ? body : nil
    }

    func checkExistingSession() -> Bool {
        if let _ = UserDefaults.standard.string(forKey: "userId") {
            // Restore session
            isAuthenticated = true
            return true
        }
        return false
    }
}

// MARK: - API Client
class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let supabaseManager = SupabaseManager.shared

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Generic Request
    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        headers: [String: String] = [:]
    ) async throws -> T {
        // Map endpoints to Supabase Edge Functions
        let functionURL = mapEndpointToFunction(endpoint: endpoint, method: method)
        
        print("[APIClient] Request URL: \(functionURL)")
        
        guard let url = URL(string: functionURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseManager.supabaseAnonKey, forHTTPHeaderField: "apikey")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            print("[APIClient] Request body: \(body)")
        }

        // Add auth token if available
        if let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        
        // Log response
        if let httpResponse = response as? HTTPURLResponse {
            print("[APIClient] Response status: \(httpResponse.statusCode)")
        }
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("[APIClient] Response body: \(responseString)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[APIClient] Error response: \(errorBody)")
            throw APIError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Map REST endpoints to Supabase Edge Functions
    private func mapEndpointToFunction(endpoint: String, method: String) -> String {
        let baseURL = supabaseManager.supabaseURLString
        let functionsBase = "\(baseURL)/functions/v1"
        
        // Map /wake -> send-wake
        if endpoint == "/wake" && method == "POST" {
            return "\(functionsBase)/send-wake"
        }
        
        // Map /wake/{id}/confirm -> wake-response
        if endpoint.contains("/wake/") && endpoint.contains("/confirm") {
            return "\(functionsBase)/wake-response"
        }
        
        // Map /wake/{id}/snooze -> wake-response
        if endpoint.contains("/wake/") && endpoint.contains("/snooze") {
            return "\(functionsBase)/wake-response"
        }
        
        // Map /wake/{id}/dismiss -> wake-response
        if endpoint.contains("/wake/") && endpoint.contains("/dismiss") {
            return "\(functionsBase)/wake-response"
        }
        
        // Map /wake/{id}/status -> get-wake-status
        if endpoint.hasPrefix("/wake/") && endpoint.hasSuffix("/status") {
            return "\(functionsBase)/get-wake-status"
        }

        // Map /wake/history -> get-history
        if endpoint == "/wake/history" || endpoint.contains("/wake/history") {
            return "\(functionsBase)/get-history"
        }

        // Map /wake/{id} (GET/POST) -> wake-response
        if endpoint.hasPrefix("/wake/") && !endpoint.contains("/history") {
            return "\(functionsBase)/wake-response"
        }
        
        // Default: treat as edge function name
        return "\(functionsBase)\(endpoint.hasPrefix("/") ? endpoint : "/\(endpoint)")"
    }

    private func getAuthToken() -> String? {
        // Get token from Supabase session
        return SupabaseManager.shared.client.auth.currentSession?.accessToken
    }
}

// MARK: - API Errors
enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}

// MARK: - API Response Models
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: String?
}

struct EmptyResponse: Decodable {}

private struct DeleteAccountResponse: Decodable {
    let success: Bool?
    let message: String?
    let error: String?
}

private enum DeleteAccountError: LocalizedError {
    case server(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .server(let statusCode, _):
            if statusCode == 401 {
                return "Session expired. Please sign in again and retry."
            }
            return "Could not delete account. Please try again."
        }
    }
}

// MARK: - Auth Errors
enum AuthError: Error, LocalizedError {
    case noAuthenticatedUser
    case emailNotVerified

    var errorDescription: String? {
        switch self {
        case .noAuthenticatedUser:
            return "No authenticated user found. Please sign in again."
        case .emailNotVerified:
            return "Please verify your email before continuing."
        }
    }
}
