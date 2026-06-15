import Foundation
import StoreKit
import SwiftUI

// MARK: - Unlock Status Model
struct UnlockStatus: Codable {
    let exists: Bool
    let hasPaid: Bool
    let isInvited: Bool
    let inviteCredits: Int
    let userId: String?
    let platform: String?
    
    enum CodingKeys: String, CodingKey {
        case exists
        case hasPaid = "has_paid"
        case isInvited = "is_invited"
        case inviteCredits = "invite_credits"
        case userId = "user_id"
        case platform
    }
}

// MARK: - Invite Model
struct UnlockInvite: Codable {
    let success: Bool
    let code: String?
    let inviteId: String?
    let inviteLink: String?
    let deepLink: String?
    let remainingCredits: Int?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success, code, error
        case inviteId = "invite_id"
        case inviteLink = "invite_link"
        case deepLink = "deep_link"
        case remainingCredits = "remaining_credits"
    }
}

// MARK: - Redeem Result
struct RedeemResult: Codable {
    let success: Bool
    let message: String?
    let error: String?
    let status: String?
    let userId: String?
    
    enum CodingKeys: String, CodingKey {
        case success, message, error, status
        case userId = "user_id"
    }
}

// MARK: - Unlock Manager
@MainActor
class UnlockManager: ObservableObject {
    static let shared = UnlockManager()
    
    @Published var isUnlocked: Bool = false
    @Published var isInvited: Bool = false
    @Published var inviteCredits: Int = 0
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var userId: String?
    
    // StoreKit
    private var product: Product?
    @Published var productPrice: String = ""
    
    // Device ID
    var deviceId: String {
        #if os(iOS)
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        return UUID().uuidString
        #endif
    }
    
    private init() {
        Task {
            await loadProduct()
            await checkUnlockStatus()
        }
    }
    
    // MARK: - API URLs
    private var baseURL: String {
        return SupabaseManager.shared.supabaseURLString
    }
    
    private var validatePurchaseURL: String {
        return "\(baseURL)/functions/v1/unlock-purchase-validate"
    }
    
    private var createInviteURL: String {
        return "\(baseURL)/functions/v1/unlock-invite-create"
    }
    
    private var validateInviteURL: String {
        return "\(baseURL)/functions/v1/unlock-invite-validate"
    }
    
    private var redeemInviteURL: String {
        return "\(baseURL)/functions/v1/unlock-invite-redeem"
    }
    
    private var getStatusURL: String {
        return "\(baseURL)/functions/v1/unlock-get-status"
    }
    
    // MARK: - Load Product
    func loadProduct() async {
        do {
            let products = try await Product.products(for: ["wake_unlock_lifetime"])
            if let product = products.first {
                self.product = product
                self.productPrice = product.displayPrice
            }
        } catch {
            print("[UnlockManager] Failed to load product: \(error)")
        }
    }
    
