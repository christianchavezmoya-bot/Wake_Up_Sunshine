import Foundation
import SwiftUI

// MARK: - Debug Event
struct DebugEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let traceId: String?
    let eventType: String
    let message: String
    let metadata: [String: String]
    let platform: String
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        traceId: String? = nil,
        eventType: String,
        message: String,
        metadata: [String: String] = [:],
        platform: String = "ios"
    ) {
        self.id = id
        self.timestamp = timestamp
        self.traceId = traceId
        self.eventType = eventType
        self.message = message
        self.metadata = metadata
        self.platform = platform
    }
}

// MARK: - Debug Logger
class DebugLogger: ObservableObject {
    static let shared = DebugLogger()
    
    @Published var events: [DebugEvent] = []
    @Published var lastWakeTraceId: String?
    @Published var lastWakeResponse: [String: Any]?
    @Published var lastNotificationPayload: [String: Any]?
    @Published var lastAlarmTriggeredAt: Date?
    
    // Current trace ID for ongoing operations
    var currentTraceId: String?
    
    private let maxEvents = 100
    private let eventsKey = "debug_events"
    private let lastWakeTraceIdKey = "last_wake_trace_id"
    
    private init() {
        loadEvents()
    }
    
    // MARK: - Logging Methods
    
    func log(
        eventType: String,
        message: String,
        traceId: String? = nil,
        metadata: [String: String] = [:]
    ) {
        let event = DebugEvent(
            traceId: traceId ?? currentTraceId,
            eventType: eventType,
            message: message,
            metadata: metadata
        )
        
        DispatchQueue.mainAsyncSafe {
            self.events.insert(event, at: 0)
            
            // Keep only the last 100 events
            if self.events.count > self.maxEvents {
                self.events = Array(self.events.prefix(self.maxEvents))
            }
            
            self.saveEvents()
        }
        
        // Also print to console
        let metadataStr = metadata.isEmpty ? "" : " | \(metadata)"
        print("[DebugLogger] [\(eventType)] \(message)\(metadataStr)")
    }
    
    // MARK: - Specific Log Methods
    
    func logAppLaunch() {
        log(eventType: "app_launch", message: "App launched")
    }
    
    func logAuthRestored(userId: String, email: String?) {
        log(eventType: "auth_restored", message: "Auth session restored", metadata: [
            "userId": userId,
            "email": email ?? "unknown"
        ])
    }
    
    func logContactsRefreshStart() {
        log(eventType: "contacts_refresh_start", message: "Refreshing contacts")
    }
    
    func logContactsRefreshComplete(
        peopleICanWake: Int,
        peopleWhoCanWakeMe: Int,
        pendingSent: Int,
        pendingReceived: Int
    ) {
        log(eventType: "contacts_refresh_complete", message: "Contacts loaded", metadata: [
            "peopleICanWake": "\(peopleICanWake)",
            "peopleWhoCanWakeMe": "\(peopleWhoCanWakeMe)",
            "pendingSent": "\(pendingSent)",
            "pendingReceived": "\(pendingReceived)"
        ])
    }
    
    func logHomeDataLoaded(peopleICanWake: Int) {
        log(eventType: "home_data_loaded", message: "Home data loaded", metadata: [
            "peopleICanWake": "\(peopleICanWake)"
        ])
    }
    
    func logWakeButtonTapped(targetUserId: String, targetName: String) {
        currentTraceId = UUID().uuidString
        log(eventType: "wake_button_tapped", message: "Wake button tapped", traceId: currentTraceId, metadata: [
            "targetUserId": targetUserId,
            "targetName": targetName
        ])
    }
    
    func logWakeRequestSent(traceId: String, targetUserId: String, alarmSoundId: String) {
        lastWakeTraceId = traceId
        UserDefaults.standard.set(traceId, forKey: lastWakeTraceIdKey)
        
        log(eventType: "wake_request_sent", message: "Wake request sent to backend", traceId: traceId, metadata: [
            "targetUserId": targetUserId,
            "alarmSoundId": alarmSoundId
        ])
    }
    
    func logWakeResponse(_ response: [String: Any]) {
        lastWakeResponse = response
        
        let traceId = response["traceId"] as? String
        let success = response["success"] as? Bool ?? false
        let requestId = response["requestId"] as? String ?? "unknown"
        let devicesNotified = response["devicesNotified"] as? Int ?? 0
        
        log(eventType: "wake_response", message: "Wake response received", traceId: traceId, metadata: [
            "success": "\(success)",
            "requestId": requestId,
            "devicesNotified": "\(devicesNotified)"
        ])
    }
    
