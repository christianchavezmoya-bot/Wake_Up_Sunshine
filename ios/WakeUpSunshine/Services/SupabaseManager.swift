import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    // Supabase credentials - Replace with your actual values
    private let supabaseURL = URL(string: "https://jehouatjcfcxjjuowzbd.supabase.co")!
    public let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImplaG91YXRqY2ZjeGpqdW93emJkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY4Mjk4MzEsImV4cCI6MjA5MjQwNTgzMX0.5nHtSx44b8U99WjaZUsRIIcUn4mHHdUMPFrM2Us3WjE"
    
    // Public accessor for supabase URL base string
    public var supabaseURLString: String {
        return supabaseURL.absoluteString
    }
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
    
    // MARK: - Edge Function URLs
    var sendWakeFunctionURL: String {
        return "\(supabaseURL.absoluteString)/functions/v1/send-wake"
    }
    
    var wakeResponseFunctionURL: String {
        return "\(supabaseURL.absoluteString)/functions/v1/wake-response"
    }
    
    var getContactsFunctionURL: String {
        return "\(supabaseURL.absoluteString)/functions/v1/get-contacts"
    }
    
    var getHistoryFunctionURL: String {
        return "\(supabaseURL.absoluteString)/functions/v1/get-history"
    }
    
    var createInviteFunctionURL: String {
        return "\(supabaseURL.absoluteString)/functions/v1/create-invite"
    }
    
    var acceptInviteFunctionURL: String {
        return "\(supabaseURL.absoluteString)/functions/v1/accept-invite"
    }
    
    var declineInviteFunctionURL: String {
        return "\(supabaseURL.absoluteString)/functions/v1/decline-invite"
    }
    
    var getInvitesFunctionURL: String {
        return "\(supabaseURL.absoluteString)/functions/v1/get-invites"
    }
}

// MARK: - Database Models
struct UserProfile: Codable, Identifiable {
    let id: UUID
    let phone_number: String
    let display_name: String?
    let avatar_color: String?
    let created_at: String
    
    var displayName: String {
        return display_name ?? "User"
    }
}

struct UserDeviceRecord: Codable, Identifiable {
    let id: UUID
    let user_id: UUID
    let device_token: String
    let device_type: String
    let is_primary: Bool
    let critical_alerts_enabled: Bool
    let last_active_at: String
}

struct WakePermissionRecord: Codable, Identifiable {
    let id: UUID
    let granter_id: UUID
    let trustee_id: UUID
    let status: String
    let schedule_start: String?
    let schedule_end: String?
    let created_at: String
}

// Note: WakeRequest is defined in WakeUpSunshineApp.swift
