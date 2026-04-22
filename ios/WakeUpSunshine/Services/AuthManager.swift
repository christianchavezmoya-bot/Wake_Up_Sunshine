import Foundation
import Supabase

class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client
    private let supabaseManager = SupabaseManager.shared

    // MARK: - Phone Authentication
    func signIn(phoneNumber: String) {
        isLoading = true
        error = nil

        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isLoading = false
            self.currentUser = User(
                id: UUID().uuidString,
                phoneNumber: phoneNumber,
                displayName: "User"
            )
            self.isAuthenticated = true
            self.saveSession()
        }
    }

    func verifyOTP(phoneNumber: String, otp: String, completion: @escaping (Bool) -> Void) {
        isLoading = true

        // Simulate OTP verification
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isLoading = false
            self.currentUser = User(
                id: UUID().uuidString,
                phoneNumber: phoneNumber,
                displayName: "User"
            )
            self.isAuthenticated = true
            self.saveSession()
            completion(true)
        }
    }

    func signOut() {
        isAuthenticated = false
        currentUser = nil
        clearSession()
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

    private let baseURL = "https://api.wakeupsunshine.app/v1"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Generic Request
    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        // Add auth token if available
        if let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(T.self, from: data)
    }

    private func getAuthToken() -> String? {
        return UserDefaults.standard.string(forKey: "authToken")
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