    func logAPNsRegistrationSuccess(tokenPrefix: String, tokenSuffix: String) {
        log(eventType: "apns_registration_success", message: "APNs token registered", metadata: [
            "tokenPrefix": tokenPrefix,
            "tokenSuffix": tokenSuffix
        ])
    }
    
    func logAPNsRegistrationFailure(error: String) {
        log(eventType: "apns_registration_failure", message: "APNs registration failed", metadata: [
            "error": error
        ])
    }
    
    func logDeviceTokenRegisterStart(token: String) {
        let prefix = String(token.prefix(8))
        let suffix = String(token.suffix(6))
        log(eventType: "device_token_register_start", message: "Registering device token with backend", metadata: [
            "tokenPrefix": prefix,
            "tokenSuffix": suffix
        ])
    }
    
    func logDeviceTokenRegisterSuccess(deviceId: String) {
        log(eventType: "device_token_register_success", message: "Device token registered successfully", metadata: [
            "deviceId": deviceId
        ])
    }
    
    func logDeviceTokenRegisterFailure(error: String) {
        log(eventType: "device_token_register_failure", message: "Failed to register device token", metadata: [
            "error": error
        ])
    }
    
    func logNotificationReceived(payload: [String: Any], inForeground: Bool) {
        lastNotificationPayload = payload
        
        let requestId = payload["requestId"] as? String ?? "unknown"
        let senderName = payload["senderName"] as? String ?? "unknown"
        
        log(eventType: "notification_received", message: "Push notification received", metadata: [
            "requestId": requestId,
            "senderName": senderName,
            "inForeground": "\(inForeground)"
        ])
    }
    
    func logWakeAlertPresented(requestId: String, senderName: String) {
        lastAlarmTriggeredAt = Date()
        
        log(eventType: "wake_alert_presented", message: "WakeAlert presented", metadata: [
            "requestId": requestId,
            "senderName": senderName
        ])
    }
    
    func logAlarmSoundPlaybackStarted(soundId: String) {
        log(eventType: "alarm_sound_playback_started", message: "Playing alarm sound", metadata: [
            "soundId": soundId
        ])
    }
    
    func logAlarmSoundPlaybackFailed(error: String) {
        log(eventType: "alarm_sound_playback_failed", message: "Failed to play alarm sound", metadata: [
            "error": error
        ])
    }
    
    func logError(_ error: Error, context: String) {
        log(eventType: "error", message: "Error: \(context)", metadata: [
            "error": error.localizedDescription
        ])
    }
    
    // MARK: - Generate Trace ID
    func generateTraceId() -> String {
        return UUID().uuidString
    }
    
    // MARK: - Persistence
    
    private func saveEvents() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        UserDefaults.standard.set(data, forKey: eventsKey)
    }
    
    private func loadEvents() {
        guard let data = UserDefaults.standard.data(forKey: eventsKey),
              let loadedEvents = try? JSONDecoder().decode([DebugEvent].self, from: data) else {
            return
        }
        events = loadedEvents
        
        // Load last wake trace ID
        if let traceId = UserDefaults.standard.string(forKey: lastWakeTraceIdKey) {
            lastWakeTraceId = traceId
        }
    }
    
    // MARK: - Clear
    
    func clearEvents() {
        events = []
        lastWakeResponse = nil
        lastNotificationPayload = nil
        lastAlarmTriggeredAt = nil
        UserDefaults.standard.removeObject(forKey: eventsKey)
        UserDefaults.standard.removeObject(forKey: lastWakeTraceIdKey)
    }
    
    // MARK: - Export
    
    func exportDiagnostics() -> String {
        var export = "=== Wake Up Sunshine Diagnostics ===\n"
        export += "Generated: \(ISO8601DateFormatter().string(from: Date()))\n\n"
        
        export += "--- Events (last \(events.count)) ---\n"
        for event in events {
            let metadataStr = event.metadata.isEmpty ? "" : " | \(event.metadata)"
            export += "[\(event.timestamp)] [\(event.eventType)] \(event.message)\(metadataStr)\n"
        }
        
        if let lastWake = lastWakeResponse {
            export += "\n--- Last Wake Response ---\n"
            export += "\(lastWake)\n"
        }
        
        if let lastNotif = lastNotificationPayload {
            export += "\n--- Last Notification Payload ---\n"
            export += "\(lastNotif)\n"
        }
        
        if let lastAlarm = lastAlarmTriggeredAt {
            export += "\n--- Last Alarm Triggered ---\n"
            export += "\(lastAlarm)\n"
        }
        
        return export
    }
}

// MARK: - Helper Extension
extension DispatchQueue {
    static func mainAsyncSafe(execute work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}