import Foundation
import Supabase

// MARK: - Invite Models
struct CreateInviteRequest: Encodable {
    let inviteeEmail: String
    let inviteeLabel: String?
    let message: String?
}

struct CreateInviteResponse: Decodable {
    let success: Bool
    let inviteId: String?
    let inviteeEmail: String?
    let inviteeLabel: String?
    let status: String?
    let message: String?
    let inviteToken: String?
    let inviteLink: String?
    let httpsLink: String?
    let qrPayload: String?
    let error: String?
}

struct AcceptInviteRequest: Encodable {
    let inviteId: String
    let inviteToken: String?
}

struct AcceptInviteResponse: Decodable {
    let success: Bool
    let status: String?
    let inviteId: String?
    let inviterId: String?
    let message: String?
    let error: String?
    let debugCode: String?
}

struct DeclineInviteRequest: Encodable {
    let inviteId: String
    let inviteToken: String?
}

struct DeclineInviteResponse: Decodable {
    let success: Bool
    let status: String?
    let inviteId: String?
    let message: String?
    let error: String?
}

struct SentInvite: Decodable, Identifiable {
    let id: UUID
    let invitee_email: String
    let status: String
    let created_at: String
    let expires_at: String
}

struct ReceivedInvite: Decodable, Identifiable {
    let id: UUID
    let inviter_id: UUID
    let inviter_name: String
    let invite_token: String
    let message: String?
    let created_at: String
}

struct GetInvitesResponse: Decodable {
    let success: Bool
    let sent: [SentInvite]?
    let received: [ReceivedInvite]?
    let error: String?
}

// MARK: - Contacts Response (New Standard Shape)
struct ContactItem: Decodable, Identifiable {
    let id: UUID
    let userId: UUID?
    let email: String
    let displayName: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case id, userId, email, displayName, status
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decodeIfPresent(UUID.self, forKey: .userId)
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? email
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "active"
    }
}

struct InviteItem: Decodable, Identifiable {
    let id: UUID
    let inviteeEmail: String?
    let inviteeLabel: String?
    let inviterEmail: String?
    let inviterName: String?
    let inviterId: UUID?
    let status: String
    let createdAt: String
    let inviteToken: String?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case inviteeEmail
        case inviteeLabel
        case inviterEmail
        case inviterName
        case inviterId
        case status
        case createdAt
        case inviteToken
        case message
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        inviteeEmail = try container.decodeIfPresent(String.self, forKey: .inviteeEmail)
        inviteeLabel = try container.decodeIfPresent(String.self, forKey: .inviteeLabel)
        inviterEmail = try container.decodeIfPresent(String.self, forKey: .inviterEmail)
        inviterName = try container.decodeIfPresent(String.self, forKey: .inviterName)
        inviterId = try container.decodeIfPresent(UUID.self, forKey: .inviterId)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "pending"
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ISO8601DateFormatter().string(from: Date())
        inviteToken = try container.decodeIfPresent(String.self, forKey: .inviteToken)
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}

struct ContactsResponse: Decodable {
    let success: Bool
    let peopleICanWake: [ContactItem]
    let peopleWhoCanWakeMe: [ContactItem]
    let blockedContacts: [ContactItem]
    let pendingInvitesSent: [InviteItem]
    let pendingInvitesReceived: [InviteItem]
    let error: String?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case peopleICanWake
        case peopleWhoCanWakeMe
        case blockedContacts
        case pendingInvitesSent
        case pendingInvitesReceived
        case error
        case message
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? false
        peopleICanWake = try container.decodeIfPresent([ContactItem].self, forKey: .peopleICanWake) ?? []
        peopleWhoCanWakeMe = try container.decodeIfPresent([ContactItem].self, forKey: .peopleWhoCanWakeMe) ?? []
        blockedContacts = try container.decodeIfPresent([ContactItem].self, forKey: .blockedContacts) ?? []
        pendingInvitesSent = try container.decodeIfPresent([InviteItem].self, forKey: .pendingInvitesSent) ?? []
        pendingInvitesReceived = try container.decodeIfPresent([InviteItem].self, forKey: .pendingInvitesReceived) ?? []
        error = try container.decodeIfPresent(String.self, forKey: .error)
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}

// MARK: - Invite Service
class InviteService: ObservableObject {
    static let shared = InviteService()
    
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastCreatedInvite: CreateInviteResponse?
    @Published var sentInvites: [SentInvite] = []
    @Published var receivedInvites: [ReceivedInvite] = []
    
    private init() {}
    
