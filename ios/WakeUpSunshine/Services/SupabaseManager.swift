import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    // Supabase credentials - Replace with your actual values
    private let supabaseURL = "https://jehouatjcfcxjjuowzbd.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImplaG91YXRqY2ZjeGpqdW93emJkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY4Mjk4MzEsImV4cCI6MjA5MjQwNTgzMX0.5nHtSx44b8U99WjaZUsRIIcUn4mHHdUMPFrM2Us3WjE"
    
    private init() {
        self.client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseAnonKey)
    }
    
    // MARK: - Edge Function URLs
    var sendWakeFunctionURL: String {
        return "\(supabaseURL)/functions/v1/send-wake"
    }
    
    var wakeResponseFunctionURL: String {
        return "\(supabaseURL)/functions/v1/wake-response"
    }
    
    var getContactsFunctionURL: String {
        return "\(supabaseURL)/functions/v1/get-contacts"
    }
    
    var getHistoryFunctionURL: String {
        return "\(supabaseURL)/functions/v1/get-history"
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

struct UserDevice: Codable, Identifiable {
    let id: UUID
    let user_id: UUID
    let device_token: String
    let device_type: String
    let is_primary: Bool
    let critical_alerts_enabled: Bool
    let last_active_at: String
}

struct WakePermission: Codable, Identifiable {
    let id: UUID
    let granter_id: UUID
    let trustee_id: UUID
    let status: String
    let schedule_start: String?
    let schedule_end: String?
    let created_at: String
}

struct WakeRequest: Codable, Identifiable {
    let id: UUID
    let sender_id: UUID
    let receiver_id: UUID
    let message: String?
    let urgency: String
    let status: String
    let sent_at: String
    let delivered_at: String?
    let dismissed_at: String?
    let confirmed_at: String?
}
