import Foundation

// MARK: - Wake Request
/// Represents a wake request sent from one user to another.
struct WakeRequest: Identifiable, Codable {
    let id: String
    let senderId: String
    let receiverId: String
    let senderName: String
    let message: String?
    let urgency: Urgency
    let alarmSoundId: String
    let sentAt: Date
    let expiresAt: Date?
    let status: Status
    
    // MARK: - Urgency
    enum Urgency: String, Codable, CaseIterable {
        case low = "low"
        case normal = "normal"
        case high = "high"
        case critical = "critical"
        
        var displayName: String {
            switch self {
            case .low: return "Low"
            case .normal: return "Normal"
            case .high: return "High"
            case .critical: return "Critical"
            }
        }
    }
    
    // MARK: - Status
    enum Status: String, Codable {
        case pending = "pending"
        case delivered = "delivered"
        case confirmed = "confirmed"
        case snoozed = "snoozed"
        case expired = "expired"
        case cancelled = "cancelled"
    }
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        senderId: String,
        receiverId: String,
        senderName: String,
        message: String? = nil,
        urgency: Urgency = .normal,
        alarmSoundId: String = "classic",
        sentAt: Date = Date(),
        expiresAt: Date? = nil,
        status: Status = .pending
    ) {
        self.id = id
        self.senderId = senderId
        self.receiverId = receiverId
        self.senderName = senderName
        self.message = message
        self.urgency = urgency
        self.alarmSoundId = alarmSoundId
        self.sentAt = sentAt
        self.expiresAt = expiresAt
        self.status = status
    }
}

// MARK: - Mock Data
extension WakeRequest {
    /// Creates a mock wake request for previews and testing
    static func mock(
        senderName: String = "Alex",
        message: String? = "Time to wake up!",
        alarmSoundId: String = "classic"
    ) -> WakeRequest {
        WakeRequest(
            senderId: "mock-sender",
            receiverId: "mock-receiver",
            senderName: senderName,
            message: message,
            urgency: .normal,
            alarmSoundId: alarmSoundId
        )
    }
}