    // MARK: - Check Unlock Status
    func checkUnlockStatus() async {
        isLoading = true
        
        do {
            var request = URLRequest(url: URL(string: "\(getStatusURL)?device_id=\(deviceId)")!)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(SupabaseManager.shared.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(SupabaseManager.shared.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("[UnlockManager] Status response: \(jsonString)")
            }
            
            let response = try JSONDecoder().decode(UnlockStatus.self, from: data)
            
            self.isUnlocked = response.hasPaid
            self.isInvited = response.isInvited
            self.inviteCredits = response.inviteCredits
            self.userId = response.userId
            self.isLoading = false
            
        } catch {
            print("[UnlockManager] Failed to check status: \(error)")
            self.isLoading = false
        }
    }
    
    // MARK: - Purchase
    func purchase() async throws -> Bool {
        guard let product = product else {
            throw UnlockError.productNotFound
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // Verify the transaction
            switch verification {
            case .unverified(_, _):
                throw UnlockError.verificationFailed
            case .verified(let transaction):
                // Validate with backend
                let success = try await validatePurchase(transaction: transaction)
                if success {
                    await transaction.finish()
                }
                return success
            }
            
        case .userCancelled:
            throw UnlockError.purchaseCancelled
            
        case .pending:
            throw UnlockError.purchasePending
            
        @unknown default:
            throw UnlockError.unknown
        }
    }
    
    private func validatePurchase(transaction: StoreKit.Transaction) async throws -> Bool {
        // Get the receipt data
        let receiptData = try getReceiptData()
        
        var request = URLRequest(url: URL(string: validatePurchaseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseManager.shared.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseManager.shared.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "device_id": deviceId,
            "platform": "ios",
            "receipt_token": receiptData,
            "product_id": transaction.productID,
            "transaction_id": transaction.originalID
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[UnlockManager] Validate response: \(jsonString)")
        }
        
        let response = try JSONDecoder().decode(ValidateResponse.self, from: data)
        
        if response.success {
            self.isUnlocked = true
            self.inviteCredits = response.inviteCredits ?? 2
            return true
        } else {
            throw UnlockError.validationFailed(response.error ?? "Unknown error")
        }
    }
    
    private func getReceiptData() throws -> String {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            throw UnlockError.receiptNotFound
        }
        
        let receiptData = try Data(contentsOf: receiptURL)
        return receiptData.base64EncodedString()
    }
    
    // MARK: - Create Invite
    func createInvite() async throws -> UnlockInvite {
        isLoading = true
        defer { isLoading = false }
        
        var request = URLRequest(url: URL(string: createInviteURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseManager.shared.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseManager.shared.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = ["device_id": deviceId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[UnlockManager] Create invite response: \(jsonString)")
        }
        
        let response = try JSONDecoder().decode(UnlockInvite.self, from: data)
        
        if response.success {
            self.inviteCredits = response.remainingCredits ?? 0
        }
        
        return response
    }
    
    // MARK: - Redeem Invite
    func redeemInvite(code: String) async throws -> RedeemResult {
        isLoading = true
        defer { isLoading = false }
        
        var request = URLRequest(url: URL(string: redeemInviteURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseManager.shared.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseManager.shared.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "code": code.uppercased(),
            "device_id": deviceId,
            "platform": "ios"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[UnlockManager] Redeem response: \(jsonString)")
        }
        
        let response = try JSONDecoder().decode(RedeemResult.self, from: data)
        
        if response.success {
            self.isUnlocked = true
            self.isInvited = true
        }
        
        return response
    }
    
    // MARK: - Validate Invite Code
    func validateInviteCode(_ code: String) async throws -> Bool {
        var request = URLRequest(url: URL(string: "\(validateInviteURL)?code=\(code.uppercased())")!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseManager.shared.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseManager.shared.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[UnlockManager] Validate invite response: \(jsonString)")
        }
        
        let response = try JSONDecoder().decode(ValidateInviteResponse.self, from: data)
        return response.valid
    }
}

// MARK: - Response Models
struct ValidateResponse: Codable {
    let success: Bool
    let error: String?
    let inviteCredits: Int?
    
    enum CodingKeys: String, CodingKey {
        case success, error
        case inviteCredits = "invite_credits"
    }
}

struct ValidateInviteResponse: Codable {
    let valid: Bool
    let error: String?
    let status: String?
}

// MARK: - Errors
enum UnlockError: LocalizedError {
    case productNotFound
    case purchaseCancelled
    case purchasePending
    case verificationFailed
    case receiptNotFound
    case validationFailed(String)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found. Please try again later."
        case .purchaseCancelled:
            return "Purchase was cancelled."
        case .purchasePending:
            return "Purchase is pending approval."
        case .verificationFailed:
            return "Transaction verification failed."
        case .receiptNotFound:
            return "App Store receipt not found."
        case .validationFailed(let message):
            return message
        case .unknown:
            return "An unknown error occurred."
        }
    }
}