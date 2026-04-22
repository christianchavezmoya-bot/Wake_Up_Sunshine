import Foundation

class WakeAlertManager: ObservableObject {
    @Published var activeWakeRequest: WakeRequest?
    @Published var isSendingWake: Bool = false

    private let apiClient = APIClient.shared

    // MARK: - Send Wake Request
    func sendWake(to userId: String, message: String? = nil, urgency: WakeRequest.WakeUrgency = .normal) async throws -> WakeRequest {
        isSendingWake = true
        defer { isSendingWake = false }

        let body: [String: Any] = [
            "targetUserId": userId,
            "message": message ?? "",
            "urgency": urgency.rawValue
        ]

        let response: WakeRequest = try await apiClient.request(
            endpoint: "/wake",
            method: "POST",
            body: body
        )

        await MainActor.run {
            self.activeWakeRequest = response
        }

        return response
    }

    // MARK: - Confirm Wake
    func confirmWake(requestId: String) async throws {
        let _: EmptyResponse = try await apiClient.request(
            endpoint: "/wake/\(requestId)/confirm",
            method: "POST"
        )
    }

    // MARK: - Snooze Wake
    func snoozeWake(requestId: String) async throws {
        let _: EmptyResponse = try await apiClient.request(
            endpoint: "/wake/\(requestId)/snooze",
            method: "POST"
        )
    }

    // MARK: - Dismiss Wake
    func dismissWake(requestId: String) async throws {
        let _: EmptyResponse = try await apiClient.request(
            endpoint: "/wake/\(requestId)/dismiss",
            method: "POST"
        )
    }

    // MARK: - Get Wake Status
    func getWakeStatus(requestId: String) async throws -> WakeRequest {
        return try await apiClient.request(
            endpoint: "/wake/\(requestId)",
            method: "GET"
        )
    }

    // MARK: - Get Wake History
    func getWakeHistory(limit: Int = 50) async throws -> [WakeRequest] {
        return try await apiClient.request(
            endpoint: "/wake/history?limit=\(limit)",
            method: "GET"
        )
    }
}

// MARK: - Wake Request Response
struct WakeRequestResponse: Decodable {
    let requestId: String
    let status: String
    let createdAt: Date
}