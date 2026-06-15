import Foundation

class WakeAlertManager: ObservableObject {
    static let shared = WakeAlertManager()
    
    @Published var activeWakeRequest: WakeRequest?
    @Published var isSendingWake: Bool = false

    private let apiClient = APIClient.shared
    
    private init() {}

    // MARK: - Send Wake Request
    func sendWake(to userId: String, message: String? = nil, urgency: WakeRequest.Urgency = .normal, alarmSoundId: String = "classic") async throws -> SendWakeResponse {
        isSendingWake = true
        defer { isSendingWake = false }

        var body: [String: Any] = [
            "targetUserId": userId,
            "urgency": urgency.rawValue,
            "alarmSoundId": alarmSoundId
        ]
        if let message = message, !message.isEmpty {
            body["message"] = message
        }

        return try await apiClient.request(
            endpoint: "/wake",
            method: "POST",
            body: body
        )
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
    func getWakeStatus(requestId: String) async throws -> WakeStatusResponse {
        return try await apiClient.request(
            endpoint: "/wake/\(requestId)/status",
            method: "POST",
            body: ["wakeRequestId": requestId]
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

// MARK: - Send Wake Response (matches backend send-wake edge function)
struct SendWakeResponse: Decodable {
    let success: Bool
    let requestId: String
    let traceId: String
    let status: String
    let devicesNotified: Int
    let alarmSoundId: String?
}

// MARK: - Wake Status Response (from get-wake-status)
struct WakeStatusResponse: Decodable {
    let success: Bool
    let wakeRequest: WakeStatusDetail?
    let error: String?
}

struct WakeStatusDetail: Decodable {
    let id: String
    let status: String
    let responseAction: String?
    let responseMessage: String?
    let respondedAt: String?
    let snoozeUntil: String?
    let alarmSoundId: String?
    let message: String?
    let urgency: String?
    let sentAt: String?
    let deliveredAt: String?
    let createdAt: String?
    let otherUserName: String?
    let otherUserEmail: String?
}