    // MARK: - Create Invite
    func createInvite(email: String, inviteeLabel: String? = nil, message: String? = nil) async throws -> CreateInviteResponse {
        await MainActor.run { isLoading = true; error = nil }

        let request = CreateInviteRequest(inviteeEmail: email, inviteeLabel: inviteeLabel, message: message)
        let session = try await SupabaseManager.shared.client.auth.session

        var urlRequest = URLRequest(url: URL(string: SupabaseManager.shared.createInviteFunctionURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(SupabaseManager.shared.supabaseAnonKey, forHTTPHeaderField: "apikey")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        print("[InviteService] Creating invite for: \(email)")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try throwIfHTTPError(response, data: data, context: "create-invite")

        let result = try JSONDecoder().decode(CreateInviteResponse.self, from: data)

        await MainActor.run {
            isLoading = false
            if let err = result.error { self.error = err } else { self.lastCreatedInvite = result }
        }

        print("[InviteService] Create invite result: success=\(result.success), token=\(result.inviteToken ?? "none")")
        return result
    }

    // MARK: - Accept Invite
    func acceptInvite(inviteId: String, inviteToken: String?) async throws -> AcceptInviteResponse {
        await MainActor.run { isLoading = true; error = nil }

        let request = AcceptInviteRequest(inviteId: inviteId, inviteToken: inviteToken)
        let session = try await SupabaseManager.shared.client.auth.session

        var urlRequest = URLRequest(url: URL(string: SupabaseManager.shared.acceptInviteFunctionURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(SupabaseManager.shared.supabaseAnonKey, forHTTPHeaderField: "apikey")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        print("[InviteService] Accepting invite id=\(inviteId) token=\(inviteToken?.prefix(8) ?? "none")...")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        if let raw = String(data: data, encoding: .utf8) { print("[InviteService] Accept response: \(raw)") }
        try throwIfHTTPError(response, data: data, context: "accept-invite")

        let result = try JSONDecoder().decode(AcceptInviteResponse.self, from: data)

        await MainActor.run {
            isLoading = false
            if let err = result.error { self.error = err }
        }
        return result
    }

    // MARK: - Decline Invite
    func declineInvite(inviteId: String, inviteToken: String?) async throws -> DeclineInviteResponse {
        await MainActor.run { isLoading = true; error = nil }

        let request = DeclineInviteRequest(inviteId: inviteId, inviteToken: inviteToken)
        let session = try await SupabaseManager.shared.client.auth.session

        var urlRequest = URLRequest(url: URL(string: SupabaseManager.shared.declineInviteFunctionURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(SupabaseManager.shared.supabaseAnonKey, forHTTPHeaderField: "apikey")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        print("[InviteService] Declining invite id=\(inviteId) token=\(inviteToken?.prefix(8) ?? "none")...")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        if let raw = String(data: data, encoding: .utf8) { print("[InviteService] Decline response: \(raw)") }
        try throwIfHTTPError(response, data: data, context: "decline-invite")

        let result = try JSONDecoder().decode(DeclineInviteResponse.self, from: data)

        await MainActor.run {
            isLoading = false
            if let err = result.error { self.error = err }
        }
        return result
    }

    // MARK: - Get Invites
    func fetchInvites(type: String = "all") async throws {
        await MainActor.run { isLoading = true }

        let session = try await SupabaseManager.shared.client.auth.session

        var urlComponents = URLComponents(string: SupabaseManager.shared.getInvitesFunctionURL)!
        urlComponents.queryItems = [URLQueryItem(name: "type", value: type)]

        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(SupabaseManager.shared.supabaseAnonKey, forHTTPHeaderField: "apikey")

        print("[InviteService] Fetching invites (type: \(type))")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try throwIfHTTPError(response, data: data, context: "get-invites")

        let result = try JSONDecoder().decode(GetInvitesResponse.self, from: data)

        await MainActor.run {
            isLoading = false
            sentInvites = result.sent ?? []
            receivedInvites = result.received ?? []
        }
    }

    // MARK: - Fetch Contacts (New Standard Shape)
    func fetchContacts() async throws -> ContactsResponse {
        await MainActor.run { isLoading = true }

        let session = try await SupabaseManager.shared.client.auth.session

        var urlRequest = URLRequest(url: URL(string: SupabaseManager.shared.getContactsFunctionURL)!)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(SupabaseManager.shared.supabaseAnonKey, forHTTPHeaderField: "apikey")

        print("[InviteService] Fetching contacts...")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try throwIfHTTPError(response, data: data, context: "get-contacts")

        if let rawString = String(data: data, encoding: .utf8) {
            print("[InviteService] Raw response: \(rawString)")
        }

        let result = try JSONDecoder().decode(ContactsResponse.self, from: data)

        await MainActor.run {
            isLoading = false
            if let err = result.error { self.error = err }
        }

        print("[InviteService] Contacts fetched: peopleICanWake=\(result.peopleICanWake.count), peopleWhoCanWakeMe=\(result.peopleWhoCanWakeMe.count), sent=\(result.pendingInvitesSent.count), received=\(result.pendingInvitesReceived.count)")
        return result
    }

    func updateWakePermissionStatus(trusteeId: UUID, status: String) async throws {
        let session = try await SupabaseManager.shared.client.auth.session
        let myId = session.user.id

        struct StatusUpdate: Encodable { let status: String }

        try await SupabaseManager.shared.client
            .from("wake_permissions")
            .update(StatusUpdate(status: status))
            .eq("granter_id", value: myId)
            .eq("trustee_id", value: trusteeId)
            .execute()
    }

    // Throws an InviteError if the HTTP response status is outside 200–299.
    private func throwIfHTTPError(_ response: URLResponse, data: Data, context: String) throws {
        guard let http = response as? HTTPURLResponse else { throw InviteError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            print("[InviteService] \(context) error \(http.statusCode): \(body)")
            throw InviteError.serverError(http.statusCode, body)
        }
    }
}

// MARK: - Errors
enum InviteError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case networkError(Error)
    case serverError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to manage invites"
        case .invalidResponse:
            return "Invalid server response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let body):
            return "Server error \(code): \(body)"
        }
    }
}
